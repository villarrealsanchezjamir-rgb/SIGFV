/*
 * Aplica database/01_SIGFV_Supabase.sql al PostgreSQL de Supabase.
 * Uso: npm run db:setup
 *
 * ATENCIÓN: este script elimina y vuelve a crear las tablas de SIGFV.
 * Úselo solo en la instalación inicial o para reiniciar la base.
 *
 * Para evitar borrados accidentales exige confirmación:
 *   - Interactiva: escriba SI cuando lo pida.
 *   - No interactiva: defina SIGFV_CONFIRM_DB_SETUP=SI
 *     (PowerShell: $env:SIGFV_CONFIRM_DB_SETUP="SI"; npm run db:setup)
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { Client } = require('pg');

(async () => {
  if (!process.env.SUPABASE_DB_URL) {
    console.error('Falta SUPABASE_DB_URL en .env');
    process.exit(1);
  }

  const confirm = (process.env.SIGFV_CONFIRM_DB_SETUP || '').toUpperCase();
  if (confirm !== 'SI') {
    if (!process.stdin.isTTY) {
      console.error('ATENCIÓN: db:setup elimina y recrea las tablas SIGFV.');
      console.error('Para continuar sin confirmación interactiva ejecute:');
      console.error('  SIGFV_CONFIRM_DB_SETUP=SI npm run db:setup');
      console.error('En PowerShell: $env:SIGFV_CONFIRM_DB_SETUP="SI"; npm run db:setup');
      process.exit(1);
    }
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const answer = await new Promise(r => rl.question('Esto BORRARÁ las tablas SIGFV. Escriba SI para continuar: ', r));
    rl.close();
    if (answer.trim().toUpperCase() !== 'SI') {
      console.log('Cancelado.');
      process.exit(1);
    }
  }

  const file = path.join(__dirname, '..', 'database', '01_SIGFV_Supabase.sql');
  const sql = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
  const client = new Client({
    connectionString: process.env.SUPABASE_DB_URL,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 20000,
    statement_timeout: 180000,
  });
  await client.connect();
  try {
    console.log('Aplicando esquema SIGFV en Supabase...');
    const result = await client.query(sql);
    const last = Array.isArray(result) ? result[result.length - 1] : result;
    console.log(last.rows ? last.rows[0] : 'Esquema aplicado.');
  } finally {
    await client.end();
  }
})().catch(e => { console.error('Error:', e.message); process.exit(1); });
