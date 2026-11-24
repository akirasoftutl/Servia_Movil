import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tema_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/perfil/data/foto_perfil.dart';
import 'package:servia/features/perfil/data/perfil_cliente.dart';
import 'package:servia/features/perfil/data/selector_foto.dart';
import 'package:servia/features/perfil/mensajes.dart';
import 'package:servia/features/perfil/pages/mi_perfil_page.dart';

import 'fakes_perfil.dart';

const _foto = FotoPerfil(id: 'f0', url: 'https://supabase.test/f0.png');
const _conFoto = PerfilCliente(
  nombre: 'Ana Pérez',
  correo: 'ana@test.com',
  telefono: '4771234567',
  foto: _foto,
);

ImageProvider _proveedor(String _) => MemoryImage(png1x1);

/// Una imagen que no se puede decodificar: simula una URL rota.
ImageProvider _proveedorRoto(String _) => MemoryImage(Uint8List.fromList([1]));

final _avatar = find.byKey(const Key('avatar-perfil'));
final _imagenAvatar = find.descendant(
  of: _avatar,
  matching: find.byType(Image),
);

Uint8List _relleno(List<int> firma, int total) {
  final bytes = Uint8List(total);
  bytes.setAll(0, firma);
  return bytes;
}

Future<void> _abrir(
  WidgetTester tester, {
  required SesionPerfilFalsa sesion,
  required PerfilClienteFalso api,
  required SelectorFotoFalso selector,
  ImageProvider Function(String)? proveedor,
  ThemeData? tema,
}) async {
  await tester.pumpWidget(const SizedBox());
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: tema ?? temaServia(),
      home: MiPerfilPage(
        authService: sesion,
        perfilClienteService: api,
        selectorFoto: selector,
        proveedorFoto: proveedor ?? _proveedor,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  late List<String> eventos;
  late SesionPerfilFalsa sesion;
  late SelectorFotoFalso selector;

  setUp(() {
    eventos = [];
    sesion = SesionPerfilFalsa(eventos);
    selector = SelectorFotoFalso(FotoElegida(bytes: png1x1, nombre: 'ana.png'));
  });

  PerfilClienteFalso api({
    PerfilCliente? perfil,
    Object? errorAlSubirFoto,
    Object? errorAlQuitarFoto,
    Completer<void>? esperaSubida,
    bool patchSinFoto = false,
  }) {
    final falso = PerfilClienteFalso(
      eventos,
      errorAlSubirFoto: errorAlSubirFoto,
      errorAlQuitarFoto: errorAlQuitarFoto,
      esperaSubida: esperaSubida,
      patchSinFoto: patchSinFoto,
    );
    if (perfil != null) falso.guardado = perfil;
    return falso;
  }

  group('avatar', () {
    testWidgets('sin foto: la inicial del nombre y «Agregar foto»', (
      tester,
    ) async {
      await _abrir(tester, sesion: sesion, api: api(), selector: selector);
      expect(_imagenAvatar, findsNothing);
      expect(
        find.descendant(of: _avatar, matching: find.text('A')),
        findsOneWidget,
      );
      expect(find.text('Agregar foto'), findsOneWidget);
      expect(find.text('Cambiar foto'), findsNothing);
      expect(find.text('Quitar foto'), findsNothing);
    });

    testWidgets('con foto: la imagen, «Cambiar foto» y «Quitar foto»', (
      tester,
    ) async {
      await _abrir(
        tester,
        sesion: sesion,
        api: api(perfil: _conFoto),
        selector: selector,
      );
      expect(_imagenAvatar, findsOneWidget);
      expect(
        find.descendant(of: _avatar, matching: find.text('A')),
        findsNothing,
      );
      expect(find.text('Cambiar foto'), findsOneWidget);
      expect(find.text('Quitar foto'), findsOneWidget);
      expect(find.text('Agregar foto'), findsNothing);
    });

    testWidgets('si la imagen no carga, vuelve a la inicial', (tester) async {
      await _abrir(
        tester,
        sesion: sesion,
        api: api(perfil: _conFoto),
        selector: selector,
        proveedor: _proveedorRoto,
      );
      expect(
        find.descendant(of: _avatar, matching: find.text('A')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('lectura para lector de pantalla (con y sin foto)', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await _abrir(tester, sesion: sesion, api: api(), selector: selector);
      expect(
        find.bySemanticsLabel(MensajesPerfil.semanticaSinFoto('Ana Pérez')),
        findsOneWidget,
      );
      await _abrir(
        tester,
        sesion: SesionPerfilFalsa(eventos),
        api: api(perfil: _conFoto),
        selector: selector,
      );
      expect(
        find.bySemanticsLabel(MensajesPerfil.semanticaFoto('Ana Pérez')),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('otra cuenta no ve la foto de la anterior y la primera la '
        'recupera (RN-46)', (tester) async {
      await _abrir(
        tester,
        sesion: sesion,
        api: api(perfil: _conFoto),
        selector: selector,
      );
      expect(_imagenAvatar, findsOneWidget);
      // Cierra sesión: la pantalla se cierra y no guarda nada de la cuenta.
      await tester.pumpWidget(const SizedBox());
      const otra = PerfilCliente(
        nombre: 'Luis Gómez',
        correo: 'luis@test.com',
        telefono: '4770000000',
      );
      await _abrir(
        tester,
        sesion: SesionPerfilFalsa(eventos),
        api: api(perfil: otra),
        selector: selector,
      );
      expect(_imagenAvatar, findsNothing);
      expect(
        find.descendant(of: _avatar, matching: find.text('L')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await _abrir(
        tester,
        sesion: SesionPerfilFalsa(eventos),
        api: api(perfil: _conFoto),
        selector: selector,
      );
      expect(_imagenAvatar, findsOneWidget);
    });
  });

  group('subir y cambiar', () {
    testWidgets('agrega una foto: POST, avatar con la foto y aviso', (
      tester,
    ) async {
      final falso = api();
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Agregar foto'));

      expect(selector.aperturas, 1);
      expect(falso.subidas, 1);
      expect(falso.ultimosBytes, png1x1);
      expect(falso.ultimoNombre, 'ana.png');
      expect(eventos, ['token', 'GET', 'token', 'POST-FOTO']);
      expect(_imagenAvatar, findsOneWidget);
      expect(find.text(MensajesPerfil.fotoActualizada), findsOneWidget);
      expect(find.text('Cambiar foto'), findsOneWidget);
      expect(find.text('Quitar foto'), findsOneWidget);
    });

    testWidgets('al cambiarla, la nueva reemplaza a la anterior', (
      tester,
    ) async {
      final falso = api(perfil: _conFoto);
      final urls = <String>[];
      await _abrir(
        tester,
        sesion: sesion,
        api: falso,
        selector: selector,
        proveedor: (url) {
          urls.add(url);
          return MemoryImage(png1x1);
        },
      );
      expect(urls.last, _foto.url);
      await _tocar(tester, find.text('Cambiar foto'));
      expect(falso.subidas, 1);
      expect(urls.last, 'https://supabase.test/clientes/uid/f1.png');
      expect(_imagenAvatar, findsOneWidget);
    });

    testWidgets('si el selector se cancela no pasa nada', (tester) async {
      selector.resultado = null;
      final falso = api(perfil: _conFoto);
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Cambiar foto'));
      expect(falso.subidas, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(_imagenAvatar, findsOneWidget);
    });

    testWidgets('mientras sube: vista previa, indicador y botones '
        'deshabilitados', (tester) async {
      final espera = Completer<void>();
      final falso = api(esperaSubida: espera);
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await tester.ensureVisible(find.text('Agregar foto'));
      await tester.tap(find.text('Agregar foto'));
      await tester.pump();
      await tester.pump();

      // Vista previa de la foto elegida y estado de subida.
      expect(_imagenAvatar, findsOneWidget);
      expect(find.text(MensajesPerfil.subiendoFoto), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      final boton = find.ancestor(
        of: find.text('Agregar foto'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.widget<ButtonStyleButton>(boton).onPressed, isNull);
      // Un segundo toque no abre otra subida.
      await tester.tap(find.text('Agregar foto'), warnIfMissed: false);
      expect(selector.aperturas, 1);

      espera.complete();
      await tester.pumpAndSettle();
      expect(find.text(MensajesPerfil.subiendoFoto), findsNothing);
      expect(falso.subidas, 1);
    });

    testWidgets('más de 5 MB: mensaje, no llama a la API y no cambia la foto', (
      tester,
    ) async {
      selector.resultado = FotoElegida(
        bytes: _relleno([0xFF, 0xD8, 0xFF], ValidacionTamano.cincoMbMasUno),
        nombre: 'grande.jpg',
      );
      final falso = api(perfil: _conFoto);
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Cambiar foto'));
      expect(falso.subidas, 0);
      expect(eventos, ['token', 'GET']);
      expect(find.text(MensajesPerfil.fotoGrande), findsOneWidget);
      expect(_imagenAvatar, findsOneWidget);
      expect(find.text('Cambiar foto'), findsOneWidget);
    });

    testWidgets('formato no permitido: mensaje y no llama a la API', (
      tester,
    ) async {
      selector.resultado = FotoElegida(
        bytes: _relleno('GIF89a'.codeUnits, 64),
        nombre: 'a.gif',
      );
      final falso = api();
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Agregar foto'));
      expect(falso.subidas, 0);
      expect(find.text(MensajesPerfil.fotoFormato), findsOneWidget);
      expect(_imagenAvatar, findsNothing);
    });

    testWidgets('400 y 413 de la API: su mensaje, la foto no cambia', (
      tester,
    ) async {
      for (final mensaje in [
        'El archivo debe ser una imagen JPEG, PNG o WebP válida.',
        'La foto supera el tamaño máximo de 5 MB.',
      ]) {
        final falso = api(
          perfil: _conFoto,
          errorAlSubirFoto: ApiException(400, mensaje),
        );
        await _abrir(tester, sesion: sesion, api: falso, selector: selector);
        await _tocar(tester, find.text('Cambiar foto'));
        expect(find.text(mensaje), findsOneWidget, reason: mensaje);
        expect(_imagenAvatar, findsOneWidget);
        expect(falso.guardado.foto?.id, 'f0');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('error de red: mensaje en español y «Reintentar» sube la '
        'misma foto', (tester) async {
      final falso = api(errorAlSubirFoto: const SocketException('sin red'));
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Agregar foto'));
      expect(find.text(MensajesAuth.errorRed), findsOneWidget);
      expect(_imagenAvatar, findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(selector.aperturas, 1);
    });

    testWidgets('«Reintentar» tras un fallo sube la foto sin volver a '
        'elegirla', (tester) async {
      var falla = true;
      final falso = _FalloUnaVez(eventos, () => falla);
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Agregar foto'));
      expect(find.text('Reintentar'), findsOneWidget);
      falla = false;
      await _tocar(tester, find.text('Reintentar'));
      expect(selector.aperturas, 1);
      expect(falso.subidas, 2);
      expect(falso.ultimosBytes, png1x1);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text(MensajesPerfil.fotoActualizada), findsOneWidget);
      expect(_imagenAvatar, findsOneWidget);
    });

    testWidgets('si el selector falla, mensaje en español y sin llamar a la '
        'API', (tester) async {
      final roto = SelectorFotoFalso(null, error: Exception('plataforma'));
      final falso = api();
      await _abrir(tester, sesion: sesion, api: falso, selector: roto);
      await _tocar(tester, find.text('Agregar foto'));
      expect(falso.subidas, 0);
      expect(find.text(MensajesPerfil.fotoNoElegida), findsOneWidget);
    });
  });

  group('quitar', () {
    testWidgets('pide confirmación y «Cancelar» no cambia nada', (
      tester,
    ) async {
      final falso = api(perfil: _conFoto);
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Quitar foto'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(MensajesPerfil.quitarTitulo), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancelar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(falso.quitadas, 0);
      expect(_imagenAvatar, findsOneWidget);
    });

    testWidgets('confirmar: DELETE, vuelve la inicial y avisa', (tester) async {
      final falso = api(perfil: _conFoto);
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Quitar foto'));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Quitar foto'),
        ),
      );
      await tester.pumpAndSettle();
      expect(falso.quitadas, 1);
      expect(eventos, ['token', 'GET', 'token', 'DELETE-FOTO']);
      expect(_imagenAvatar, findsNothing);
      expect(
        find.descendant(of: _avatar, matching: find.text('A')),
        findsOneWidget,
      );
      expect(find.text(MensajesPerfil.fotoEliminada), findsOneWidget);
      expect(find.text('Agregar foto'), findsOneWidget);
    });

    testWidgets('si la API falla conserva la foto y muestra el motivo', (
      tester,
    ) async {
      final falso = api(
        perfil: _conFoto,
        errorAlQuitarFoto: ApiException(
          503,
          'Supabase Storage no está configurado en el servidor.',
        ),
      );
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Quitar foto'));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Quitar foto'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Supabase Storage no está configurado en el servidor.'),
        findsOneWidget,
      );
      expect(_imagenAvatar, findsOneWidget);
      expect(find.text('Quitar foto'), findsOneWidget);
    });
  });

  group('editar el perfil no toca la foto', () {
    testWidgets('el PATCH con foto la conserva', (tester) async {
      final falso = api(perfil: _conFoto);
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Editar información'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Ana Pérez'),
        'Ana Ruiz',
      );
      await _tocar(tester, find.text('Guardar'));
      expect(falso.actualizaciones, 1);
      expect(falso.quitadas, 0);
      expect(_imagenAvatar, findsOneWidget);
    });

    testWidgets('aunque la API no devuelva foto en el PATCH, la app no la '
        'quita', (tester) async {
      final falso = api(perfil: _conFoto, patchSinFoto: true);
      await _abrir(tester, sesion: sesion, api: falso, selector: selector);
      await _tocar(tester, find.text('Editar información'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Ana Pérez'),
        'Ana Ruiz',
      );
      await _tocar(tester, find.text('Guardar'));
      expect(_imagenAvatar, findsOneWidget);
    });
  });

  group('estilos del tema (rediseño)', () {
    testWidgets('el avatar toma sus colores y su tipografía del tema', (
      tester,
    ) async {
      await _abrir(tester, sesion: sesion, api: api(), selector: selector);
      final tema = Theme.of(tester.element(_avatar));
      final caja = tester.widget<Container>(_avatar);
      final decoracion = caja.decoration! as BoxDecoration;
      expect(decoracion.color, tema.colorScheme.primaryContainer);
      expect(decoracion.shape, BoxShape.circle);
      expect(tester.getSize(_avatar), const Size.square(Medidas.logo));
      final inicial = tester.widget<Text>(
        find.descendant(of: _avatar, matching: find.text('A')),
      );
      expect(inicial.style?.color, tema.colorScheme.onPrimaryContainer);
      expect(inicial.style?.fontFamily, fuenteServia);
    });

    testWidgets('cambiar el tema cambia el avatar: no hay colores fijos', (
      tester,
    ) async {
      const verde = Color(0xFF00FF00);
      const rojo = Color(0xFFFF0000);
      final otro = temaServia().copyWith(
        colorScheme: ColoresServia.esquema.copyWith(
          primaryContainer: verde,
          onPrimaryContainer: rojo,
        ),
      );
      await _abrir(
        tester,
        sesion: sesion,
        api: api(),
        selector: selector,
        tema: otro,
      );
      final decoracion =
          tester.widget<Container>(_avatar).decoration! as BoxDecoration;
      expect(decoracion.color, verde);
      final inicial = tester.widget<Text>(
        find.descendant(of: _avatar, matching: find.text('A')),
      );
      expect(inicial.style?.color, rojo);
    });

    testWidgets('los botones de foto miden al menos 48 dp y usan los colores '
        'del tema', (tester) async {
      await _abrir(
        tester,
        sesion: sesion,
        api: api(perfil: _conFoto),
        selector: selector,
      );
      final tema = Theme.of(tester.element(_avatar));
      for (final texto in ['Cambiar foto', 'Quitar foto']) {
        final boton = find.ancestor(
          of: find.text(texto),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(
          tester.getSize(boton).height,
          greaterThanOrEqualTo(Medidas.tactil),
          reason: texto,
        );
        final estilo = tester.widget<ButtonStyleButton>(boton).style!;
        expect(
          estilo.foregroundColor!.resolve({}),
          anyOf(tema.colorScheme.onSurface, tema.colorScheme.error),
        );
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('el diálogo de quitar usa el tema y los botones del '
        'rediseño', (tester) async {
      await _abrir(
        tester,
        sesion: sesion,
        api: api(perfil: _conFoto),
        selector: selector,
      );
      await _tocar(tester, find.text('Quitar foto'));
      final tema = Theme.of(tester.element(find.byType(AlertDialog)));
      final dialogo = tester.widget<AlertDialog>(find.byType(AlertDialog));
      // Sin fondo ni forma propios: salen del `dialogTheme`.
      expect(dialogo.backgroundColor, isNull);
      expect(dialogo.shape, isNull);
      expect(tema.dialogTheme.shape, isNotNull);

      final confirmar = tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      expect(confirmar.style!.shape!.resolve({}), const StadiumBorder());
      expect(
        confirmar.style!.backgroundColor!.resolve({}),
        tema.colorScheme.onSurface,
      );
      expect(confirmar.style!.minimumSize!.resolve({})!.height, Medidas.boton);
      final cancelar = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(cancelar.style!.shape!.resolve({}), const StadiumBorder());
      expect(cancelar.style!.minimumSize!.resolve({})!.height, Medidas.tactil);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    test('el código nuevo no trae colores, espacios ni radios literales', () {
      final archivos = [
        'lib/features/perfil/pages/avatar_perfil.dart',
        'lib/features/perfil/pages/seccion_foto_perfil.dart',
        'lib/features/perfil/pages/dialogo_confirmacion.dart',
        'lib/features/perfil/pages/estilos_perfil.dart',
      ];
      final prohibidos = {
        'color literal': RegExp(r'Color\(0x|Colors\.'),
        'tamaño de letra': RegExp(r'fontSize:'),
        'radio literal': RegExp(r'(Border|)Radius\.circular\('),
        'relleno literal': RegExp(r'EdgeInsets\.\w+\([^)]*\d'),
        'espacio literal': RegExp(r'(SizedBox\([^)]*|width:\s*|dimension:\s*)\d'),
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

/// Falla la subida mientras [falla] devuelva true.
class _FalloUnaVez extends PerfilClienteFalso {
  _FalloUnaVez(super.eventos, this.falla);
  final bool Function() falla;

  @override
  Future<FotoPerfil> subirFoto(
    String token,
    Uint8List bytes,
    String nombre,
  ) async {
    if (falla()) {
      eventos.add('POST-FOTO');
      subidas++;
      ultimosBytes = bytes;
      throw ApiException(
        503,
        'No se pudo guardar la foto en Supabase Storage.',
      );
    }
    return super.subirFoto(token, bytes, nombre);
  }
}

abstract final class ValidacionTamano {
  static const cincoMbMasUno = 5 * 1024 * 1024 + 1;
}
