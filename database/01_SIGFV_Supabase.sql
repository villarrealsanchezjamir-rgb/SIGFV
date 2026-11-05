-- =====================================================================
-- SIGFV · Sistema Integral de Gestión de Flota Vehicular
-- Esquema PostgreSQL para Supabase
--
-- Cómo ejecutarlo:
--   1) Supabase Dashboard -> SQL Editor -> New query
--   2) Pegue TODO este archivo y pulse "Run"
--
-- ADVERTENCIA: al inicio se eliminan las tablas de SIGFV. Úselo para la
-- instalación inicial o para reiniciar la base. No afecta a otras tablas
-- que no pertenezcan a SIGFV.
-- =====================================================================
SET client_min_messages = warning;

-- ===== Limpieza de objetos SIGFV =====
DROP TABLE IF EXISTS asistente_uso_tokens, asistente_consultas_log, configuraciones, auditoria,
  notificaciones, evidencias_incidente, acciones_correctivas, incidentes, abastecimientos,
  evidencias_inspeccion, inspeccion_detalles, inspecciones, archivos_adjuntos, documentos,
  mantenimiento_repuestos, repuestos, mantenimientos, devoluciones, asignaciones,
  contratos_alquiler, historial_estados_vehiculo, vehiculos, refresh_tokens, registros_acceso,
  usuario_unidades, usuario_roles, usuarios, rol_permisos, permisos, roles, licencias,
  conductores, niveles_gravedad, tipos_incidente, componentes_inspeccion, tipos_documento,
  tipos_mantenimiento, proveedores_combustible, talleres, proveedores, categorias_licencia,
  propietarios, estados_vehiculo, categorias_vehiculo, tipos_vehiculo, modelos, marcas,
  proyectos, areas, unidades_mineras, empresas CASCADE;

DROP FUNCTION IF EXISTS sp_crear_admin_inicial(text, text, text) CASCADE;
DROP FUNCTION IF EXISTS fn_validar_asignacion() CASCADE;
DROP FUNCTION IF EXISTS fn_set_actualizado() CASCADE;

DROP TYPE IF EXISTS resultado_asistente CASCADE;
DROP TYPE IF EXISTS estado_accion CASCADE;
DROP TYPE IF EXISTS estado_investigacion CASCADE;
DROP TYPE IF EXISTS resultado_componente CASCADE;
DROP TYPE IF EXISTS resultado_inspeccion CASCADE;
DROP TYPE IF EXISTS estado_mantenimiento CASCADE;
DROP TYPE IF EXISTS estado_asignacion CASCADE;
DROP TYPE IF EXISTS tipo_asignacion CASCADE;
DROP TYPE IF EXISTS estado_alquiler CASCADE;
DROP TYPE IF EXISTS accion_permiso CASCADE;
DROP TYPE IF EXISTS aplica_a CASCADE;
DROP TYPE IF EXISTS estado_conductor CASCADE;
DROP TYPE IF EXISTS tipo_combustible CASCADE;

-- ===== Utilidades de fecha/hora (zona horaria de Perú) =====
CREATE OR REPLACE FUNCTION sigfv_now() RETURNS timestamp
  LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'America/Lima') $$;

CREATE OR REPLACE FUNCTION sigfv_today() RETURNS date
  LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'America/Lima')::date $$;

-- ===== Tipos enumerados =====
CREATE TYPE tipo_combustible AS ENUM ('diesel','gasolina','glp','gnv','electrico','otro');
CREATE TYPE estado_conductor AS ENUM ('activo','inactivo','inhabilitado');
CREATE TYPE aplica_a AS ENUM ('vehiculo','conductor','ambos');
CREATE TYPE accion_permiso AS ENUM ('consultar','crear','editar','eliminar','aprobar','exportar','configurar');
CREATE TYPE estado_alquiler AS ENUM ('vigente','vencido','rescindido');
CREATE TYPE tipo_asignacion AS ENUM ('operativa','alquiler','temporal','permanente');
CREATE TYPE estado_asignacion AS ENUM ('programada','activa','finalizada','cancelada');
CREATE TYPE estado_mantenimiento AS ENUM ('programado','en_proceso','completado','cancelado');
CREATE TYPE resultado_inspeccion AS ENUM ('conforme','conforme_con_observaciones','no_conforme');
CREATE TYPE resultado_componente AS ENUM ('conforme','observado','no_conforme');
CREATE TYPE estado_investigacion AS ENUM ('pendiente','en_investigacion','cerrado');
CREATE TYPE estado_accion AS ENUM ('pendiente','en_curso','cumplida');
CREATE TYPE resultado_asistente AS ENUM ('exito','error','denegado');

-- ===== ORGANIZACIÓN =====
CREATE TABLE empresas (
  id SERIAL PRIMARY KEY,
  ruc VARCHAR(20) NOT NULL UNIQUE,
  razon_social VARCHAR(150) NOT NULL,
  direccion VARCHAR(200),
  telefono VARCHAR(30),
  correo VARCHAR(120),
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);

CREATE TABLE unidades_mineras (
  id SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL REFERENCES empresas(id),
  codigo VARCHAR(20) NOT NULL UNIQUE,
  nombre VARCHAR(120) NOT NULL,
  ubicacion VARCHAR(200),
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);

CREATE TABLE areas (
  id SERIAL PRIMARY KEY,
  unidad_minera_id INTEGER NOT NULL REFERENCES unidades_mineras(id),
  nombre VARCHAR(100) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (unidad_minera_id, nombre)
);

CREATE TABLE proyectos (
  id SERIAL PRIMARY KEY,
  unidad_minera_id INTEGER NOT NULL REFERENCES unidades_mineras(id),
  codigo VARCHAR(30) NOT NULL UNIQUE,
  nombre VARCHAR(150) NOT NULL,
  fecha_inicio DATE,
  fecha_fin DATE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- ===== CATÁLOGOS =====
CREATE TABLE marcas (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE modelos (
  id SERIAL PRIMARY KEY,
  marca_id INTEGER NOT NULL REFERENCES marcas(id),
  nombre VARCHAR(80) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (marca_id, nombre)
);

CREATE TABLE tipos_vehiculo (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE categorias_vehiculo (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE estados_vehiculo (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL UNIQUE,
  permite_asignacion BOOLEAN NOT NULL DEFAULT FALSE,
  color VARCHAR(7)
);

CREATE TABLE propietarios (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  documento VARCHAR(20) UNIQUE,
  es_empresa BOOLEAN NOT NULL DEFAULT TRUE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE categorias_licencia (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(10) NOT NULL UNIQUE,
  descripcion VARCHAR(120)
);

CREATE TABLE proveedores (
  id SERIAL PRIMARY KEY,
  ruc VARCHAR(20) UNIQUE,
  nombre VARCHAR(150) NOT NULL,
  telefono VARCHAR(30),
  correo VARCHAR(120),
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE talleres (
  id SERIAL PRIMARY KEY,
  proveedor_id INTEGER REFERENCES proveedores(id),
  nombre VARCHAR(150) NOT NULL,
  direccion VARCHAR(200),
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE proveedores_combustible (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  ruc VARCHAR(20) UNIQUE,
  ubicacion VARCHAR(200),
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE tipos_mantenimiento (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE tipos_documento (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL UNIQUE,
  aplica_a aplica_a NOT NULL,
  dias_alerta SMALLINT NOT NULL DEFAULT 30,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE componentes_inspeccion (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL UNIQUE,
  es_critico BOOLEAN NOT NULL DEFAULT FALSE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE tipos_incidente (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE niveles_gravedad (
  id SMALLINT PRIMARY KEY,
  nombre VARCHAR(40) NOT NULL UNIQUE
);

-- ===== CONDUCTORES =====
CREATE TABLE conductores (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(20) NOT NULL UNIQUE,
  nombres VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  documento_identidad VARCHAR(20) NOT NULL UNIQUE,
  telefono VARCHAR(30),
  correo VARCHAR(120),
  direccion VARCHAR(200),
  unidad_minera_id INTEGER REFERENCES unidades_mineras(id),
  estado estado_conductor NOT NULL DEFAULT 'activo',
  fecha_incorporacion DATE,
  observaciones TEXT,
  eliminado_en TIMESTAMP,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_cond_estado ON conductores (estado);

CREATE TABLE licencias (
  id SERIAL PRIMARY KEY,
  conductor_id INTEGER NOT NULL REFERENCES conductores(id),
  categoria_id INTEGER NOT NULL REFERENCES categorias_licencia(id),
  numero VARCHAR(30) NOT NULL UNIQUE,
  fecha_emision DATE NOT NULL,
  fecha_vencimiento DATE NOT NULL,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  CHECK (fecha_vencimiento > fecha_emision)
);
CREATE INDEX ix_lic_venc ON licencias (fecha_vencimiento);

-- ===== SEGURIDAD =====
CREATE TABLE roles (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL UNIQUE,
  descripcion VARCHAR(200),
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE permisos (
  id SERIAL PRIMARY KEY,
  modulo VARCHAR(40) NOT NULL,
  accion accion_permiso NOT NULL,
  UNIQUE (modulo, accion)
);

CREATE TABLE rol_permisos (
  rol_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permiso_id INTEGER NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
  PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE usuarios (
  id SERIAL PRIMARY KEY,
  nombre_usuario VARCHAR(50) NOT NULL UNIQUE,
  correo VARCHAR(120) NOT NULL UNIQUE,
  nombres VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  conductor_id INTEGER REFERENCES conductores(id),
  intentos_fallidos SMALLINT NOT NULL DEFAULT 0,
  bloqueado_hasta TIMESTAMP,
  ultimo_acceso TIMESTAMP,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  eliminado_en TIMESTAMP,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);

CREATE TABLE usuario_roles (
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  rol_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, rol_id)
);

CREATE TABLE usuario_unidades (
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  unidad_minera_id INTEGER NOT NULL REFERENCES unidades_mineras(id) ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, unidad_minera_id)
);

CREATE TABLE registros_acceso (
  id BIGSERIAL PRIMARY KEY,
  usuario_id INTEGER REFERENCES usuarios(id),
  nombre_usuario VARCHAR(50),
  ip VARCHAR(45),
  exitoso BOOLEAN NOT NULL,
  fecha TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_acc_fecha ON registros_acceso (fecha);

CREATE TABLE refresh_tokens (
  id BIGSERIAL PRIMARY KEY,
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expira_en TIMESTAMP NOT NULL,
  revocado BOOLEAN NOT NULL DEFAULT FALSE
);

-- ===== VEHÍCULOS =====
CREATE TABLE vehiculos (
  id SERIAL PRIMARY KEY,
  codigo_interno VARCHAR(20) NOT NULL UNIQUE,
  placa VARCHAR(15) UNIQUE,
  modelo_id INTEGER NOT NULL REFERENCES modelos(id),
  tipo_id INTEGER NOT NULL REFERENCES tipos_vehiculo(id),
  categoria_id INTEGER REFERENCES categorias_vehiculo(id),
  anio_fabricacion SMALLINT,
  numero_serie VARCHAR(40),
  vin VARCHAR(25) UNIQUE,
  numero_motor VARCHAR(40),
  kilometraje NUMERIC(10,1) NOT NULL DEFAULT 0 CHECK (kilometraje >= 0),
  capacidad VARCHAR(60),
  tipo_combustible tipo_combustible NOT NULL DEFAULT 'diesel',
  fecha_adquisicion DATE,
  propietario_id INTEGER NOT NULL REFERENCES propietarios(id),
  proveedor_id INTEGER REFERENCES proveedores(id),
  estado_id INTEGER NOT NULL REFERENCES estados_vehiculo(id),
  unidad_minera_id INTEGER NOT NULL REFERENCES unidades_mineras(id),
  observaciones TEXT,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  eliminado_en TIMESTAMP,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_veh_estado ON vehiculos (estado_id);
CREATE INDEX ix_veh_unidad ON vehiculos (unidad_minera_id);

CREATE TABLE historial_estados_vehiculo (
  id BIGSERIAL PRIMARY KEY,
  vehiculo_id INTEGER NOT NULL REFERENCES vehiculos(id),
  estado_anterior_id INTEGER REFERENCES estados_vehiculo(id),
  estado_nuevo_id INTEGER NOT NULL REFERENCES estados_vehiculo(id),
  motivo VARCHAR(250),
  usuario_id INTEGER REFERENCES usuarios(id),
  fecha TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_hev_veh ON historial_estados_vehiculo (vehiculo_id, fecha);

-- ===== OPERACIONES =====
CREATE TABLE contratos_alquiler (
  id SERIAL PRIMARY KEY,
  numero VARCHAR(30) NOT NULL UNIQUE,
  proveedor_id INTEGER NOT NULL REFERENCES proveedores(id),
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NOT NULL,
  tarifa NUMERIC(12,2),
  condiciones TEXT,
  estado estado_alquiler NOT NULL DEFAULT 'vigente',
  CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE asignaciones (
  id SERIAL PRIMARY KEY,
  vehiculo_id INTEGER NOT NULL REFERENCES vehiculos(id),
  conductor_id INTEGER REFERENCES conductores(id),
  responsable_id INTEGER NOT NULL REFERENCES usuarios(id),
  contrato_id INTEGER REFERENCES contratos_alquiler(id),
  area_id INTEGER REFERENCES areas(id),
  unidad_minera_id INTEGER NOT NULL REFERENCES unidades_mineras(id),
  proyecto_id INTEGER REFERENCES proyectos(id),
  tipo tipo_asignacion NOT NULL DEFAULT 'operativa',
  fecha_inicio TIMESTAMP NOT NULL,
  fecha_fin TIMESTAMP,
  estado estado_asignacion NOT NULL DEFAULT 'programada',
  observaciones TEXT,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio)
);
CREATE INDEX ix_asig_veh ON asignaciones (vehiculo_id, estado);
CREATE INDEX ix_asig_cond ON asignaciones (conductor_id, estado);

CREATE TABLE devoluciones (
  id SERIAL PRIMARY KEY,
  asignacion_id INTEGER NOT NULL UNIQUE REFERENCES asignaciones(id),
  fecha TIMESTAMP NOT NULL,
  kilometraje NUMERIC(10,1),
  condicion VARCHAR(250),
  recibido_por INTEGER NOT NULL REFERENCES usuarios(id)
);

-- ===== MANTENIMIENTO =====
CREATE TABLE mantenimientos (
  id SERIAL PRIMARY KEY,
  vehiculo_id INTEGER NOT NULL REFERENCES vehiculos(id),
  tipo_id INTEGER NOT NULL REFERENCES tipos_mantenimiento(id),
  fecha DATE NOT NULL,
  kilometraje NUMERIC(10,1),
  descripcion TEXT,
  diagnostico TEXT,
  trabajo_realizado TEXT,
  responsable_id INTEGER REFERENCES usuarios(id),
  taller_id INTEGER REFERENCES talleres(id),
  costo NUMERIC(12,2) NOT NULL DEFAULT 0,
  proximo_fecha DATE,
  proximo_km NUMERIC(10,1),
  estado estado_mantenimiento NOT NULL DEFAULT 'programado',
  eliminado_en TIMESTAMP,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_mant_veh ON mantenimientos (vehiculo_id, fecha);
CREATE INDEX ix_mant_estado ON mantenimientos (estado, fecha);

CREATE TABLE repuestos (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(30) NOT NULL UNIQUE,
  nombre VARCHAR(150) NOT NULL,
  costo_referencial NUMERIC(12,2),
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE mantenimiento_repuestos (
  mantenimiento_id INTEGER NOT NULL REFERENCES mantenimientos(id) ON DELETE CASCADE,
  repuesto_id INTEGER NOT NULL REFERENCES repuestos(id),
  cantidad NUMERIC(10,2) NOT NULL CHECK (cantidad > 0),
  costo_unitario NUMERIC(12,2) NOT NULL,
  PRIMARY KEY (mantenimiento_id, repuesto_id)
);

-- ===== DOCUMENTACIÓN =====
CREATE TABLE documentos (
  id SERIAL PRIMARY KEY,
  tipo_id INTEGER NOT NULL REFERENCES tipos_documento(id),
  vehiculo_id INTEGER REFERENCES vehiculos(id),
  conductor_id INTEGER REFERENCES conductores(id),
  numero VARCHAR(50),
  fecha_emision DATE,
  fecha_vencimiento DATE,
  dias_alerta SMALLINT,
  observaciones VARCHAR(250),
  eliminado_en TIMESTAMP,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  CHECK ((vehiculo_id IS NOT NULL) <> (conductor_id IS NOT NULL))
);
CREATE INDEX ix_doc_venc ON documentos (fecha_vencimiento);

CREATE TABLE archivos_adjuntos (
  id BIGSERIAL PRIMARY KEY,
  documento_id INTEGER NOT NULL REFERENCES documentos(id) ON DELETE CASCADE,
  nombre_original VARCHAR(200) NOT NULL,
  ruta_almacenada VARCHAR(300) NOT NULL,
  mime VARCHAR(80) NOT NULL,
  tamano_bytes INTEGER NOT NULL,
  sha256 CHAR(64) NOT NULL,
  subido_por INTEGER REFERENCES usuarios(id),
  subido_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);

-- ===== INSPECCIONES =====
CREATE TABLE inspecciones (
  id SERIAL PRIMARY KEY,
  vehiculo_id INTEGER NOT NULL REFERENCES vehiculos(id),
  conductor_id INTEGER NOT NULL REFERENCES conductores(id),
  fecha_hora TIMESTAMP NOT NULL,
  resultado resultado_inspeccion NOT NULL,
  bloquea_vehiculo BOOLEAN NOT NULL DEFAULT FALSE,
  observaciones TEXT,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_insp_veh ON inspecciones (vehiculo_id, fecha_hora);

CREATE TABLE inspeccion_detalles (
  inspeccion_id INTEGER NOT NULL REFERENCES inspecciones(id) ON DELETE CASCADE,
  componente_id INTEGER NOT NULL REFERENCES componentes_inspeccion(id),
  resultado resultado_componente NOT NULL,
  observacion VARCHAR(250),
  PRIMARY KEY (inspeccion_id, componente_id)
);

CREATE TABLE evidencias_inspeccion (
  id BIGSERIAL PRIMARY KEY,
  inspeccion_id INTEGER NOT NULL REFERENCES inspecciones(id) ON DELETE CASCADE,
  ruta_almacenada VARCHAR(300) NOT NULL,
  mime VARCHAR(80) NOT NULL,
  tamano_bytes INTEGER NOT NULL
);

-- ===== COMBUSTIBLE =====
CREATE TABLE abastecimientos (
  id SERIAL PRIMARY KEY,
  vehiculo_id INTEGER NOT NULL REFERENCES vehiculos(id),
  fecha TIMESTAMP NOT NULL,
  tipo_combustible tipo_combustible NOT NULL,
  litros NUMERIC(9,2) NOT NULL CHECK (litros > 0),
  precio_litro NUMERIC(8,3) NOT NULL CHECK (precio_litro > 0),
  importe_total NUMERIC(12,2) GENERATED ALWAYS AS (round(litros * precio_litro, 2)) STORED,
  kilometraje NUMERIC(10,1),
  proveedor_id INTEGER REFERENCES proveedores_combustible(id),
  responsable_id INTEGER REFERENCES usuarios(id),
  observaciones VARCHAR(250),
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_abast_veh ON abastecimientos (vehiculo_id, fecha);

-- ===== INCIDENTES =====
CREATE TABLE incidentes (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(20) NOT NULL UNIQUE,
  vehiculo_id INTEGER NOT NULL REFERENCES vehiculos(id),
  conductor_id INTEGER REFERENCES conductores(id),
  fecha_hora TIMESTAMP NOT NULL,
  ubicacion VARCHAR(200),
  tipo_id INTEGER NOT NULL REFERENCES tipos_incidente(id),
  gravedad_id SMALLINT NOT NULL REFERENCES niveles_gravedad(id),
  descripcion TEXT NOT NULL,
  danos TEXT,
  medidas_adoptadas TEXT,
  reportado_por INTEGER NOT NULL REFERENCES usuarios(id),
  estado_investigacion estado_investigacion NOT NULL DEFAULT 'pendiente',
  eliminado_en TIMESTAMP,
  creado_en TIMESTAMP NOT NULL DEFAULT sigfv_now(),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_inc_estado ON incidentes (estado_investigacion, fecha_hora);

CREATE TABLE acciones_correctivas (
  id SERIAL PRIMARY KEY,
  incidente_id INTEGER NOT NULL REFERENCES incidentes(id) ON DELETE CASCADE,
  descripcion TEXT NOT NULL,
  responsable_id INTEGER REFERENCES usuarios(id),
  fecha_compromiso DATE,
  estado estado_accion NOT NULL DEFAULT 'pendiente'
);

CREATE TABLE evidencias_incidente (
  id BIGSERIAL PRIMARY KEY,
  incidente_id INTEGER NOT NULL REFERENCES incidentes(id) ON DELETE CASCADE,
  ruta_almacenada VARCHAR(300) NOT NULL,
  mime VARCHAR(80) NOT NULL,
  tamano_bytes INTEGER NOT NULL
);

-- ===== CONTROL =====
CREATE TABLE notificaciones (
  id BIGSERIAL PRIMARY KEY,
  usuario_id INTEGER REFERENCES usuarios(id),
  rol_id INTEGER REFERENCES roles(id),
  tipo VARCHAR(40) NOT NULL,
  titulo VARCHAR(150) NOT NULL,
  mensaje VARCHAR(300),
  entidad VARCHAR(40),
  entidad_id INTEGER,
  leida BOOLEAN NOT NULL DEFAULT FALSE,
  creada_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_not_usr ON notificaciones (usuario_id, leida);

CREATE TABLE auditoria (
  id BIGSERIAL PRIMARY KEY,
  usuario_id INTEGER REFERENCES usuarios(id),
  accion VARCHAR(40) NOT NULL,
  entidad VARCHAR(60) NOT NULL,
  entidad_id VARCHAR(40),
  valores_anteriores JSONB,
  valores_nuevos JSONB,
  ip VARCHAR(45),
  fecha TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_aud_ent ON auditoria (entidad, entidad_id);
CREATE INDEX ix_aud_fecha ON auditoria (fecha);

CREATE TABLE configuraciones (
  clave VARCHAR(80) PRIMARY KEY,
  valor VARCHAR(500) NOT NULL,
  descripcion VARCHAR(200),
  actualizado_en TIMESTAMP NOT NULL DEFAULT sigfv_now()
);

CREATE TABLE asistente_consultas_log (
  id BIGSERIAL PRIMARY KEY,
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
  herramienta VARCHAR(60),
  parametros JSONB,
  resultado resultado_asistente NOT NULL,
  duracion_ms INTEGER,
  fecha TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_ail_usr ON asistente_consultas_log (usuario_id, fecha);

CREATE TABLE asistente_uso_tokens (
  id BIGSERIAL PRIMARY KEY,
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
  proveedor VARCHAR(40) NOT NULL,
  modelo VARCHAR(80) NOT NULL,
  tokens_entrada INTEGER NOT NULL,
  tokens_salida INTEGER NOT NULL,
  fecha TIMESTAMP NOT NULL DEFAULT sigfv_now()
);
CREATE INDEX ix_aut_fecha ON asistente_uso_tokens (usuario_id, fecha);

-- ===== REGLAS DE NEGOCIO EN BD =====
CREATE OR REPLACE FUNCTION fn_validar_asignacion() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_permite boolean;
BEGIN
  SELECT e.permite_asignacion INTO v_permite
    FROM vehiculos v JOIN estados_vehiculo e ON e.id = v.estado_id
   WHERE v.id = NEW.vehiculo_id;
  IF NOT COALESCE(v_permite, FALSE) THEN
    RAISE EXCEPTION 'El estado del vehículo no permite asignaciones';
  END IF;

  IF NEW.conductor_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM conductores c JOIN licencias l ON l.conductor_id = c.id
      WHERE c.id = NEW.conductor_id AND c.estado = 'activo' AND c.eliminado_en IS NULL
        AND l.fecha_vencimiento >= (COALESCE(NEW.fecha_fin, NEW.fecha_inicio))::date) THEN
    RAISE EXCEPTION 'Conductor inhabilitado o con licencia vencida';
  END IF;

  IF EXISTS (
      SELECT 1 FROM asignaciones a
      WHERE a.estado IN ('programada','activa')
        AND (a.vehiculo_id = NEW.vehiculo_id OR (NEW.conductor_id IS NOT NULL AND a.conductor_id = NEW.conductor_id))
        AND a.fecha_inicio < COALESCE(NEW.fecha_fin, TIMESTAMP '9999-12-31')
        AND COALESCE(a.fecha_fin, TIMESTAMP '9999-12-31') > NEW.fecha_inicio) THEN
    RAISE EXCEPTION 'Asignación duplicada: vehículo o conductor ya asignado en ese periodo';
  END IF;

  RETURN NEW;
END $$;

CREATE TRIGGER trg_asignaciones_validar
  BEFORE INSERT ON asignaciones
  FOR EACH ROW EXECUTE FUNCTION fn_validar_asignacion();

-- Actualiza automáticamente actualizado_en
CREATE OR REPLACE FUNCTION fn_set_actualizado() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.actualizado_en := sigfv_now();
  RETURN NEW;
END $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['empresas','unidades_mineras','conductores','usuarios','vehiculos',
      'asignaciones','mantenimientos','documentos','incidentes','configuraciones'] LOOP
    EXECUTE format('CREATE TRIGGER trg_%I_actualizado BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado()', t, t);
  END LOOP;
END $$;

-- Administrador inicial: el hash bcrypt lo genera la aplicación.
CREATE OR REPLACE FUNCTION sp_crear_admin_inicial(p_usuario text, p_correo text, p_hash text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
  IF EXISTS (SELECT 1 FROM usuarios) THEN
    RAISE EXCEPTION 'Ya existen usuarios; el administrador inicial solo se crea una vez';
  END IF;
  INSERT INTO usuarios (nombre_usuario, correo, nombres, apellidos, password_hash)
  VALUES (p_usuario, p_correo, 'Administrador', 'Sistema', p_hash)
  RETURNING id INTO v_id;
  INSERT INTO usuario_roles (usuario_id, rol_id)
  SELECT v_id, id FROM roles WHERE nombre = 'Administrador';
END $$;

-- ===== DATOS INICIALES DE CONFIGURACIÓN =====
INSERT INTO estados_vehiculo (nombre, permite_asignacion, color) VALUES
  ('Operativo', TRUE, '#26865B'),
  ('En mantenimiento', FALSE, '#D4AF37'),
  ('Fuera de servicio', FALSE, '#C64747'),
  ('Alquilado', TRUE, '#447BA8'),
  ('De baja', FALSE, '#42464B');

INSERT INTO niveles_gravedad (id, nombre) VALUES
  (1, 'Leve'), (2, 'Moderado'), (3, 'Grave'), (4, 'Crítico');

INSERT INTO tipos_vehiculo (nombre) VALUES
  ('Camioneta'),('Camión'),('Volquete'),('Excavadora'),('Cargador frontal'),
  ('Retroexcavadora'),('Tractor'),('Bus'),('Minibús'),('Camión cisterna'),
  ('Vehículo de transporte'),('Maquinaria pesada'),('Otro');

INSERT INTO tipos_mantenimiento (nombre) VALUES
  ('Preventivo'),('Correctivo'),('Predictivo'),('Emergencia');

INSERT INTO tipos_documento (nombre, aplica_a, dias_alerta) VALUES
  ('SOAT','vehiculo',30),('Tarjeta de propiedad','vehiculo',60),('Revisión técnica','vehiculo',30),
  ('Póliza','vehiculo',30),('Licencia de conducir','conductor',45),('Autorización','ambos',30),
  ('Certificado','ambos',30),('Contrato','ambos',60),('Otro','ambos',30);

INSERT INTO componentes_inspeccion (nombre, es_critico) VALUES
  ('Frenos',TRUE),('Neumáticos',TRUE),('Luces',FALSE),('Dirección',TRUE),('Espejos',FALSE),
  ('Bocina',FALSE),('Cinturones',TRUE),('Extintor',TRUE),('Botiquín',FALSE),
  ('Niveles de fluidos',FALSE),('Estado del motor',FALSE),('Documentación',FALSE),
  ('Equipamiento de seguridad',FALSE);

INSERT INTO tipos_incidente (nombre) VALUES
  ('Incidente'),('Accidente'),('Avería'),('Daño material');

INSERT INTO categorias_licencia (codigo, descripcion) VALUES
  ('A-I','Vehículos menores'),('A-IIa','Automóviles y camionetas'),
  ('A-IIb','Transporte de pasajeros'),('A-IIIa','Buses'),
  ('A-IIIb','Camiones y volquetes'),('A-IIIc','Transporte especial');

INSERT INTO roles (nombre, descripcion) VALUES
  ('Administrador','Acceso completo'),
  ('Supervisor de flota','Vehículos, asignaciones, mantenimientos y reportes'),
  ('Responsable de mantenimiento','Mantenimientos, repuestos e historial técnico'),
  ('Conductor','Consulta autorizada, inspecciones e incidencias'),
  ('Personal de seguridad','Inspecciones, documentación, incidentes y alertas');

INSERT INTO permisos (modulo, accion)
SELECT m, a::accion_permiso
FROM unnest(ARRAY['dashboard','vehiculos','conductores','asignaciones','mantenimiento',
    'documentos','inspecciones','combustible','incidentes','historial','reportes',
    'usuarios','notificaciones','configuracion','asistente']) AS m
CROSS JOIN unnest(ARRAY['consultar','crear','editar','eliminar','aprobar','exportar','configurar']) AS a;

INSERT INTO rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p WHERE r.nombre = 'Administrador';

INSERT INTO rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r JOIN permisos p ON p.accion = 'consultar'
WHERE r.nombre <> 'Administrador' AND p.modulo NOT IN ('usuarios','configuracion');

INSERT INTO configuraciones (clave, valor, descripcion) VALUES
  ('alerta.documentos.dias','30','Días de anticipación por defecto para vencimientos'),
  ('alerta.mantenimiento.dias','15','Días de anticipación para mantenimientos'),
  ('combustible.desviacion.pct','35','Desviación % sobre el promedio para marcar registro anormal'),
  ('archivos.max_mb','10','Tamaño máximo de adjuntos'),
  ('asistente.activo','1','Habilita el asistente IA'),
  ('asistente.proveedor','anthropic','Proveedor activo'),
  ('asistente.modelo','','Modelo del proveedor'),
  ('asistente.timeout_seg','30','Tiempo máximo de espera'),
  ('asistente.max_tokens','1000','Máximo de tokens por respuesta'),
  ('asistente.max_filas_herramienta','50','Filas máximas por consulta'),
  ('asistente.limite_diario_usuario','50','Mensajes por usuario y día'),
  ('retencion.auditoria.meses','60','Retención mínima de auditoría'),
  ('retencion.asistente_log.meses','12','Retención de logs del asistente');

-- ===== SEGURIDAD DE ACCESO DIRECTO =====
-- El backend accede como rol `postgres` (propietario) y omite RLS.
-- anon/authenticated no pueden leer ni escribir directamente las tablas.
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- ===== VERIFICACIÓN =====
SELECT 'SIGFV instalado en Supabase' AS estado,
       (SELECT count(*) FROM information_schema.tables WHERE table_schema='public') AS tablas,
       (SELECT count(*) FROM roles) AS roles,
       (SELECT count(*) FROM permisos) AS permisos;
