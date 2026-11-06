/*
 * Aplica una migración SQL a la base de datos configurada en .env.
 * Uso: npm run db:migrate -- database/02_clientes_roles_offline.sql
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const file = process.argv[2] || 'database/02_clientes_roles_offline.sql';
const full = path.isAbsolute(file) ? file : path.join(__dirname, '..', file);

if (!process.env.SUPABASE_DB_URL) {
  console.error('ERROR: falta SUPABASE_DB_URL en .env');
  process.exit(1);
}
if (!fs.existsSync(full)) {
  console.error('ERROR: no existe el archivo', full);
  process.exit(1);
}

const sql = fs.readFileSync(full, 'utf8');
const pool = new Pool({
  connectionString: process.env.SUPABASE_DB_URL,
  ssl: { rejectUnauthorized: false },
  max: 1
});

(async () => {
  console.log('Aplicando', path.relative(path.join(__dirname, '..'), full), '…');
  const client = await pool.connect();
  try {
    await client.query(sql);
    console.log('Migración aplicada correctamente.');
  } finally {
    client.release();
    await pool.end();
  }
})().catch(e => {
  console.error('ERROR al aplicar la migración:', e.message);
  process.exit(1);
});
