# Servia_BE

@../Servia_Contexto/AGENTS.md

## Este repo

- **Qué es:** la API de Servia en NestJS. Es la única pieza que escribe en Firestore y la que hace cumplir las reglas de negocio.
- **Historias que le tocan:** todas, en su parte de backend.

## Comandos

- Instalar dependencias: `npm install`
- Correr en local: `cp .env.example .env` y `npm run start:dev` (Swagger en http://localhost:3000/docs)
- Pruebas: `npm test` (unitarias) y `npm run test:e2e`
- Lint: `npm run lint` (oxlint); formato: `npm run format` (Prettier)

## Convenciones del código

- NestJS 12 con módulos ES: los imports locales llevan `.js` (`./salud.module.js`).
- Todo acceso a Firebase pasa por `FirebaseService` (`src/comun/firebase`).
- Las rutas son privadas por defecto (guard global); las públicas llevan `@Publico()`. El usuario se obtiene con `@UsuarioActual()`.
- Las reglas de negocio se validan aquí, nunca solo en las apps (decisión T3).

## Cómo trabajar aquí

- Cada issue de este repo es la parte de la API de una historia (o una tarea técnica), con su propia rama y su PR hacia `dev`. Lee sus secciones *Qué hay que hacer*, *Criterios* y *Cómo probarlo* antes de programar.
- Antes de abrir un PR que toque reservas, horarios o cuentas, usa la skill `verificar-reglas`.
