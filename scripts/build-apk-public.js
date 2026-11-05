/*
 * Compila la APK release con una URL pública HTTPS grabada.
 *
 * Uso:
 *   npm run mobile:apk:public -- https://sigfv.example.com
 *
 * Requisitos en Windows:
 *   - JDK 21
 *   - Android SDK 35
 *   - android/local.properties con sdk.dir correcto
 *   - android/keystore.properties y android/sigfv-release.keystore (firma)
 */
const { spawnSync } = require('child_process');

const url = (process.argv[2] || '').trim().replace(/\/+$/, '');

if (!/^https:\/\/[^/]+/i.test(url)) {
  console.error('Uso: npm run mobile:apk:public -- https://tu-servicio-publico');
  console.error('La URL debe ser HTTPS.');
  process.exit(1);
}

if (/^https:\/\/(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/i.test(url)) {
  console.error('ERROR: use una URL pública, no localhost ni una IP privada/LAN.');
  process.exit(1);
}

process.env.PUBLIC_API_URL = url;
console.log('Compilando APK release con API:', url);

const r = spawnSync('npm', ['run', 'mobile:release'], {
  stdio: 'inherit',
  env: process.env,
  shell: true,
});

if (r.status !== 0) {
  console.error('La compilación de la APK falló.');
  process.exit(r.status === null ? 1 : r.status);
}

console.log('');
console.log('APK generada en: android/app/build/outputs/apk/release/app-release.apk');
console.log('Cópiela a dist/ con un nombre de versión, por ejemplo:');
console.log('  copy android\\app\\build\\outputs\\apk\\release\\app-release.apk dist\\SIGFV-2.0.1.apk');
