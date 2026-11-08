-- ============================================================
-- SIGFV 2.4 · Registro de empresas y solicitud de vehículos
-- Los clientes envían su solicitud desde la web o la APK (sin
-- iniciar sesión). El administrador la revisa, aprueba/rechaza y
-- asigna vehículos y conductores. Todo queda en la base de datos.
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS solicitud_codigo_seq START 1;

CREATE TABLE IF NOT EXISTS solicitudes_empresa (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(24) NOT NULL UNIQUE,
  ruc VARCHAR(20) NOT NULL,
  razon_social VARCHAR(150) NOT NULL,
  contacto VARCHAR(120) NOT NULL,
  cargo VARCHAR(80),
  telefono VARCHAR(30) NOT NULL,
  correo VARCHAR(120) NOT NULL,
  direccion VARCHAR(200),
  actividad VARCHAR(150),
  unidad_solicitada VARCHAR(150),
  requisitos TEXT NOT NULL,
  observaciones TEXT,
  estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aprobada', 'rechazada')),
  empresa_id INTEGER REFERENCES empresas(id),
  unidad_minera_id INTEGER REFERENCES unidades_mineras(id),
  revisado_por VARCHAR(120),
  revisado_en TIMESTAMP,
  respuesta_admin TEXT,
  origen VARCHAR(20) NOT NULL DEFAULT 'web',
  ip VARCHAR(64),
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);

CREATE INDEX IF NOT EXISTS ix_sol_estado ON solicitudes_empresa (estado, creado_en DESC);
CREATE INDEX IF NOT EXISTS ix_sol_ruc ON solicitudes_empresa (ruc);

CREATE TABLE IF NOT EXISTS solicitud_vehiculos (
  id SERIAL PRIMARY KEY,
  solicitud_id INTEGER NOT NULL REFERENCES solicitudes_empresa(id) ON DELETE CASCADE,
  tipo_vehiculo_id INTEGER REFERENCES tipos_vehiculo(id),
  categoria_vehiculo_id INTEGER REFERENCES categorias_vehiculo(id),
  cantidad INTEGER NOT NULL DEFAULT 1 CHECK (cantidad BETWEEN 1 AND 50),
  fecha_inicio DATE,
  fecha_fin DATE,
  requiere_conductor BOOLEAN NOT NULL DEFAULT FALSE,
  detalles TEXT,
  vehiculo_id INTEGER REFERENCES vehiculos(id),
  conductor_id INTEGER REFERENCES conductores(id),
  estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'asignado', 'sin_asignar')),
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio)
);

CREATE INDEX IF NOT EXISTS ix_solv_solicitud ON solicitud_vehiculos (solicitud_id);
CREATE INDEX IF NOT EXISTS ix_solv_vehiculo ON solicitud_vehiculos (vehiculo_id);

COMMENT ON TABLE solicitudes_empresa IS
  'Solicitudes de registro de empresas clientes y pedido de vehículos.';
COMMENT ON TABLE solicitud_vehiculos IS
  'Detalle de vehículos solicitados y asignados por el administrador.';
