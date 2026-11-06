-- =====================================================================
-- SIGFV 2.2 · Acceso por empresa + rol, empresas clientes y offline
-- Migración ADITIVA e idempotente: no borra ni modifica datos existentes.
-- Aplicar después de 01_SIGFV_Supabase.sql.
-- =====================================================================

BEGIN;

-- ---------- Empresas clientes ----------
ALTER TABLE empresas ADD COLUMN IF NOT EXISTS contacto VARCHAR(120);
ALTER TABLE empresas ADD COLUMN IF NOT EXISTS notas TEXT;

COMMENT ON COLUMN empresas.notas IS
  'Alcance del servicio y requerimientos solicitados por la empresa (una línea por requerimiento).';

-- ---------- Roles con acceso propio ----------
ALTER TABLE roles ADD COLUMN IF NOT EXISTS empresa_id INTEGER REFERENCES empresas(id);
ALTER TABLE roles ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
ALTER TABLE roles ADD COLUMN IF NOT EXISTS intentos_fallidos SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE roles ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMP;
ALTER TABLE roles ADD COLUMN IF NOT EXISTS ultimo_acceso TIMESTAMP;
ALTER TABLE roles ADD COLUMN IF NOT EXISTS icono VARCHAR(40);
ALTER TABLE roles ADD COLUMN IF NOT EXISTS color VARCHAR(20);
ALTER TABLE roles ADD COLUMN IF NOT EXISTS es_sistema BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS ix_roles_empresa ON roles (empresa_id);

-- El nombre del rol pasa a ser único por empresa (no global).
ALTER TABLE roles DROP CONSTRAINT IF EXISTS roles_nombre_key;
CREATE UNIQUE INDEX IF NOT EXISTS ux_roles_nombre_empresa
  ON roles (nombre, COALESCE(empresa_id, 0));

-- ---------- Usuarios representantes de un rol ----------
-- Cada rol que inicia sesión necesita un usuario técnico para las claves
-- foráneas de auditoría e historial. No aparece en el módulo Usuarios.
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS es_representante BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS ix_usuarios_representante ON usuarios (es_representante);

-- ---------- Registro de accesos ----------
ALTER TABLE registros_acceso ADD COLUMN IF NOT EXISTS rol_id INTEGER REFERENCES roles(id);
ALTER TABLE registros_acceso ADD COLUMN IF NOT EXISTS empresa_id INTEGER REFERENCES empresas(id);
ALTER TABLE registros_acceso ADD COLUMN IF NOT EXISTS operador VARCHAR(120);
CREATE INDEX IF NOT EXISTS ix_acc_rol ON registros_acceso (rol_id, fecha DESC);

-- ---------- Cola idempotente de sincronización offline ----------
CREATE TABLE IF NOT EXISTS sync_ops (
  op_id VARCHAR(100) PRIMARY KEY,
  role_id INTEGER REFERENCES roles(id),
  empresa_id INTEGER REFERENCES empresas(id),
  usuario_id INTEGER REFERENCES usuarios(id),
  method VARCHAR(10) NOT NULL,
  resource VARCHAR(40) NOT NULL,
  record_id INTEGER,
  body JSONB,
  ok BOOLEAN NOT NULL DEFAULT FALSE,
  error TEXT,
  aplicado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX IF NOT EXISTS ix_sync_ops_role ON sync_ops (role_id, aplicado_en DESC);

-- ---------- Contraseña inicial del rol Administrador ----------
-- Contraseña temporal: SIGFV.Admin.2026
-- Se conserva la contraseña existente si la migración se ejecuta de nuevo.
DO $$
DECLARE
  v_rid INTEGER;
  v_hash VARCHAR(255);
  v_uid INTEGER;
  v_admin_hash CONSTANT VARCHAR(255) :=
    'pbkdf2-sha256$120000$DA9E8HiQjvXAA60ZwFXVnQ==$V/Jfwo/6mb2EGJpnCuNVU7/FsnpjiYKdEewZ1ETp9Uc=';
BEGIN
  SELECT id INTO v_rid FROM roles WHERE nombre = 'Administrador' ORDER BY id LIMIT 1;
  IF v_rid IS NULL THEN
    RETURN;
  END IF;

  UPDATE roles
     SET password_hash = COALESCE(password_hash, v_admin_hash),
         es_sistema = TRUE,
         activo = TRUE,
         icono = COALESCE(icono, 'shield'),
         color = COALESCE(color, '#171717')
   WHERE id = v_rid;

  SELECT password_hash INTO v_hash FROM roles WHERE id = v_rid;

  IF NOT EXISTS (SELECT 1 FROM usuario_roles WHERE rol_id = v_rid) THEN
    INSERT INTO usuarios (nombre_usuario, correo, nombres, apellidos, password_hash, es_representante)
    VALUES ('rol_' || v_rid, 'rol_' || v_rid || '@sigfv.local', 'Acceso', 'Administrador', v_hash, TRUE)
    ON CONFLICT DO NOTHING;

    SELECT id INTO v_uid FROM usuarios WHERE nombre_usuario = 'rol_' || v_rid;
    IF v_uid IS NOT NULL THEN
      INSERT INTO usuario_roles (usuario_id, rol_id) VALUES (v_uid, v_rid)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
END $$;

-- Iconos y colores para los roles existentes (solo si están vacíos).
UPDATE roles SET icono = COALESCE(icono, CASE nombre
    WHEN 'Administrador' THEN 'shield'
    WHEN 'Supervisor de flota' THEN 'truck'
    WHEN 'Responsable de mantenimiento' THEN 'wrench'
    WHEN 'Conductor' THEN 'id-card'
    WHEN 'Personal de seguridad' THEN 'clipboard'
    ELSE 'key' END),
  color = COALESCE(color, CASE nombre
    WHEN 'Administrador' THEN '#171717'
    WHEN 'Supervisor de flota' THEN '#447BA8'
    WHEN 'Responsable de mantenimiento' THEN '#A98624'
    WHEN 'Conductor' THEN '#26865B'
    WHEN 'Personal de seguridad' THEN '#C64747'
    ELSE '#42464B' END);

COMMIT;
