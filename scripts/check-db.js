/*
 * Diagnóstico rápido de la base de datos: conteos y estado de la migración 2.2.
 * Uso: npm run db:check
 */
require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.SUPABASE_DB_URL,
  ssl: { rejectUnauthorized: false },
  max: 1
});

(async () => {
  const r = await pool.query(`
    SELECT
      (SELECT COUNT(*) FROM empresas)::int empresas,
      (SELECT COUNT(*) FROM roles)::int roles,
      (SELECT COUNT(*) FROM usuarios)::int usuarios,
      (SELECT COUNT(*) FROM vehiculos)::int vehiculos,
      (SELECT COUNT(*) FROM unidades_mineras)::int unidades,
      (SELECT COUNT(*) FROM roles WHERE password_hash IS NOT NULL)::int roles_con_clave,
      (SELECT COUNT(*) FROM usuarios WHERE es_representante)::int representantes,
      (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'sync_ops')::int sync_ops
  `);
  console.log(r.rows[0]);
  const roles = await pool.query(
    'SELECT id, nombre, empresa_id, password_hash IS NOT NULL AS clave FROM roles ORDER BY id');
  console.table(roles.rows);
  await pool.end();
})().catch(e => { console.error(e.message); process.exit(1); });
