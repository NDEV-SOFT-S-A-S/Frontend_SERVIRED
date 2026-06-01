# Frontend SERVIRED

Plataforma digital SERVIRED — Flutter Web + Móvil.

## Stack

| Elemento | Decisión |
|----------|----------|
| Framework | Flutter 3.x (web + móvil) |
| Lenguaje | Dart 3.x |
| Estado | flutter_bloc (BLoC/Cubit) |
| HTTP | dio + interceptores |
| Navegación | go_router |
| DI | get_it |
| Storage seguro | flutter_secure_storage |
| Entorno | flutter_dotenv |

## Arquitectura

```
Presentación → Estado (Cubit) → Repositorio → DataSource (API)
```

Estructura modular por feature. Ver `SPEC-FE-001.md` para detalle completo.

## Prerrequisitos

- Flutter SDK >= 3.3.0
- Dart SDK >= 3.3.0

Instalar Flutter: https://docs.flutter.dev/get-started/install/windows

## Comandos

```bash
# Instalar dependencias
flutter pub get

# Levantar en desarrollo (web)
flutter run -d chrome --dart-define=APP_ENV=dev

# Levantar en móvil
flutter run --dart-define=APP_ENV=dev

# Build web
flutter build web --dart-define=APP_ENV=prod

# Build APK
flutter build apk --dart-define=APP_ENV=prod

# Tests
flutter test

# Tests con cobertura
flutter test --coverage

# Análisis estático
flutter analyze
```

## Variables de entorno

Los archivos `.env.dev`, `.env.uat` y `.env.prod` están en la raíz.
Contienen únicamente `API_BASE_URL` y `APP_ENV`.
**Nunca** deben contener credenciales, tokens ni URLs de Codesa/SuperFlex.

## Módulos

| Módulo | Estado | HU |
|--------|--------|-----|
| auth | ✅ Implementado | HU-LOG001, HU-LOG002 |
| juegos | 🔲 Pendiente | — |
| pagos | 🔲 Pendiente | — |
| wallet | 🔲 Pendiente | — |

## Documentación

Ver `C:\Users\StivenR\Documents\NDEVSOFT\DEV\VARIOS\SERVIRED\Claude\Projects\SERVIRED - Frontend`
