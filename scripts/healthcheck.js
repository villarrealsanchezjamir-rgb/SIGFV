/*
 * Comprueba que un backend SIGFV esté en línea.
 *
 * Uso:
 *   npm run health -- https://sigfv.example.com
 *   SIGFV_URL=https://sigfv.example.com npm run health
 */
require('dotenv').config();

const base = (process.argv[2] || process.env.SIGFV_URL || process.env.PUBLIC_API_URL || '')
  .trim()
  .replace(/\/+$/, '');

if (!base) {
  console.error('Uso: npm run health -- https://tu-servicio');
  process.exit(1);
}

(async () => {
  try {
    const r = await fetch(base + '/api/health', { signal: AbortSignal.timeout(15000) });
    const text = await r.text();
    let data;
    try { data = JSON.parse(text); } catch { data = text; }

    console.log('URL:', base);
    console.log('HTTP:', r.status);
    console.log(typeof data === 'string' ? data : JSON.stringify(data, null, 2));

    if (!r.ok || !data || data.ok !== true) process.exit(1);
  } catch (e) {
    console.error('No se pudo contactar el backend:', e.message);
    process.exit(1);
  }
})();
