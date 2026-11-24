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

## Mapa de Google

La pantalla **Ver mapa** de «Cerca de ti» usa el SDK de Google Maps para Android (`google_maps_flutter`). La llave de la API **no se commitea**: `android/app/build.gradle.kts` la lee de `android/local.properties` (ignorado por Git) o de la variable de entorno `MAPS_API_KEY`, con valor vacío por defecto para que la compilación y las pruebas funcionen sin llave.

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
