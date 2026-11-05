// Uso: npm run crear-admin
// También puede definir ADMIN_USER, ADMIN_EMAIL y ADMIN_PASSWORD como variables de entorno.
const readline = require('readline'), bcrypt = require('bcryptjs'), pool = require('../db');
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = t => new Promise(r => rl.question(t, r));
(async () => {
  const E = process.env;
  const u = (E.ADMIN_USER || await ask('Usuario administrador: ')).trim();
  const c = (E.ADMIN_EMAIL || await ask('Correo: ')).trim();
  const p = E.ADMIN_PASSWORD || await ask('Contraseña (mín. 8 caracteres): ');
  rl.close();
  if (!u || !c || p.length < 8) { console.error('Datos inválidos.'); process.exit(1); }
  try {
    await pool.query('SELECT sp_crear_admin_inicial($1,$2,$3)', [u, c, await bcrypt.hash(p, 12)]);
    console.log('Administrador creado en Supabase.');
  } catch (e) { console.error('Error:', e.message); process.exitCode = 1; }
  await pool.end();
})();
