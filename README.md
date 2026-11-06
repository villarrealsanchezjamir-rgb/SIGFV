# SIGFV · Sistema Integral de Gestión de Flota Vehicular

Sistema web + aplicación Android para la gestión de flota vehicular, ahora con **Supabase (PostgreSQL)** como base de datos única.

```
Web (navegador) ───────┐
                       ├──► API Express en la nube (HTTPS) ───► Supabase PostgreSQL
APK Android ───────────┘
```

La web y la APK usan **la misma API y la misma base de datos en Supabase**. La app Android puede ejecutarse en cualquier red (Wi-Fi o datos) siempre que el backend esté accesible.

> **Producción / uso real:** no deje el backend dependiendo de una PC. Despliegue el API en la nube con HTTPS; así la web y la APK funcionan desde cualquier red y sin abrir VS Code. Guía completa: **[DEPLOY.md](DEPLOY.md)**.

---

## 1. Lo que ya está hecho

- Esquema de ~50 tablas migrado de MySQL a **PostgreSQL 17 de Supabase**.
- Enums, restricciones, índices, triggers de negocio y funciones adaptados a PostgreSQL.
- Datos iniciales (estados, tipos, permisos, roles, configuraciones) cargados.
- Seguridad a nivel de base de datos: **RLS activado** y permisos revocados para `anon`/`authenticated`; solo el backend accede.
- Backend Express reescrito con `pg` y conexión al **pooler de Supabase**.
- Login, permisos por módulo/acción, auditoría y CRUD genérico funcionando.
- Frontend de escritorio rediseñado (barra lateral agrupada, dashboard, tablas, formulario lateral).
- App Android con **Capacitor** compilada y firmada, con interfaz exclusiva para celulares.
- APK release listo para instalar: **`dist/SIGFV-2.1.0.apk`** (URL del backend grabada, no se pide al usuario).
- Despliegue en la nube preparado (Render, Railway, Fly.io y VPS con Docker + Caddy). Ver **`DEPLOY.md`**.
- Keep-alive para Render en `.github/workflows/keepalive.yml`.

---

## 2. Requisitos

- Node.js 20 o superior (solo para desarrollo local o para ejecutar el backend en un servidor propio).
- Una cuenta/proyecto de Supabase (ya configurado en este proyecto).
- Para producción: un servicio siempre activo con HTTPS (Render, Railway, Fly.io o VPS). Ver **[DEPLOY.md](DEPLOY.md)**.
- Para recompilar el APK: JDK 21 + Android SDK (ver sección 6.3).

---

## 3. Inicio rápido (solo desarrollo local)

```bash
npm install
npm start
```

Abra <http://localhost:3000>.

> Esto levanta el backend en la PC y se detiene al cerrar la terminal o VS Code. Para que la web y la APK funcionen sin la PC, siga **[DEPLOY.md](DEPLOY.md)**.

Credenciales iniciales del administrador:

| Campo | Valor |
|---|---|
| Usuario | `admin` |
| Contraseña | `Sigfv2026!` |

> Cambie la contraseña desde **Usuarios → admin → Editar** después del primer ingreso.

Si la base se reinicia o se crea un proyecto Supabase nuevo:

```bash
npm run db:setup      # aplica database/01_SIGFV_Supabase.sql (BORRA las tablas SIGFV)
npm run crear-admin   # crea el administrador (solo una vez)
```

---

## 4. Configuración de Supabase

El archivo `.env` contiene las credenciales del proyecto (no lo comparta ni lo suba a Git). En la nube, esos valores se configuran en el panel del proveedor:

```env
SUPABASE_URL=https://TU_PROYECTO.supabase.co
SUPABASE_ANON_KEY=TU_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=TU_SERVICE_ROLE_KEY
SUPABASE_DB_URL=postgresql://postgres.PROYECTO:PASSWORD@REGION.pooler.supabase.com:6543/postgres
JWT_SECRET=UNA_CADENA_LARGA_Y_ALEATORIA_DE_32_O_MAS_CARACTERES
```

- `SUPABASE_DB_URL` es la cadena del **pooler** (Project Settings → Database → Connection string).
- `SUPABASE_SERVICE_ROLE_KEY` se usa **solo en el servidor**; nunca la incluya en la APK ni en el frontend.
- Para comprobar la conexión: <http://localhost:3000/api/health>.

```json
{
  "ok": true,
  "version": "2.0.1",
  "database": "Supabase PostgreSQL",
  "supabase": { "configured": true, "ok": true }
}
```

El esquema está en **`database/01_SIGFV_Supabase.sql`**. El archivo MySQL original quedó en `database/legacy/` solo como referencia y **no se usa**.

> `JWT_SECRET` debe tener 32+ caracteres. Cámbielo en producción.

---

## 5. Módulos disponibles

Dashboard con datos reales · Vehículos · Conductores y licencias · Asignaciones (valida estado del vehículo, licencia vigente y cruces de fechas en la base de datos) · Mantenimiento · Documentación y vencimientos · Inspecciones (una inspección no conforme puede dejar el vehículo fuera de servicio) · Combustible · Incidentes · Notificaciones · Usuarios y roles · Configuración · Historial de estados y auditoría · Exportación CSV.

---

## 6. APK para Android

### 6.1 Instalar

1. Copie la APK **`dist/SIGFV-2.1.0.apk`** al teléfono (cable, WhatsApp, Drive, etc.).
2. Permita **Instalar aplicaciones de origen desconocido** para el explorador/gestor de archivos.
3. Abra el APK e instale.

La APK está firmada (release) con el keystore `android/sigfv-release.keystore` y `android/keystore.properties`. Conserve ambos archivos y sus contraseñas en un lugar seguro: son necesarios para publicar actualizaciones de la misma app. No los suba a Git (ya están en `.gitignore`).

### 6.2 Conexión con el backend (URL interna)

La APK **no pide ni muestra la URL del servidor**: `https://sigfv.onrender.com` va grabada en el código al compilar. El usuario solo ingresa su usuario y contraseña.

- Al abrir, la app comprueba `/api/health` y reintenta automáticamente mientras Render despierta.
- Mientras la app está en uso, envía un ping cada 4 minutos para mantener el servicio activo.
- Para compilar contra otro servidor (por ejemplo, un entorno de pruebas):
  ```powershell
  $env:PUBLIC_API_URL = "https://otro-servidor"; npm run mobile:build
  ```

> **Disponibilidad 24/7:** el plan gratuito de Render suspende el servicio tras ~15 minutos sin tráfico. El workflow `.github/workflows/keepalive.yml` hace una petición cada 10 minutos para mantenerlo despierto, pero GitHub Actions puede retrasarse o pausarse si el repositorio pasa 60 días sin actividad. Para disponibilidad garantizada use el plan pago de Render (o Fly.io/VPS con proceso permanente).

### 6.3 Recompilar el APK

Requisitos: JDK 21, Android SDK (platform 35, build-tools 35), `android/local.properties` con la ruta del SDK y el keystore de firma.

Para la APK release firmada (usa la URL de producción por defecto):

```powershell
npm run mobile:apk:public
```

Para grabar otra URL pública:

```powershell
npm run mobile:apk:public -- https://sigfv.midominio.com
```

Salida: `android/app/build/outputs/apk/release/app-release.apk` y copia automática a `dist/SIGFV-2.1.0.apk`.

Para la release sin copiar a `dist`:

```powershell
npm run mobile:release
```

Para una APK de depuración:

```powershell
npm run mobile:apk
```

Salida: `android/app/build/outputs/apk/debug/app-debug.apk`.

> La versión actual es `versionCode 3` / `versionName 2.1.0`. Aumente `versionCode` en `android/app/build.gradle` antes de cada nueva publicación para que Android permita actualizar sobre la APK anterior.

> `npm run mobile:apk:public` busca automáticamente un JDK 21 instalado. Si usa `npm run mobile:release` directamente, defina `JAVA_HOME` al JDK 21 (Gradle 8.11 no usa Java 25).

`mobile/www` se genera automáticamente desde `mobile/app/` (diseño exclusivo para celulares) con `scripts/build-mobile.js`; no lo edite a mano. La web de escritorio vive en `public/` y tiene su propio diseño. `PUBLIC_API_URL` se toma del entorno, no de `.env`, para evitar grabar una IP local por accidente.

---

## 7. Estructura del proyecto

```
SIGFV/
├─ server.js                 API REST + servidor de la web
├─ db.js                     Pool PostgreSQL → Supabase
├─ .env                      Credenciales locales (NO compartir)
├─ .env.example              Plantilla de variables
├─ .env.production.example   Plantilla para VPS
├─ public/                  Web de escritorio (diseño propio)
│  ├─ index.html
│  ├─ app.css
│  ├─ app.js
│  ├─ manifest.webmanifest
│  ├─ sw.js
│  └─ icon.svg
├─ mobile/
│  ├─ app/                    Interfaz exclusiva de la APK (fuente)
│  │  ├─ index.html
│  │  ├─ app.css
│  │  ├─ app.js
│  │  └─ config.js
│  └─ www/                   Copia empaquetada (generada)
├─ database/
│  ├─ 01_SIGFV_Supabase.sql  Esquema PostgreSQL (Supabase)
│  └─ legacy/                Esquema MySQL original (no usado)
├─ scripts/
│  ├─ crear-admin.js
│  ├─ setup-db.js
│  ├─ build-mobile.js
│  ├─ build-apk-public.js
│  └─ healthcheck.js
├─ android/                  Proyecto Android (Capacitor)
├─ .github/workflows/        Keep-alive de Render
├─ dist/                     APKs generadas
├─ capacitor.config.json
├─ Dockerfile
├─ docker-compose.yml        VPS + Caddy
├─ Caddyfile                 HTTPS automático
├─ render.yaml               Render
├─ railway.json              Railway
├─ fly.toml                  Fly.io
├─ DEPLOY.md                 Guía de despliegue en la nube
├─ README.md
└─ package.json
```

---

## 8. Seguridad

- Contraseñas con **bcrypt** (coste 12); nunca se guardan en claro.
- Sesión con JWT de 8 h.
- Bloqueo de cuenta tras 5 intentos fallidos (15 min).
- Permisos verificados en el servidor por módulo y acción.
- Consultas **parametrizadas** (`$1`, `$2`, …).
- Escape de HTML en el frontend.
- Registro de accesos y auditoría de cambios.
- **RLS activado** en todas las tablas; `anon` y `authenticated` no pueden leer ni escribir directamente.
- La `service_role` key y la contraseña de la base viven solo en `.env` o en las variables del proveedor (nunca en la APK ni en el frontend).
- `.env`, `.env.production`, `android/keystore.properties` y `android/*.keystore` están excluidos de Git y Docker.
- CORS habilitado en `/api` con autenticación por Bearer token (no usa cookies).
- En producción use siempre HTTPS.

> **Importante:** el archivo `.env` de este proyecto contiene credenciales reales. No lo suba a repositorios públicos ni lo comparta. Si se filtró, rote la contraseña de la base, la `service_role` key y el `JWT_SECRET`. Cambiar el `JWT_SECRET` invalida las sesiones activas.

---

## 9. Solución de problemas

| Síntoma | Causa / solución |
|---|---|
| `Falta SUPABASE_DB_URL` | Complete `.env` o la variable del proveedor con la cadena del pooler. |
| `Defina JWT_SECRET (32+ caracteres)` | `JWT_SECRET` vacío o demasiado corto. |
| `Sesión no iniciada o vencida` | El token expiró (8 h); vuelva a iniciar sesión. |
| Error de conexión en la APK | Verifique que el backend esté encendido, la URL sea correcta y el teléfono tenga red. En LAN, revise el firewall. |
| La APK no abre datos | Toque el icono de servidor en la cabecera y corrija la URL. Si la APK trae una IP vieja, use la URL pública. |
| En otra PC no aparecen los registros | Esa PC está usando otro backend u otro proyecto Supabase. Abra `https://SU_BACKEND/api/health` y compare las credenciales. |
| La APK solo funciona en la Wi-Fi de la PC | La APK tiene grabada una IP LAN. Recompile con `npm run mobile:apk:public -- https://...` o cambie la URL desde la app. |
| La IP de la PC cambió y dejó de funcionar | Use IP fija/reserva DHCP o, mejor, un backend público con dominio. |
| `relation "..." does not exist` | Solo en instalación inicial: `npm run db:setup`. **No lo ejecute sobre una base con datos: borra las tablas.** |
| Se borraron los datos | Alguien ejecutó `db:setup` o se apuntó a otro proyecto Supabase. Restaure el respaldo. |
| Supabase pausado | En el plan gratuito el proyecto se pausa por inactividad; reactívelo en el panel de Supabase. |
| Render free tarda en abrir | El plan free duerme el servicio; la primera visita puede tardar ~1 minuto. Use un plan siempre activo para producción. |
| 502/503 en el backend | La app no escucha en el puerto `PORT` o falló el arranque. Revise los logs del proveedor. |

---

## 10. Créditos

Interfaz y lógica originales de SIGFV; migración a Supabase, API PostgreSQL, PWA y app Android integradas en esta versión.
