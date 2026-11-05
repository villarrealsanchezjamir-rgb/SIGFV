require('dotenv').config();
const { Pool, types } = require('pg');

/*
 * Conexión al PostgreSQL de Supabase.
 * SUPABASE_DB_URL es la cadena de conexión del pooler (Project Settings -> Database).
 * El backend usa el rol postgres (propietario) y por eso omite RLS; la API
 * aplica autenticación JWT y permisos por módulo/acción.
 */

// Devolver fechas y horas como texto (mismo comportamiento que el frontend espera).
types.setTypeParser(1082, v => v); // date
types.setTypeParser(1083, v => v); // time
types.setTypeParser(1114, v => v); // timestamp
types.setTypeParser(1184, v => v); // timestamptz

if (!process.env.SUPABASE_DB_URL) {
  console.error('Falta SUPABASE_DB_URL en el archivo .env');
  process.exit(1);
}

const pool = new Pool({
  connectionString: process.env.SUPABASE_DB_URL,
  ssl: { rejectUnauthorized: false },
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 15000,
  keepAlive: true,
});

pool.on('error', e => console.error('Error del pool PostgreSQL:', e.message));
// Las fechas/horas se calculan con sigfv_now()/sigfv_today() (zona America/Lima)
// definidas en la base de datos, por lo que no depende de la zona del servidor.

module.exports = pool;
