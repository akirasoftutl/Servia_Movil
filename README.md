# Servia - App Cliente

Aplicación móvil para clientes del ecosistema Servia, desarrollada con Flutter. Permite a los usuarios acceder a servicios, gestionar su cuenta e interactuar con la plataforma de forma ágil y segura.

---

## Requisitos Previos

Asegúrate de tener instalado y configurado en tu entorno local:

- **Flutter SDK**: `>=3.0.0`
- **Dart SDK**: `>=3.0.0`
- **Android Studio** o **VS Code** con extensiones de Flutter/Dart.
- Emulador de Android o dispositivo físico configurado en modo depuración.

---

## Instalación y Configuración

1. **Clonar el repositorio:**
   ```bash
   git clone [https://github.com/Akirasoft/Servia_FE.git](https://github.com/Akirasoft Servia_FE.git)
   cd Servia_FE
   ```

2. **Instalar Dependencias**
    Comando: flutter pub get

## Acceso con Google

El botón «Continuar con Google» ya está conectado. Para que funcione hay que **activar el proveedor Google y volver a descargar las credenciales de Firebase**: el `google-services.json` debe traer el cliente OAuth web (`client_type: 3`) y el cliente Android con la huella SHA del APK (`client_type: 1`).

1. En Firebase Console → **Authentication → Sign-in method**, activa **Google** y guarda.
2. **Android:** registra el SHA-1 de debug y el de release en la app Android de Firebase (Configuración del proyecto → Tus apps). Descarga el `google-services.json` nuevo y reemplaza `android/app/google-services.json`. Debe contener un `oauth_client` con `client_type: 3` (web). Si usas FlutterFire CLI:

   ```bash
   flutterfire configure --project=servia-akirasoft \
     --android-package-name=com.akirasoft.servia \
     --android-out=android/app/google-services.json
   ```

3. **iOS:** si todavía no existe la app iOS con bundle `com.akirasoft.servia`, regístrala en Firebase. Descarga `GoogleService-Info.plist` y cópialo a `ios/Runner/GoogleService-Info.plist` (añádelo al target Runner en Xcode). Después copia la plantilla y rellena los tres valores:

   ```bash
   cp ios/Flutter/GoogleSignIn.template.xcconfig ios/Flutter/GoogleSignIn.xcconfig
   ```

   - `GOOGLE_CLIENT_ID`: `CLIENT_ID` del plist.
   - `GOOGLE_SERVER_CLIENT_ID`: ID de cliente web del proyecto (el mismo `client_type: 3` de Android).
   - `GOOGLE_REVERSED_CLIENT_ID`: `REVERSED_CLIENT_ID` del plist.

   `GoogleSignIn.xcconfig` y `GoogleService-Info.plist` están ignorados por Git.

4. Reinicia la app desde cero (no solo hot reload). La primera vez que una cuenta de Google entra, la API crea su perfil de cliente con nombre y correo del token y le asigna el claim `tipo: cliente`; no hace falta contraseña ni rellenar el formulario de registro.

### Si al elegir la cuenta dice «Se canceló el acceso con Google»

En Android, `google_sign_in` usa Credential Manager, que devuelve `canceled` también cuando Firebase no reconoce el certificado del APK. No es una cancelación del usuario: falta registrar la huella SHA.

1. Obtén la huella del certificado con el que firmas:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android -keypass android
   ```

   En este repo el build release también se firma con la de debug (`android/app/build.gradle.kts`), así que con esa huella basta para `flutter run` y para `--release`.

2. En Firebase Console → **Configuración del proyecto → Tus apps → app Android**, añade el **SHA-1 y el SHA-256** y guarda.

3. Habilita Google en **Authentication → Sign-in method** y vuelve a descargar `google-services.json`. Además del `oauth_client` con `client_type: 3` (web), debe aparecer uno con `client_type: 1` y `certificate_hash`. Copiar solo el ID de cliente web a mano no basta.

4. Desinstala la app del dispositivo (Credential Manager guarda el fallo) y vuelve a ejecutarla.

Si el mensaje sigue apareciendo, ejecuta con `flutter run` y revisa el `flutter log`: se imprime `GoogleSignIn: canceled <descripción>`; `Account reauth failed` confirma que el SHA o el paquete no coinciden.

## Mapa de Google

La pestaña **Buscar** muestra el mapa de negocios cercanos de fondo con la lista en una hoja deslizable. Usa el SDK de Google Maps para Android (`google_maps_flutter`). La llave de la API **no se commitea**: `android/app/build.gradle.kts` la lee de `android/local.properties` (ignorado por Git) o de la variable de entorno `MAPS_API_KEY`, con valor vacío por defecto para que la compilación y las pruebas funcionen sin llave.

1. En Google Cloud Console, activa **Maps SDK for Android** y crea una API key.
2. Restringe la llave a **Maps SDK for Android**, al paquete Android `com.akirasoft.servia` y a las huellas **SHA-1** de firma (depuración y release).
3. Configúrala en local agregando a `android/local.properties`:
   ```properties
   MAPS_API_KEY=TU_LLAVE_DE_GOOGLE_MAPS
   ```
   O exportándola en tu entorno antes de compilar:
   ```bash
   export MAPS_API_KEY=TU_LLAVE_DE_GOOGLE_MAPS
   ```

Sin llave configurada, el lienzo del mapa se muestra vacío/gris, pero la lista de lugares cercanos y el resto de la aplicación siguen funcionando sin cierres.

# Pruebas y Análisis de Código

**Ejecutar el linter y análisis estático**

    Comando: flutter analyze

**Ejecutar la suite de pruebas unitarias y de widgets**
    Comando: flutter test

## Integración continua

GitHub Actions realiza una revisión automática en cada pull request hacia `dev` y `main`, y en cada push a esas ramas. El workflow **Integración continua** ejecuta el job **Verificar la app** en Ubuntu con Flutter del canal estable.

El CI crea `lib/core/firebase/firebase_options.dart` solo en el runner con valores ficticios y sin secretos, porque el archivo está ignorado en Git y el código lo necesita para el análisis.

La revisión instala las dependencias con `flutter pub get`, analiza el código con `flutter analyze` y ejecuta las pruebas con `flutter test`. Si algún paso falla, la revisión queda en rojo; si todos pasan, queda en verde. Consulta el resultado en la pestaña **Checks** del pull request o en **Actions** del repositorio.
