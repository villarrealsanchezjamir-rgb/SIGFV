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
const fs = require('fs');
const path = require('path');

// Android Gradle Plugin 8.x requiere JDK 17/21. Si JAVA_HOME apunta a un JDK
// más nuevo (por ejemplo el JBR 25 de Android Studio), buscar un JDK 21 local.
function ensureJava21() {
  const current = process.env.JAVA_HOME || '';
  if (/jdk-?21/i.test(current)) return;

  const roots = [
    'C:\\Program Files\\Eclipse Adoptium',
    'C:\\Program Files\\Java',
    'C:\\Program Files\\Microsoft',
  ];

  for (const root of roots) {
    if (!fs.existsSync(root)) continue;
    let dirs = [];
    try { dirs = fs.readdirSync(root); } catch { continue; }
    for (const d of dirs) {
      if (!/^jdk-?21/i.test(d)) continue;
      const candidate = path.join(root, d);
      if (fs.existsSync(path.join(candidate, 'bin', 'java.exe'))) {
        process.env.JAVA_HOME = candidate;
        console.log('JAVA_HOME ajustado a JDK 21:', candidate);
        return;
      }
    }
  }

  if (current) console.warn('ADVERTENCIA: JAVA_HOME no parece ser JDK 21:', current);
  else console.warn('ADVERTENCIA: JAVA_HOME no está definido. Si Gradle falla, configure JDK 21.');
}

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

ensureJava21();

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
