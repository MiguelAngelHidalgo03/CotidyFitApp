# CotidyFitApp
CotidyFit — Mobile fitness app focused on daily consistency. Helping users build sustainable health habits with a simple and accessible system.

Every day counts.

CotidyFit is a mobile app designed to make daily health consistency simple and accessible for everyone.

## Core Philosophy

Consistency over intensity.

## Features (MVP)

- Daily health check-in system
- Basic workout routines
- Weight tracking
- CotidyFit Index (CF Index)
- Streak system

More coming soon.

## Firebase Auth (producción)

### Google Sign-In (Android)

Checklist típico cuando falla con errores como `ApiException: 10` o `sign_in_failed`:

- Activar Google como proveedor en Firebase Console → Authentication → Sign-in method.
- Añadir SHA-1 (y SHA-256 si aplica) del keystore que estés usando:
	- Debug: `android/app/debug.keystore`
	- Release: tu keystore de producción
- Descargar/actualizar `android/app/google-services.json`.
- Ejecutar `flutter clean` y volver a compilar.

### Reset password (idioma + plantilla)

- El cliente fuerza idioma Español para los emails de Auth (`setLanguageCode('es')`).
- La personalización del contenido del email se configura en Firebase Console → Authentication → Templates → Password reset.
