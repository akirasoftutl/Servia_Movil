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

# Pruebas y Análisis de Código

**Ejecutar el linter y análisis estático**

    Comando: flutter analyze

**Ejecutar la suite de pruebas unitarias y de widgets**
    Comando: flutter test

## Integración continua

GitHub Actions realiza una revisión automática en cada pull request hacia `dev` y `main`, y en cada push a esas ramas. El workflow **Integración continua** ejecuta el job **Verificar la app** en Ubuntu con Flutter del canal estable.

La revisión instala las dependencias con `flutter pub get`, analiza el código con `flutter analyze` y ejecuta las pruebas con `flutter test`. Si algún paso falla, la revisión queda en rojo; si todos pasan, queda en verde. Consulta el resultado en la pestaña **Checks** del pull request o en **Actions** del repositorio.
