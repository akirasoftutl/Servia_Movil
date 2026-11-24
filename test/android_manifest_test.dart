import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifiesto = File('android/app/src/main/AndroidManifest.xml');

  test('el manifiesto principal permite internet antes de application', () {
    final contenido = manifiesto.readAsStringSync();
    final permiso = RegExp(
      r'<uses-permission\s+android:name="android.permission.INTERNET"\s*/>',
    ).firstMatch(contenido);
    expect(permiso, isNotNull);
    expect(permiso!.start, lessThan(contenido.indexOf('<application')));
  });

  test('declara POST_NOTIFICATIONS para Android 13 o más nuevo', () {
    final contenido = manifiesto.readAsStringSync();
    final permiso = RegExp(
      r'<uses-permission\s+android:name="android.permission.POST_NOTIFICATIONS"\s*/>',
    ).firstMatch(contenido);
    expect(permiso, isNotNull);
    expect(permiso!.start, lessThan(contenido.indexOf('<application')));
  });

  test('consulta aplicaciones externas que pueden abrir https', () {
    final contenido = manifiesto.readAsStringSync();
    final consultas = RegExp(r'<queries>([\s\S]*?)</queries>')
        .firstMatch(contenido)!
        .group(1)!;
    expect(
      consultas,
      matches(
        RegExp(
          r'<intent>\s*<action android:name="android.intent.action.VIEW"\s*/>\s*<data android:scheme="https"\s*/>\s*</intent>',
        ),
      ),
    );
  });

  test('release no habilita tráfico sin cifrar ni configuración alternativa', () {
    final contenido = manifiesto.readAsStringSync();
    expect(contenido, isNot(contains('usesCleartextTraffic="true"')));
    expect(contenido, isNot(contains('networkSecurityConfig')));
  });

  test('declara la llave de Google Maps por placeholder sin commitear secretos', () {
    final contenido = manifiesto.readAsStringSync();
    expect(
      contenido,
      matches(
        RegExp(
          r'<meta-data\s+android:name="com\.google\.android\.geo\.API_KEY"\s+android:value="\$\{MAPS_API_KEY\}"\s*/>',
        ),
      ),
    );
    expect(contenido, isNot(contains('AIza')));

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('manifestPlaceholders["MAPS_API_KEY"]'));
    expect(gradle, contains('local.properties'));
    expect(gradle, contains('System.getenv("MAPS_API_KEY")'));
    expect(gradle, isNot(contains('AIza')));
  });
}
