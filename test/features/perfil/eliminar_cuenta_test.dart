import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tema_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/perfil/data/cuenta_con_reservas.dart';
import 'package:servia/features/perfil/mensajes.dart';
import 'package:servia/features/perfil/pages/mi_perfil_page.dart';
import 'package:servia/features/reservas/pages/mis_reservas_page.dart';

import '../reservas/fakes.dart' show ReservasFalso;
import 'fakes_perfil.dart';

final _campo = find.byKey(const Key('campo-contrasena-eliminar'));
final _dialogo = find.byType(AlertDialog);

CuentaConReservasException conflicto() => CuentaConReservasException(
  mensaje:
      'No puedes eliminar tu cuenta porque tienes reservas pendientes o '
      'confirmadas: SRV-AAAAAA, SRV-BBBBBB. Cancélalas o espera a que '
      'terminen.',
  total: 2,
  reservas: [
    ReservaPorAtender(
      id: 'r1',
      folio: 'SRV-AAAAAA',
      estado: 'pendiente',
      // 10:30 en México (UTC-6).
      inicio: DateTime.utc(2026, 11, 25, 16, 30),
    ),
    ReservaPorAtender(
      id: 'r2',
      folio: 'SRV-BBBBBB',
      estado: 'confirmada',
      // 19:00 del 1 de diciembre en México.
      inicio: DateTime.utc(2026, 12, 2, 1),
    ),
  ],
);

Future<void> _abrir(
  WidgetTester tester, {
  required SesionPerfilFalsa sesion,
  required PerfilClienteFalso api,
  ReservasFalso? reservas,
  ThemeData? tema,
}) async {
  await tester.pumpWidget(const SizedBox());
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: tema ?? temaServia(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MiPerfilPage(
                  authService: sesion,
                  perfilClienteService: api,
                  reservasService: reservas ?? ReservasFalso(),
                ),
              ),
            ),
            child: const Text('Inicio'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Inicio'));
  await tester.pumpAndSettle();
}

Future<void> _abrirDialogo(WidgetTester tester) async {
  final boton = find.text(MensajesPerfil.eliminarCuenta);
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Future<void> _confirmar(WidgetTester tester, String contrasena) async {
  await tester.enterText(_campo, contrasena);
  await tester.tap(
    find.descendant(
      of: _dialogo,
      matching: find.text(MensajesPerfil.eliminarConfirmar),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late List<String> eventos;
  late SesionPerfilFalsa sesion;
  late PerfilClienteFalso api;

  setUp(() {
    eventos = [];
    sesion = SesionPerfilFalsa(eventos);
    api = PerfilClienteFalso(eventos);
  });

  testWidgets('el botón acompaña a «Soporte» y «Español» y abre el diálogo que '
      'explica qué se elimina y qué se conserva', (tester) async {
    await _abrir(tester, sesion: sesion, api: api);
    await _abrirDialogo(tester);
    expect(find.text(MensajesPerfil.eliminarTitulo), findsOneWidget);
    expect(find.text(MensajesPerfil.eliminarSeElimina), findsOneWidget);
    expect(find.text(MensajesPerfil.eliminarSeConserva), findsOneWidget);
    expect(find.text(MensajesPerfil.eliminarIrreversible), findsOneWidget);
    expect(_campo, findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
  });

  testWidgets('«Cancelar» no cambia nada: ni reautentica ni llama a la API', (
    tester,
  ) async {
    await _abrir(tester, sesion: sesion, api: api);
    await _abrirDialogo(tester);
    await tester.tap(
      find.descendant(of: _dialogo, matching: find.text('Cancelar')),
    );
    await tester.pumpAndSettle();
    expect(_dialogo, findsNothing);
    expect(find.byType(MiPerfilPage), findsOneWidget);
    expect(eventos, ['token', 'GET']);
    expect(sesion.usuario, isNotNull);
  });

  testWidgets('sin contraseña: error en el campo y no hace nada más', (
    tester,
  ) async {
    await _abrir(tester, sesion: sesion, api: api);
    await _abrirDialogo(tester);
    await _confirmar(tester, '');
    expect(
      find.text(MensajesPerfil.eliminarContrasenaObligatoria),
      findsOneWidget,
    );
    expect(eventos, ['token', 'GET']);
  });

  testWidgets('contraseña incorrecta: mensaje y NO llama a la API', (
    tester,
  ) async {
    sesion.errorAlReautenticar = FirebaseAuthException(code: 'wrong-password');
    await _abrir(tester, sesion: sesion, api: api);
    await _abrirDialogo(tester);
    await _confirmar(tester, 'mala-clave');
    expect(find.text(MensajesAuth.contrasenaActualIncorrecta), findsOneWidget);
    expect(api.eliminaciones, 0);
    expect(eventos, ['token', 'GET', 'reautenticar']);
    expect(sesion.usuario, isNotNull);
    expect(_dialogo, findsOneWidget);
  });

  testWidgets('204: reautentica, token nuevo, DELETE, cierra sesión, vuelve '
      'al inicio y despide', (tester) async {
    await _abrir(tester, sesion: sesion, api: api);
    await _abrirDialogo(tester);
    await _confirmar(tester, 'clave-correcta');
    expect(sesion.ultimaContrasena, 'clave-correcta');
    expect(eventos, [
      'token',
      'GET',
      'reautenticar',
      'token-nuevo',
      'DELETE-CUENTA',
      'cerrar-sesion',
    ]);
    expect(sesion.usuario, isNull);
    expect(find.byType(MiPerfilPage), findsNothing);
    expect(_dialogo, findsNothing);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text(MensajesPerfil.cuentaEliminada), findsOneWidget);
  });

  testWidgets('409: muestra el mensaje, los folios con fecha de México y '
      'conserva la sesión', (tester) async {
    api.errorAlEliminar = conflicto();
    await _abrir(tester, sesion: sesion, api: api);
    await _abrirDialogo(tester);
    await _confirmar(tester, 'clave-correcta');
    expect(
      find.textContaining('No puedes eliminar tu cuenta porque tienes'),
      findsOneWidget,
    );
    expect(find.text('SRV-AAAAAA'), findsOneWidget);
    expect(find.text('SRV-BBBBBB'), findsOneWidget);
    expect(
      find.textContaining('miércoles 25 de noviembre de 2026'),
      findsOneWidget,
    );
    expect(find.textContaining('10:30'), findsOneWidget);
    // 2 de diciembre 01:00 UTC es el 1 de diciembre a las 19:00 en México.
    expect(
      find.textContaining('martes 1 de diciembre de 2026'),
      findsOneWidget,
    );
    expect(find.textContaining('19:00'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text(MensajesPerfil.verMisReservas), findsOneWidget);
    expect(sesion.usuario, isNotNull);
    expect(eventos.contains('cerrar-sesion'), isFalse);
    expect(find.byType(MiPerfilPage), findsOneWidget);
  });

  testWidgets('«Ver mis reservas» abre Mis reservas sin cerrar sesión', (
    tester,
  ) async {
    api.errorAlEliminar = conflicto();
    await _abrir(tester, sesion: sesion, api: api);
    await _abrirDialogo(tester);
    await _confirmar(tester, 'clave-correcta');
    await tester.tap(find.text(MensajesPerfil.verMisReservas));
    await tester.pumpAndSettle();
    expect(find.byType(MisReservasPage), findsOneWidget);
    expect(_dialogo, findsNothing);
    expect(sesion.usuario, isNotNull);
  });

  testWidgets('401, 503 y red: mensaje en español, sin perder la sesión y '
      'se puede reintentar', (tester) async {
    final casos = <Object, String>{
      const ApiException(401, MensajesPerfil.sesionInvalida):
          MensajesPerfil.sesionInvalida,
      const ApiException(
        503,
        'No se pudo eliminar tu cuenta. Vuelve a intentarlo en unos minutos.',
      ): 'No se pudo eliminar tu cuenta. Vuelve a intentarlo en unos minutos.',
      const SocketException('sin red'): MensajesAuth.errorRed,
    };
    for (final MapEntry(key: fallo, value: mensaje) in casos.entries) {
      eventos.clear();
      sesion = SesionPerfilFalsa(eventos);
      api = PerfilClienteFalso(eventos)..errorAlEliminar = fallo;
      await _abrir(tester, sesion: sesion, api: api);
      await _abrirDialogo(tester);
      await _confirmar(tester, 'clave-correcta');
      expect(find.text(mensaje), findsOneWidget, reason: '$fallo');
      expect(sesion.usuario, isNotNull);
      expect(eventos.contains('cerrar-sesion'), isFalse);
      // Reintento: la API ya responde bien y se cierra la sesión.
      api.errorAlEliminar = null;
      await tester.tap(
        find.descendant(
          of: _dialogo,
          matching: find.text(MensajesPerfil.eliminarConfirmar),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.eliminaciones, 2, reason: '$fallo');
      expect(sesion.usuario, isNull);
    }
  });

  testWidgets('mientras elimina: botones deshabilitados e indicador', (
    tester,
  ) async {
    final espera = Completer<void>();
    final lenta = _EliminaLento(eventos, espera);
    await _abrir(tester, sesion: sesion, api: lenta);
    await _abrirDialogo(tester);
    await tester.enterText(_campo, 'clave-correcta');
    await tester.tap(
      find.descendant(
        of: _dialogo,
        matching: find.text(MensajesPerfil.eliminarConfirmar),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(MensajesPerfil.eliminandoCuenta), findsOneWidget);
    for (final tipo in [FilledButton, OutlinedButton]) {
      final boton = tester.widget<ButtonStyleButton>(
        find.descendant(of: _dialogo, matching: find.byType(tipo)),
      );
      expect(boton.onPressed, isNull, reason: '$tipo');
    }
    espera.complete();
    await tester.pumpAndSettle();
    expect(lenta.eliminaciones, 1);
    expect(sesion.usuario, isNull);
  });

  group('estilos del tema (rediseño)', () {
    testWidgets('«Eliminar cuenta» usa el color de error del tema y píldora', (
      tester,
    ) async {
      await _abrir(tester, sesion: sesion, api: api);
      await _abrirDialogo(tester);
      final tema = Theme.of(tester.element(_dialogo));
      final dialogo = tester.widget<AlertDialog>(_dialogo);
      expect(dialogo.backgroundColor, isNull);
      expect(dialogo.shape, isNull);
      final confirmar = tester.widget<FilledButton>(
        find.descendant(of: _dialogo, matching: find.byType(FilledButton)),
      );
      expect(
        confirmar.style!.backgroundColor!.resolve({}),
        tema.colorScheme.error,
      );
      expect(
        confirmar.style!.foregroundColor!.resolve({}),
        tema.colorScheme.onError,
      );
      expect(confirmar.style!.shape!.resolve({}), const StadiumBorder());
      expect(confirmar.style!.minimumSize!.resolve({})!.height, Medidas.boton);
      final cancelar = tester.widget<OutlinedButton>(
        find.descendant(of: _dialogo, matching: find.byType(OutlinedButton)),
      );
      expect(cancelar.style!.shape!.resolve({}), const StadiumBorder());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('cambiar el tema cambia el botón: no hay colores fijos', (
      tester,
    ) async {
      const rojo = Color(0xFFFF0000);
      final otro = temaServia().copyWith(
        colorScheme: ColoresServia.esquema.copyWith(error: rojo),
      );
      await _abrir(tester, sesion: sesion, api: api, tema: otro);
      await _abrirDialogo(tester);
      final confirmar = tester.widget<FilledButton>(
        find.descendant(of: _dialogo, matching: find.byType(FilledButton)),
      );
      expect(confirmar.style!.backgroundColor!.resolve({}), rojo);
    });

    testWidgets('el campo usa el InputDecorationTheme (sin bordes propios)', (
      tester,
    ) async {
      await _abrir(tester, sesion: sesion, api: api);
      await _abrirDialogo(tester);
      final decoracion = tester
          .widget<TextField>(
            find.descendant(of: _campo, matching: find.byType(TextField)),
          )
          .decoration!;
      final delTema = Theme.of(tester.element(_campo)).inputDecorationTheme;
      // El campo no define bordes ni relleno: son los del tema.
      expect(decoracion.border, delTema.border);
      expect(decoracion.enabledBorder, delTema.enabledBorder);
      expect(decoracion.fillColor, delTema.fillColor);
      expect(decoracion.labelText, isNull);
      // La etiqueta va encima del campo, como el resto de formularios.
      expect(find.text(MensajesPerfil.contrasenaActual), findsWidgets);
    });

    testWidgets('el botón de la pantalla es una acción destructiva del tema', (
      tester,
    ) async {
      await _abrir(tester, sesion: sesion, api: api);
      final tema = Theme.of(tester.element(find.byType(MiPerfilPage)));
      final boton = find.ancestor(
        of: find.text(MensajesPerfil.eliminarCuenta),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      await tester.ensureVisible(boton);
      expect(
        tester
            .widget<ButtonStyleButton>(boton)
            .style!
            .foregroundColor!
            .resolve({}),
        tema.colorScheme.error,
      );
      expect(
        tester.getSize(boton).height,
        greaterThanOrEqualTo(Medidas.tactil),
      );
    });

    test('el código nuevo no trae colores, espacios ni radios literales', () {
      final archivos = [
        'lib/features/perfil/pages/dialogo_eliminar_cuenta.dart',
        'lib/features/perfil/data/cuenta_con_reservas.dart',
      ];
      final prohibidos = {
        'color literal': RegExp(r'Color\(0x|Colors\.'),
        'tamaño de letra': RegExp(r'fontSize:'),
        'radio literal': RegExp(r'(Border|)Radius\.circular\('),
        'relleno literal': RegExp(r'EdgeInsets\.\w+\([^)]*\d'),
        'espacio literal': RegExp(
          r'(SizedBox\([^)]*|width:\s*|dimension:\s*)\d',
        ),
      };
      for (final ruta in archivos) {
        final fuente = File(ruta).readAsStringSync();
        for (final MapEntry(key: nombre, value: regla) in prohibidos.entries) {
          expect(regla.hasMatch(fuente), isFalse, reason: '$ruta: $nombre');
        }
      }
    });
  });
}

class _EliminaLento extends PerfilClienteFalso {
  _EliminaLento(super.eventos, this.espera);
  final Completer<void> espera;

  @override
  Future<void> eliminarCuenta(String token) async {
    await super.eliminarCuenta(token);
    await espera.future;
  }
}
