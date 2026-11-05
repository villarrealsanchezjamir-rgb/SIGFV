/*
 * Copia la interfaz web a mobile/www y genera config.js con las
 * variables propias de la app Android.
 *
 * IMPORTANTE: PUBLIC_API_URL se toma del entorno, NO de .env, para evitar
 * grabar por accidente una IP local (192.168.x.x) en una APK de producción.
 *
 * Uso recomendado:
 *   npm run mobile:apk:public -- https://tu-servicio
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const src = path.join(root, 'public');
const dest = path.join(root, 'mobile', 'www');

const api = (process.env.PUBLIC_API_URL || '').replace(/\/+$/, '');

if (!api) {
  console.warn('ADVERTENCIA: PUBLIC_API_URL no está definida.');
  console.warn('La APK pedirá la URL del servidor en la pantalla de inicio de sesión.');
} else if (!/^https?:\/\//i.test(api)) {
  console.error('ERROR: PUBLIC_API_URL debe empezar con http:// o https://');
  process.exit(1);
} else if (/^http:\/\/(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/i.test(api)) {
  console.warn('ADVERTENCIA: PUBLIC_API_URL es una dirección privada/LAN.');
  console.warn('La APK solo funcionará en esa red. Para uso desde cualquier red use HTTPS público.');
}

fs.rmSync(dest, { recursive: true, force: true });
fs.mkdirSync(dest, { recursive: true });

for (const f of fs.readdirSync(src)) {
  const from = path.join(src, f), to = path.join(dest, f);
  const st = fs.statSync(from);
  if (st.isDirectory()) fs.cpSync(from, to, { recursive: true });
  else fs.copyFileSync(from, to);
}

fs.writeFileSync(path.join(dest, 'config.js'),
  `// Generado por scripts/build-mobile.js\nwindow.SIGFV_MOBILE = true;\nwindow.SIGFV_API_BASE = ${JSON.stringify(api)};\n`);

const idx = path.join(dest, 'index.html');
let html = fs.readFileSync(idx, 'utf8');
html = html.replace('<script>\nconst $=', '<script src="config.js"></script>\n<script>\nconst $=');
if (!html.includes('config.js')) html = html.replace('</body>', '<script src="config.js"></script></body>');
fs.writeFileSync(idx, html);

console.log('Interfaz copiada a mobile/www');
console.log('API por defecto:', api || '(se pedirá en la pantalla de inicio de sesión)');
