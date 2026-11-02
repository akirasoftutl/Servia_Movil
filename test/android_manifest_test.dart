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

  test('release no habilita tráfico sin cifrar ni configuración alternativa', () {
    final contenido = manifiesto.readAsStringSync();
    expect(contenido, isNot(contains('usesCleartextTraffic="true"')));
    expect(contenido, isNot(contains('networkSecurityConfig')));
  });
}
