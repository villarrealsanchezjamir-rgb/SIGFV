# Despliegue de SIGFV en la nube (Opción A)

Esta guía deja la web y la APK usando **un backend público con HTTPS** y la **misma base de datos Supabase**. Al terminar:

- La web se abre desde una URL (`https://...`), sin VS Code y sin PC encendida.
- La APK funciona desde Wi-Fi o datos móviles, sin estar en la red de la PC.
- Los registros son los mismos para web y APK porque ambos usan el mismo backend y la misma base.

```
Web (navegador) ─┐
                 ├──► Backend .NET 10 público (HTTPS) ───► Supabase PostgreSQL
APK (Android) ───┘
```

> La base de datos ya está en Supabase. Lo único que hay que mover a la nube es el backend (`api/`), que se compila con el `Dockerfile` incluido.

---

## 1. Requisitos

- Cuenta en **Render** (recomendado), **Railway**, **Fly.io** o un **VPS** con Docker.
- El proyecto en un repositorio de GitHub (Render/Railway) o acceso SSH al VPS.
- Los valores reales del archivo `.env` actual:
  - `JWT_SECRET`
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `SUPABASE_DB_URL`
- Opcional: un dominio propio.

**Nunca suba `.env` al repositorio.** Ya está excluido en `.gitignore` y `.dockerignore`.

---

## 2. Suba el proyecto a GitHub

El proyecto ya tiene un repositorio Git local inicializado en la rama `main`, con un commit inicial. Solo falta crear el repositorio vacío en GitHub y subirlo:

```powershell
cd C:\Users\anghe\Downloads\SIGFV
git status
git remote add origin https://github.com/USUARIO/SIGFV.git
git push -u origin main
```

Antes de subir, confirme que **no** aparecen en Git:

- `.env`
- `android/keystore.properties`
- `android/sigfv-release.keystore`
- `node_modules`
- `dist`
- `mobile/www`

> Si copia el proyecto a otra PC sin la carpeta `.git`, ejecute `git init`, `git add .` y `git commit -m "SIGFV listo para despliegue"` antes de agregar el remoto.

> Guarde el keystore y su contraseña en un lugar seguro. Sin ellos no podrá firmar actualizaciones de la APK.

---

## 3. Opción recomendada: Render

Render puede leer el archivo `render.yaml` incluido y crear el servicio automáticamente.

1. Entre a <https://render.com> y cree una cuenta.
2. **New → Blueprint**.
3. Conecte GitHub y seleccione el repositorio `SIGFV`.
4. Render detectará `render.yaml`. Complete las variables que pida:
   - `JWT_SECRET` (32 caracteres o más)
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_DB_URL`
5. Deploy.
6. Espere a que el estado sea **Live**.
7. Abra `https://NOMBRE.onrender.com/api/health`. Debe responder:

```json
{
  "ok": true,
  "version": "2.0.1",
  "database": "Supabase PostgreSQL",
  "supabase": { "configured": true, "ok": true }
}
```

La web queda en `https://NOMBRE.onrender.com/`.

### Notas de Render

- El plan **free** “duerme” el servicio tras unos minutos de inactividad; la primera visita puede tardar hasta ~1 minuto. Para uso real cambie a `plan: starter` en `render.yaml` (aprox. USD 7/mes).
- Render asigna el puerto mediante la variable `PORT`; no la configure manualmente.
- Si el deploy falla, revise **Logs**. Los errores más comunes son variables faltantes o la base Supabase pausada.
- Para dominio propio: **Settings → Custom Domains**, agregue el dominio y cree el CNAME que indica Render.

### Probar el backend

```powershell
npm run health -- https://NOMBRE.onrender.com
```

---

## 4. Opción: Railway

1. Cree una cuenta en <https://railway.app>.
2. **New Project → Deploy from GitHub repo** y seleccione `SIGFV`.
3. Railway usará el `Dockerfile` (también existe `railway.json` con el health check).
4. En **Variables**, agregue las cinco variables de Supabase y `JWT_SECRET`.
5. En **Settings → Networking → Generate Domain**.
6. Verifique `https://DOMINIO/api/health`.
7. La web queda en `https://DOMINIO/`.

Railway no tiene plan gratuito permanente; revise su plan vigente antes de usarlo.

---

## 5. Opción: Fly.io

1. Instale `flyctl`:

```powershell
iwr https://fly.io/install.ps1 -useb | iex
```

2. Inicie sesión:

```powershell
fly auth login
```

3. Edite `fly.toml` y cambie `app = "sigfv"` por un nombre único (por ejemplo `sigfv-tuempresa`).
4. Cree la app y configure los secretos:

```powershell
fly apps create sigfv-tuempresa
fly secrets set JWT_SECRET="..." SUPABASE_URL="..." SUPABASE_ANON_KEY="..." SUPABASE_SERVICE_ROLE_KEY="..." SUPABASE_DB_URL="..."
```

5. Despliegue:

```powershell
fly deploy
```

6. Abra la app:

```powershell
fly open
```

7. Verifique `https://sigfv-tuempresa.fly.dev/api/health`.

`fly.toml` está configurado con `min_machines_running = 1` para que no se apague. Revise los costos de Fly antes de usarlo.

---

## 6. Opción: VPS con Docker + Caddy (HTTPS automático)

Requisitos: VPS Ubuntu 22.04/24.04, Docker Engine y Docker Compose.

1. Instale Docker:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Cierre sesión y vuelva a entrar.

2. Apunte el DNS del dominio a la IP del VPS (registro A).
3. Copie el proyecto al VPS (git clone o scp).
4. Abra los puertos:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

5. Cree `.env.production`:

```bash
cp .env.production.example .env.production
nano .env.production
```

Complete `DOMAIN`, `JWT_SECRET` y las variables de Supabase.

6. Levante los contenedores:

```bash
docker compose --env-file .env.production up -d --build
```

7. Verifique:

```bash
docker compose logs -f sigfv
curl https://TU_DOMINIO/api/health
```

Caddy obtiene y renueva el certificado HTTPS automáticamente.

### Actualizar en el VPS

```bash
git pull
docker compose --env-file .env.production up -d --build
```

> Si usa Cloudflare como proxy, configure SSL/TLS en **Full (strict)** o use **DNS only** para que Caddy pueda validar el certificado.

---

## 7. Configurar la APK

La APK anterior (`dist/SIGFV-2.0.0.apk`) trae grabada `http://192.168.1.242:3000`, una IP de la PC original. En otra red no funcionará. La nueva `dist/SIGFV-2.0.1-sin-url.apk` ya no trae IP: pide la URL al iniciar sesión.

### 7.1 Cambio rápido, sin recompilar

Ya existe una APK release firmada y validada, `dist/SIGFV-2.0.1-sin-url.apk`, que no trae URL grabada y la pide al iniciar sesión. Sirve para probar el backend apenas esté desplegado:

1. Instale `dist/SIGFV-2.0.1-sin-url.apk` (o la APK vieja).
2. En la pantalla de inicio de sesión, escriba la URL pública en **Servidor SIGFV**:
   `https://NOMBRE.onrender.com` (o su dominio).
3. También puede cambiarla después con el botón de servidor en la cabecera.

Esto sirve para probar, pero la URL queda guardada por dispositivo.

### 7.2 APK definitiva con la URL grabada

Requisitos en Windows:

- JDK 21 (ya instalado en este equipo).
- Android SDK 35.
- `android/local.properties` con la ruta correcta al SDK.
- `android/keystore.properties` y `android/sigfv-release.keystore` (firma).

Compile la release con la URL pública:

```powershell
cd C:\Users\anghe\Downloads\SIGFV
npm run mobile:apk:public -- https://NOMBRE.onrender.com
```

El comando compila la release, la firma y **copia automáticamente** el resultado a `dist\SIGFV-2.0.1.apk`. Al final muestra la ruta:

```
APK lista para instalar: ...\dist\SIGFV-2.0.1.apk
```

También queda el archivo intermedio en `android\app\build\outputs\apk\release\app-release.apk`.

> La versión ya está incrementada a `versionCode 2` / `versionName 2.0.1` para que Android permita actualizar sobre la APK anterior. Para futuras versiones, incremente `versionCode` en `android/app/build.gradle`.

> `npm run mobile:apk:public` busca automáticamente un JDK 21 instalado. Si ejecuta `npm run mobile:release` directamente, defina `JAVA_HOME` al JDK 21; Gradle 8.11 no debe usar el JBR 25 de Android Studio.

### 7.3 Si actualiza la APK sobre la anterior

La aplicación descarta automáticamente la URL vieja guardada cuando detecta una nueva URL pública grabada. Eso incluye cualquier URL que se haya cambiado manualmente en el dispositivo: al actualizar la APK vuelve a quedar la URL pública grabada en la compilación. Si necesita otra, cámbiela de nuevo desde el botón de servidor.

---

## 8. Verificación final

1. `npm run health -- https://SU_DOMINIO` → `ok: true` y `version: 2.0.1`.
2. Abra la web `https://SU_DOMINIO` e inicie sesión.
3. Cree un registro de prueba (por ejemplo, una marca o un vehículo).
4. Abra la APK **con datos móviles, sin Wi-Fi de la PC**.
5. Inicie sesión con la URL pública y confirme que ve el mismo registro.
6. Apague la PC. Web y APK deben seguir funcionando.

---

## 9. Seguridad

- **Rote las claves** si el `.env` se compartió o estuvo en una PC ajena:
  - `JWT_SECRET` (invalida sesiones actuales; todos deben volver a entrar).
  - Contraseña de la base en Supabase.
  - `SUPABASE_SERVICE_ROLE_KEY`.
- La `service_role` key **solo** vive en el servidor. Nunca en la APK ni en el navegador.
- No suba a Git:
  - `.env`, `.env.production`
  - `android/keystore.properties`
  - `android/*.keystore`
  - `android/local.properties`
- Guarde una copia segura del keystore y sus contraseñas.
- Cambie la contraseña del administrador inicial (`admin` / `Sigfv2026!`) después del primer ingreso.
- No ejecute `npm run db:setup` sobre una base con datos: **elimina y recrea las tablas**. El script ahora pide confirmación.
- Use siempre HTTPS en producción.
- Programe respaldos/exportaciones de Supabase.

---

## 10. Solución de problemas

| Síntoma | Causa / solución |
|---|---|
| `Falta SUPABASE_DB_URL en el archivo .env` | Falta la variable en el panel del proveedor. |
| `Defina JWT_SECRET (32+ caracteres)` | `JWT_SECRET` vacío o demasiado corto. |
| `connection timeout` a PostgreSQL | Supabase pausado, URL mal copiada o el proveedor bloquea la salida al puerto 6543. Use la cadena del **pooler** de Supabase. |
| `/api/health` devuelve 500 | La base no responde o las credenciales son incorrectas. Revise logs. |
| 502/503 en Render/Fly | La app no está escuchando en `PORT`. Revise logs y el Dockerfile. |
| La web carga pero el login falla | El backend no responde o hay un error de CSP/CORS. Revise la consola del navegador y `/api/health`. |
| La APK no conecta | URL incorrecta, HTTPS inválido, servidor dormido (Render free) o el teléfono sin internet. Use el botón de servidor para corregir la URL. |
| La APK sigue usando la IP vieja | Cambie el servidor desde la app o reinstale/actualice la APK con la URL pública grabada. |
| “No aparecen” los datos en otra PC | Esa PC está usando otro backend u otro proyecto Supabase. Verifique la URL y el `SUPABASE_URL`. |
| Se borraron los datos | Alguien ejecutó `db:setup` o apuntó a otro proyecto Supabase. Restaure el respaldo. |
| Supabase no responde | Proyecto pausado por inactividad (plan gratuito). Reactívelo en el panel. |
| Error al instalar la APK | Firme con el mismo keystore y aumente `versionCode`. |

---

## 11. Costos aproximados

| Servicio | Costo |
|---|---|
| Render free | USD 0, pero duerme por inactividad |
| Render Starter | ~USD 7/mes |
| Railway | Plan/consumo variable |
| Fly.io | Consumo variable; instancia pequeña ~USD 3–5/mes |
| VPS | ~USD 5/mes + dominio (~USD 10/año) |
| Supabase free | USD 0, se pausa por inactividad |
| Supabase Pro | ~USD 25/mes |

Para un sistema de flota en uso diario, lo recomendable es un servicio siempre activo (Render Starter, Fly o VPS) y Supabase activo.

---

## 12. Reversión

- **Render/Railway/Fly:** vuelva a desplegar el commit anterior desde el panel o con `fly deploy` sobre la versión anterior.
- **VPS:** `git checkout COMMIT_ANTERIOR` y `docker compose --env-file .env.production up -d --build`.
- **Supabase:** restaure el respaldo desde el panel. No use `db:setup` para “arreglar” una base con datos.
- **APK:** conserve la APK anterior y el keystore. Recuerde aumentar `versionCode` en cada nueva versión.

---

## 13. Checklist

- [ ] `.env` fuera de Git.
- [ ] Backend desplegado con HTTPS.
- [ ] `/api/health` responde `ok: true`.
- [ ] Web abre e inicia sesión.
- [ ] APK apunta a la URL pública.
- [ ] APK probada con datos móviles.
- [ ] PC apagada y todo sigue funcionando.
- [ ] Keystore y contraseñas respaldados.
- [ ] Claves rotadas si el `.env` se compartió.
- [ ] Respaldo de Supabase configurado.
