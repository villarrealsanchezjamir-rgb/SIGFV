/*
 * Copia la interfaz móvil exclusiva (mobile/app) a mobile/www y genera
 * config.js con la URL del backend grabada en el código de la APK.
 *
 * La app NO muestra ni pide la URL: el usuario solo inicia sesión.
 * Por defecto se usa el backend de producción. Para probar contra otro
 * servidor, defina PUBLIC_API_URL en el entorno:
 *
 *   set PUBLIC_API_URL=https://mi-servidor && npm run mobile:build
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const src = path.join(root, 'mobile', 'app');
const dest = path.join(root, 'mobile', 'www');
const { version } = require('../package.json');

const DEFAULT_API = 'https://sigfv.onrender.com';
const api = String(process.env.PUBLIC_API_URL || DEFAULT_API).trim().replace(/\/+$/, '');

if (!/^https?:\/\//i.test(api)) {
  console.error('ERROR: PUBLIC_API_URL debe empezar con http:// o https://');
  process.exit(1);
}
if (/^http:\/\/(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/i.test(api)) {
  console.warn('ADVERTENCIA: PUBLIC_API_URL es una dirección privada/LAN.');
  console.warn('La APK solo funcionará en esa red. Para uso desde cualquier red use HTTPS público.');
}
if (!fs.existsSync(path.join(src, 'index.html'))) {
  console.error('ERROR: no se encontró mobile/app/index.html');
  process.exit(1);
}

fs.rmSync(dest, { recursive: true, force: true });
fs.mkdirSync(dest, { recursive: true });

for (const f of fs.readdirSync(src)) {
  if (f === 'config.js') continue;
  const from = path.join(src, f), to = path.join(dest, f);
  const st = fs.statSync(from);
  if (st.isDirectory()) fs.cpSync(from, to, { recursive: true });
  else fs.copyFileSync(from, to);
}

fs.writeFileSync(path.join(dest, 'config.js'),
  `// Generado por scripts/build-mobile.js\n` +
  `window.SIGFV_MOBILE = true;\n` +
  `window.SIGFV_API_BASE = ${JSON.stringify(api)};\n` +
  `window.SIGFV_APP_VERSION = ${JSON.stringify(version)};\n`);

console.log('Interfaz móvil copiada a mobile/www');
console.log('API grabada en la APK:', api);
console.log('Versión de la app:', version);
