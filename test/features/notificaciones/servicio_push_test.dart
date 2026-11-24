import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/notificaciones/data/servicio_push.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServicioPush', () {
    test('pide permiso, obtiene el token y lo registra en la API', () async {
      final mensajeria = MessagingFalso();
      final avisos = NotificacionesFalso();
      final push = ServicioPush(messaging: mensajeria, notificaciones: avisos);
      addTearDown(push.dispose);

      await push.registrar('token-api');

      expect(mensajeria.solicitudesPermiso, 1);
      expect(mensajeria.tokensObtenidos, 1);
      expect(avisos.registros, [
        {'token': 'token-api', 'tokenFcm': 'token-fcm'},
      ]);
    });

    test('si se niega el permiso no pide token ni registra', () async {
      final mensajeria = MessagingFalso(permisoConcedido: false);
      final avisos = NotificacionesFalso();
      final push = ServicioPush(messaging: mensajeria, notificaciones: avisos);
      addTearDown(push.dispose);

      await push.registrar('token-api');

      expect(mensajeria.solicitudesPermiso, 1);
      expect(mensajeria.tokensObtenidos, 0);
      expect(avisos.registros, isEmpty);
    });

    test(
      'un fallo del permiso o del plugin no impide entrar a la app',
      () async {
        for (final acceso in [
          () => MessagingFalso(errorPermiso: StateError('sin permiso')),
          () => MessagingFalso(errorToken: StateError('sin token')),
        ]) {
          final mensajeria = acceso();
          final avisos = NotificacionesFalso();
          final push = ServicioPush(
            messaging: mensajeria,
            notificaciones: avisos,
          );
          addTearDown(push.dispose);
          await push.registrar('token-api');
          expect(avisos.registros, isEmpty);
        }
      },
    );

    test('registra de nuevo al renovar el token', () async {
      final mensajeria = MessagingFalso();
      final avisos = NotificacionesFalso();
      final push = ServicioPush(messaging: mensajeria, notificaciones: avisos);
      addTearDown(push.dispose);
      push.configurar();
      await push.registrar('token-api');

      mensajeria.refrescos.add('nuevo-token');
      await pumpEventQueue();

      expect(avisos.registros, [
        {'token': 'token-api', 'tokenFcm': 'token-fcm'},
        {'token': 'token-api', 'tokenFcm': 'nuevo-token'},
      ]);
    });

    test('no reenvía tokens renovados si el permiso fue denegado', () async {
      final mensajeria = MessagingFalso(permisoConcedido: false);
      final avisos = NotificacionesFalso();
      final push = ServicioPush(messaging: mensajeria, notificaciones: avisos);
      addTearDown(push.dispose);
      push.configurar();
      await push.registrar('token-api');

      mensajeria.refrescos.add('nuevo-token');
      await pumpEventQueue();

      expect(avisos.registros, isEmpty);
    });

    test('da de baja el token antes de limpiar la sesión', () async {
      final mensajeria = MessagingFalso();
      final avisos = NotificacionesFalso();
      final push = ServicioPush(messaging: mensajeria, notificaciones: avisos);
      addTearDown(push.dispose);
      await push.registrar('token-api');
      push.sincronizarNoLeidas(3);

      await push.desactivar('token-api');

      expect(avisos.bajas, [
        {'token': 'token-api', 'tokenFcm': 'token-fcm'},
      ]);
      expect(push.noLeidas.value, 0);
      expect(mensajeria.tokensObtenidos, 1);
    });

    test('si no hay token FCM no llama a la API al cerrar sesión', () async {
      final mensajeria = MessagingFalso(
        permisoConcedido: false,
        errorToken: StateError('sin token'),
      );
      final avisos = NotificacionesFalso();
      final push = ServicioPush(messaging: mensajeria, notificaciones: avisos);
      addTearDown(push.dispose);
      await push.registrar('token-api');

      await push.desactivar('token-api');

      expect(avisos.bajas, isEmpty);
    });

    test('mantiene el contador de no leídos sin valores negativos', () async {
      final push = ServicioPush(
        messaging: MessagingFalso(),
        notificaciones: NotificacionesFalso(),
      );
      addTearDown(push.dispose);
      push.sincronizarNoLeidas(2);
      expect(push.noLeidas.value, 2);
      push.marcarLeidaLocal();
      expect(push.noLeidas.value, 1);
      push.sincronizarNoLeidas(-5);
      expect(push.noLeidas.value, 0);
      push.marcarLeidaLocal();
      expect(push.noLeidas.value, 0);
    });

    test('cargarMensajeInicial guarda el mensaje para la sesión', () async {
      final mensaje = mensajePrueba();
      final push = ServicioPush(
        messaging: MessagingFalso(mensajeInicial: mensaje),
        notificaciones: NotificacionesFalso(),
      );
      addTearDown(push.dispose);

      await push.cargarMensajeInicial();
      await push.procesarMensajePendiente('token-api');

      expect(push.noLeidas.value, 0);
    });

    group('token de la API vigente (los ID tokens caducan en ~1 h)', () {
      var contador = 0;
      Future<String?> proveedor() async => 'fresco-${++contador}';

      setUp(() => contador = 0);

      test('al abrir un push pide un token fresco, no el capturado', () async {
        final mensajeria = MessagingFalso();
        final avisos = NotificacionesFalso();
        final push = ServicioPush(
          messaging: mensajeria,
          notificaciones: avisos,
        );
        addTearDown(push.dispose);
        push.configurar();
        await push.registrar('token-viejo', proveedorToken: proveedor);

        mensajeria.aperturas.add(
          mensajePrueba(notificacionId: 'a7', reservaId: 'r9'),
        );
        await pumpEventQueue();

        expect(avisos.tokensMarcadas, ['fresco-1']);
      });

      test(
        'al renovarse el token FCM se registra con un token fresco',
        () async {
          final mensajeria = MessagingFalso();
          final avisos = NotificacionesFalso();
          final push = ServicioPush(
            messaging: mensajeria,
            notificaciones: avisos,
          );
          addTearDown(push.dispose);
          push.configurar();
          await push.registrar('token-viejo', proveedorToken: proveedor);

          mensajeria.refrescos.add('nuevo-token');
          await pumpEventQueue();

          expect(avisos.registros.last, {
            'token': 'fresco-1',
            'tokenFcm': 'nuevo-token',
          });
        },
      );

      test('si el proveedor falla usa el último token conocido', () async {
        final mensajeria = MessagingFalso();
        final avisos = NotificacionesFalso();
        final push = ServicioPush(
          messaging: mensajeria,
          notificaciones: avisos,
        );
        addTearDown(push.dispose);
        push.configurar();
        await push.registrar(
          'token-viejo',
          proveedorToken: () async => throw StateError('sin red'),
        );

        mensajeria.aperturas.add(mensajePrueba(notificacionId: 'a7'));
        await pumpEventQueue();

        expect(avisos.tokensMarcadas, ['token-viejo']);
      });
    });
  });
}
