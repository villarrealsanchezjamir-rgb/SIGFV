# SIGFV · Cliente Flutter (APK nativa)

Aplicación **Flutter** que consume la **misma API de Render** que ya usa la web y la APK
anterior (`https://sigfv.onrender.com`) y, por lo tanto, la **misma base de datos Supabase**.

> Esta carpeta es independiente. **No se modificó** `mobile/`, `android/`, `public/`, `api/`,
> ni claves, `.env`, keystore o base de datos del proyecto que ya funciona.

---

## 1. Qué incluye

| Pantalla | Función |
|---|---|
| Arranque | Despierta Render (`/api/health`), reintentos y modo offline |
| Acceso | Empresa + rol + contraseña (`/api/auth/login`), igual que la web |
| Registro público | Empresa cliente solicita vehículos (`/api/public/solicitudes`, origen `apk`) |
| Panel | KPIs, estado de flota, próximos mantenimientos y documentos por vencer |
| Módulos | Agrupados por área, generados desde `/api/meta` según permisos del rol |
| Listados | Búsqueda, paginación, caché local y exportación a Excel |
| Formularios | Dinámicos según el tipo de campo del catálogo (texto, número, fecha, hora, select, textarea, password) |
| Alertas | Documentos, licencias, inspecciones e incidentes |
| Solicitudes | Aprobar/rechazar y asignar vehículo + conductor |
| Perfil | Empresa, rol, pendientes de sincronizar, cambio de contraseña, cierre de sesión |
| Offline | Caché en `SharedPreferences` + cola de cambios (`outbox`) que se envía con `/api/sync` |

La UI no está cableada módulo por módulo: se construye desde `/api/meta`
(`resources`, `cols`, `fields`, permisos `crear/editar/eliminar/exportar`).

---

## 2. Requisitos

- Flutter 3.47+ (probado con **3.47.9** / Dart 3.13.7)
- Android SDK 36 (para compilar la APK)
- JDK 17 (el que trae Android Studio)

Verificar:

```powershell
C:\Users\Usuario\flutter\bin\flutter.bat doctor
```

---

## 3. Ejecutar en el celular (modo desarrollo)

Con el teléfono conectado por USB y depuración USB activa:

```powershell
cd "C:\Users\Usuario\Downloads\SIGFV-main\flutter_app"
C:\Users\Usuario\flutter\bin\flutter.bat devices
C:\Users\Usuario\flutter\bin\flutter.bat run
```

## 4. Generar la APK

```powershell
cd "C:\Users\Usuario\Downloads\SIGFV-main\flutter_app"
C:\Users\Usuario\flutter\bin\flutter.bat build apk --release
```

Archivo resultante:

```
flutter_app\build\app\outputs\flutter-apk\app-release.apk
```

Cópielo al teléfono e instálelo (permitir "instalar apps de origen desconocido").

> El `applicationId` es **`com.sigfv.flutterapp`**, distinto del `com.sigfv.app` de la APK
> Capacitor. Así ambas pueden convivir instaladas sin conflicto.

## 5. Apuntar a otro servidor (opcional)

La URL está centralizada en `lib/config.dart` y por defecto es Render:

```dart
defaultValue: 'https://sigfv.onrender.com'
```

Sin tocar código:

```powershell
flutter run --dart-define=API_BASE=https://otro-servidor
```

---

## 6. Acceso de prueba

Del `README.md` del proyecto original:

- **Empresa:** «Compañía Minera Andina del Perú S.A.C.» (o «Todas las empresas»)
- **Rol:** Administrador
- **Contraseña:** `SIGFV.Admin.2026`

Las credenciales no se modificaron ni se guardaron en el código: se escriben en el login,
se guarda solo el token JWT en el almacenamiento local del dispositivo.

---

## 7. Notas técnicas

- **Modo offline:** al abrir por primera vez se cachean `/api/meta`, dashboard, alertas,
  listados y catálogos. Sin internet se consulta la caché y los cambios se guardan en una
  cola (`sigfv_outbox`) que se sincroniza con `POST /api/sync` al volver la conexión.
  Los registros pendientes se muestran con un icono de nube y `id` negativo.
- **Exportación Excel:** abre `GET /api/export/{recurso}?token=...` en el navegador del
  teléfono (mismo mecanismo que la app anterior).
- **Fechas:** se envían como `AAAA-MM-DD` y las de tipo `datetime` como `AAAA-MM-DD HH:mm`,
  idéntico a lo que envía la web.
- **NDK:** el proyecto no tiene código nativo; se quitó `ndkVersion` del
  `android/app/build.gradle.kts` para no exigir la descarga del NDK.
- **Icono y arranque:** el icono se genera con `tools/make_icon.ps1` (monograma «SF»
  dorado sobre fondo oscuro). La pantalla de arranque nativa usa el mismo fondo
  `#171717` para que no haya destello blanco antes de la pantalla de carga de Flutter.

## 8. Estructura

```
flutter_app/
├── lib/
│   ├── main.dart               # MaterialApp + idioma es-PE + gate de estado
│   ├── config.dart             # URL de la API
│   ├── theme.dart              # paleta y estilos de la app original
│   ├── models.dart             # meta, recursos, campos, outbox
│   ├── api_client.dart         # HTTP + manejo de errores/offline
│   ├── state/app_state.dart    # sesión, caché, cola offline, sync, export
│   ├── widgets/common.dart     # badges, dropdowns, formatos, diálogos
│   └── screens/                # boot, login, registro público, panel, módulos,
│                               # listado, formulario, alertas, solicitudes, perfil
├── android/                    # proyecto Android (com.sigfv.flutterapp)
└── pubspec.yaml
```
