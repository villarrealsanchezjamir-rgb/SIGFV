/*
 * Compila la APK release con la URL del backend grabada en el código.
 *
 * Por defecto usa https://sigfv.onrender.com (no se muestra en la app).
 * Para generar una APK contra otro servidor:
 *   npm run mobile:apk:public -- https://otro-servidor
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

const DEFAULT_API = 'https://sigfv.onrender.com';
const url = String(process.argv[2] || DEFAULT_API).trim().replace(/\/+$/, '');

if (!/^https:\/\/[^/]+/i.test(url)) {
  console.error('La URL del backend debe ser HTTPS.');
  console.error('Uso: npm run mobile:apk:public -- https://tu-servicio-publico');
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

const apk = path.join(__dirname, '..', 'android', 'app', 'build', 'outputs', 'apk', 'release', 'app-release.apk');
const { version } = require('../package.json');
const dist = path.join(__dirname, '..', 'dist');
const finalApk = path.join(dist, `SIGFV-${version}.apk`);

if (!fs.existsSync(apk)) {
  console.error('No se encontró la APK en:', apk);
  process.exit(1);
}

fs.mkdirSync(dist, { recursive: true });
fs.copyFileSync(apk, finalApk);

console.log('');
console.log('APK generada:', apk);
console.log('APK lista para instalar:', finalApk);
