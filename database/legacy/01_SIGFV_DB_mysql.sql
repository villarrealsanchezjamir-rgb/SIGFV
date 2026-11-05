SET NAMES utf8mb4;
-- SIGFV_DB · MySQL 8 · Fase 2
-- Convención: eliminación lógica con `activo`/`eliminado_en`; auditoría con creado_en/actualizado_en.
CREATE DATABASE IF NOT EXISTS SIGFV_DB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE SIGFV_DB;

-- ===== ORGANIZACIÓN =====
CREATE TABLE empresas (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, ruc VARCHAR(20) NOT NULL UNIQUE, razon_social VARCHAR(150) NOT NULL,
  direccion VARCHAR(200), telefono VARCHAR(30), correo VARCHAR(120), activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE unidades_mineras (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, empresa_id INT UNSIGNED NOT NULL, codigo VARCHAR(20) NOT NULL UNIQUE,
  nombre VARCHAR(120) NOT NULL, ubicacion VARCHAR(200), activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (empresa_id) REFERENCES empresas(id)
) ENGINE=InnoDB;
CREATE TABLE areas (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, unidad_minera_id INT UNSIGNED NOT NULL, nombre VARCHAR(100) NOT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1, UNIQUE (unidad_minera_id, nombre), FOREIGN KEY (unidad_minera_id) REFERENCES unidades_mineras(id)
) ENGINE=InnoDB;
CREATE TABLE proyectos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, unidad_minera_id INT UNSIGNED NOT NULL, codigo VARCHAR(30) NOT NULL UNIQUE,
  nombre VARCHAR(150) NOT NULL, fecha_inicio DATE, fecha_fin DATE, activo TINYINT(1) NOT NULL DEFAULT 1,
  FOREIGN KEY (unidad_minera_id) REFERENCES unidades_mineras(id)
) ENGINE=InnoDB;

-- ===== CATÁLOGOS =====
CREATE TABLE marcas (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(80) NOT NULL UNIQUE, activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE modelos (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, marca_id INT UNSIGNED NOT NULL, nombre VARCHAR(80) NOT NULL, activo TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE (marca_id, nombre), FOREIGN KEY (marca_id) REFERENCES marcas(id)) ENGINE=InnoDB;
CREATE TABLE tipos_vehiculo (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(80) NOT NULL UNIQUE, activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE categorias_vehiculo (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(80) NOT NULL UNIQUE, activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE estados_vehiculo (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(50) NOT NULL UNIQUE,
  permite_asignacion TINYINT(1) NOT NULL DEFAULT 0, color VARCHAR(7)) ENGINE=InnoDB;
CREATE TABLE propietarios (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(150) NOT NULL, documento VARCHAR(20) UNIQUE, es_empresa TINYINT(1) NOT NULL DEFAULT 1, activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE categorias_licencia (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, codigo VARCHAR(10) NOT NULL UNIQUE, descripcion VARCHAR(120)) ENGINE=InnoDB;
CREATE TABLE proveedores (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, ruc VARCHAR(20) UNIQUE, nombre VARCHAR(150) NOT NULL, telefono VARCHAR(30), correo VARCHAR(120), activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE talleres (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, proveedor_id INT UNSIGNED, nombre VARCHAR(150) NOT NULL, direccion VARCHAR(200), activo TINYINT(1) NOT NULL DEFAULT 1,
  FOREIGN KEY (proveedor_id) REFERENCES proveedores(id)) ENGINE=InnoDB;
CREATE TABLE proveedores_combustible (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(150) NOT NULL, ruc VARCHAR(20) UNIQUE, ubicacion VARCHAR(200), activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE tipos_mantenimiento (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(60) NOT NULL UNIQUE, activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE tipos_documento (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(80) NOT NULL UNIQUE,
  aplica_a ENUM('vehiculo','conductor','ambos') NOT NULL, dias_alerta SMALLINT UNSIGNED NOT NULL DEFAULT 30, activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE componentes_inspeccion (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(80) NOT NULL UNIQUE,
  es_critico TINYINT(1) NOT NULL DEFAULT 0, activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE tipos_incidente (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(80) NOT NULL UNIQUE, activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE niveles_gravedad (id TINYINT UNSIGNED PRIMARY KEY, nombre VARCHAR(40) NOT NULL UNIQUE) ENGINE=InnoDB;

-- ===== CONDUCTORES =====
CREATE TABLE conductores (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, codigo VARCHAR(20) NOT NULL UNIQUE, nombres VARCHAR(100) NOT NULL, apellidos VARCHAR(100) NOT NULL,
  documento_identidad VARCHAR(20) NOT NULL UNIQUE, telefono VARCHAR(30), correo VARCHAR(120), direccion VARCHAR(200),
  unidad_minera_id INT UNSIGNED, estado ENUM('activo','inactivo','inhabilitado') NOT NULL DEFAULT 'activo', fecha_incorporacion DATE,
  observaciones TEXT, eliminado_en DATETIME, creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (unidad_minera_id) REFERENCES unidades_mineras(id), INDEX ix_cond_estado (estado)
) ENGINE=InnoDB;
CREATE TABLE licencias (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, conductor_id INT UNSIGNED NOT NULL, categoria_id INT UNSIGNED NOT NULL,
  numero VARCHAR(30) NOT NULL UNIQUE, fecha_emision DATE NOT NULL, fecha_vencimiento DATE NOT NULL,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, CHECK (fecha_vencimiento > fecha_emision),
  FOREIGN KEY (conductor_id) REFERENCES conductores(id), FOREIGN KEY (categoria_id) REFERENCES categorias_licencia(id),
  INDEX ix_lic_venc (fecha_vencimiento)
) ENGINE=InnoDB;

-- ===== SEGURIDAD =====
CREATE TABLE roles (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(60) NOT NULL UNIQUE, descripcion VARCHAR(200), activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE permisos (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, modulo VARCHAR(40) NOT NULL,
  accion ENUM('consultar','crear','editar','eliminar','aprobar','exportar','configurar') NOT NULL, UNIQUE (modulo, accion)) ENGINE=InnoDB;
CREATE TABLE rol_permisos (rol_id INT UNSIGNED NOT NULL, permiso_id INT UNSIGNED NOT NULL, PRIMARY KEY (rol_id, permiso_id),
  FOREIGN KEY (rol_id) REFERENCES roles(id), FOREIGN KEY (permiso_id) REFERENCES permisos(id)) ENGINE=InnoDB;
CREATE TABLE usuarios (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, nombre_usuario VARCHAR(50) NOT NULL UNIQUE, correo VARCHAR(120) NOT NULL UNIQUE,
  nombres VARCHAR(100) NOT NULL, apellidos VARCHAR(100) NOT NULL, password_hash VARCHAR(255) NOT NULL, conductor_id INT UNSIGNED,
  intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0, bloqueado_hasta DATETIME, ultimo_acceso DATETIME,
  activo TINYINT(1) NOT NULL DEFAULT 1, eliminado_en DATETIME, creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, FOREIGN KEY (conductor_id) REFERENCES conductores(id)
) ENGINE=InnoDB;
CREATE TABLE usuario_roles (usuario_id INT UNSIGNED NOT NULL, rol_id INT UNSIGNED NOT NULL, PRIMARY KEY (usuario_id, rol_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id), FOREIGN KEY (rol_id) REFERENCES roles(id)) ENGINE=InnoDB;
CREATE TABLE usuario_unidades (usuario_id INT UNSIGNED NOT NULL, unidad_minera_id INT UNSIGNED NOT NULL, PRIMARY KEY (usuario_id, unidad_minera_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id), FOREIGN KEY (unidad_minera_id) REFERENCES unidades_mineras(id)) ENGINE=InnoDB;
CREATE TABLE registros_acceso (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, usuario_id INT UNSIGNED, nombre_usuario VARCHAR(50), ip VARCHAR(45),
  exitoso TINYINT(1) NOT NULL, fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX ix_acc_fecha (fecha)) ENGINE=InnoDB;
CREATE TABLE refresh_tokens (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, usuario_id INT UNSIGNED NOT NULL, token_hash CHAR(64) NOT NULL UNIQUE,
  expira_en DATETIME NOT NULL, revocado TINYINT(1) NOT NULL DEFAULT 0, FOREIGN KEY (usuario_id) REFERENCES usuarios(id)) ENGINE=InnoDB;

-- ===== VEHÍCULOS =====
CREATE TABLE vehiculos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, codigo_interno VARCHAR(20) NOT NULL UNIQUE, placa VARCHAR(15) UNIQUE,
  modelo_id INT UNSIGNED NOT NULL, tipo_id INT UNSIGNED NOT NULL, categoria_id INT UNSIGNED, anio_fabricacion SMALLINT UNSIGNED,
  numero_serie VARCHAR(40), vin VARCHAR(25) UNIQUE, numero_motor VARCHAR(40), kilometraje DECIMAL(10,1) NOT NULL DEFAULT 0,
  capacidad VARCHAR(60), tipo_combustible ENUM('diesel','gasolina','glp','gnv','electrico','otro') NOT NULL DEFAULT 'diesel',
  fecha_adquisicion DATE, propietario_id INT UNSIGNED NOT NULL, proveedor_id INT UNSIGNED, estado_id INT UNSIGNED NOT NULL,
  unidad_minera_id INT UNSIGNED NOT NULL, observaciones TEXT, activo TINYINT(1) NOT NULL DEFAULT 1, eliminado_en DATETIME,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CHECK (kilometraje >= 0),
  FOREIGN KEY (modelo_id) REFERENCES modelos(id), FOREIGN KEY (tipo_id) REFERENCES tipos_vehiculo(id), FOREIGN KEY (categoria_id) REFERENCES categorias_vehiculo(id),
  FOREIGN KEY (propietario_id) REFERENCES propietarios(id), FOREIGN KEY (proveedor_id) REFERENCES proveedores(id),
  FOREIGN KEY (estado_id) REFERENCES estados_vehiculo(id), FOREIGN KEY (unidad_minera_id) REFERENCES unidades_mineras(id),
  INDEX ix_veh_estado (estado_id), INDEX ix_veh_unidad (unidad_minera_id)
) ENGINE=InnoDB;
CREATE TABLE historial_estados_vehiculo (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, vehiculo_id INT UNSIGNED NOT NULL, estado_anterior_id INT UNSIGNED,
  estado_nuevo_id INT UNSIGNED NOT NULL, motivo VARCHAR(250), usuario_id INT UNSIGNED, fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id), FOREIGN KEY (estado_nuevo_id) REFERENCES estados_vehiculo(id), FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
  INDEX ix_hev_veh (vehiculo_id, fecha)) ENGINE=InnoDB;

-- ===== OPERACIONES =====
CREATE TABLE contratos_alquiler (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, numero VARCHAR(30) NOT NULL UNIQUE, proveedor_id INT UNSIGNED NOT NULL,
  fecha_inicio DATE NOT NULL, fecha_fin DATE NOT NULL, tarifa DECIMAL(12,2), condiciones TEXT, estado ENUM('vigente','vencido','rescindido') NOT NULL DEFAULT 'vigente',
  CHECK (fecha_fin >= fecha_inicio), FOREIGN KEY (proveedor_id) REFERENCES proveedores(id)) ENGINE=InnoDB;
CREATE TABLE asignaciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, vehiculo_id INT UNSIGNED NOT NULL, conductor_id INT UNSIGNED, responsable_id INT UNSIGNED NOT NULL,
  contrato_id INT UNSIGNED, area_id INT UNSIGNED, unidad_minera_id INT UNSIGNED NOT NULL, proyecto_id INT UNSIGNED,
  tipo ENUM('operativa','alquiler','temporal','permanente') NOT NULL DEFAULT 'operativa', fecha_inicio DATETIME NOT NULL, fecha_fin DATETIME,
  estado ENUM('programada','activa','finalizada','cancelada') NOT NULL DEFAULT 'programada', observaciones TEXT,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio),
  FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id), FOREIGN KEY (conductor_id) REFERENCES conductores(id), FOREIGN KEY (responsable_id) REFERENCES usuarios(id),
  FOREIGN KEY (contrato_id) REFERENCES contratos_alquiler(id), FOREIGN KEY (area_id) REFERENCES areas(id),
  FOREIGN KEY (unidad_minera_id) REFERENCES unidades_mineras(id), FOREIGN KEY (proyecto_id) REFERENCES proyectos(id),
  INDEX ix_asig_veh (vehiculo_id, estado), INDEX ix_asig_cond (conductor_id, estado)
) ENGINE=InnoDB;
CREATE TABLE devoluciones (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, asignacion_id INT UNSIGNED NOT NULL UNIQUE, fecha DATETIME NOT NULL,
  kilometraje DECIMAL(10,1), condicion VARCHAR(250), recibido_por INT UNSIGNED NOT NULL,
  FOREIGN KEY (asignacion_id) REFERENCES asignaciones(id), FOREIGN KEY (recibido_por) REFERENCES usuarios(id)) ENGINE=InnoDB;

-- ===== MANTENIMIENTO =====
CREATE TABLE mantenimientos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, vehiculo_id INT UNSIGNED NOT NULL, tipo_id INT UNSIGNED NOT NULL, fecha DATE NOT NULL,
  kilometraje DECIMAL(10,1), descripcion TEXT, diagnostico TEXT, trabajo_realizado TEXT, responsable_id INT UNSIGNED, taller_id INT UNSIGNED,
  costo DECIMAL(12,2) NOT NULL DEFAULT 0, proximo_fecha DATE, proximo_km DECIMAL(10,1),
  estado ENUM('programado','en_proceso','completado','cancelado') NOT NULL DEFAULT 'programado', eliminado_en DATETIME,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id), FOREIGN KEY (tipo_id) REFERENCES tipos_mantenimiento(id),
  FOREIGN KEY (responsable_id) REFERENCES usuarios(id), FOREIGN KEY (taller_id) REFERENCES talleres(id),
  INDEX ix_mant_veh (vehiculo_id, fecha), INDEX ix_mant_estado (estado, fecha)
) ENGINE=InnoDB;
CREATE TABLE repuestos (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, codigo VARCHAR(30) NOT NULL UNIQUE, nombre VARCHAR(150) NOT NULL,
  costo_referencial DECIMAL(12,2), activo TINYINT(1) NOT NULL DEFAULT 1) ENGINE=InnoDB;
CREATE TABLE mantenimiento_repuestos (mantenimiento_id INT UNSIGNED NOT NULL, repuesto_id INT UNSIGNED NOT NULL, cantidad DECIMAL(10,2) NOT NULL,
  costo_unitario DECIMAL(12,2) NOT NULL, PRIMARY KEY (mantenimiento_id, repuesto_id), CHECK (cantidad > 0),
  FOREIGN KEY (mantenimiento_id) REFERENCES mantenimientos(id), FOREIGN KEY (repuesto_id) REFERENCES repuestos(id)) ENGINE=InnoDB;

-- ===== DOCUMENTACIÓN =====
CREATE TABLE documentos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, tipo_id INT UNSIGNED NOT NULL, vehiculo_id INT UNSIGNED, conductor_id INT UNSIGNED,
  numero VARCHAR(50), fecha_emision DATE, fecha_vencimiento DATE, dias_alerta SMALLINT UNSIGNED, observaciones VARCHAR(250),
  eliminado_en DATETIME, creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CHECK ((vehiculo_id IS NOT NULL) <> (conductor_id IS NOT NULL)),
  FOREIGN KEY (tipo_id) REFERENCES tipos_documento(id), FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id), FOREIGN KEY (conductor_id) REFERENCES conductores(id),
  INDEX ix_doc_venc (fecha_vencimiento)
) ENGINE=InnoDB;
CREATE TABLE archivos_adjuntos (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, documento_id INT UNSIGNED NOT NULL, nombre_original VARCHAR(200) NOT NULL,
  ruta_almacenada VARCHAR(300) NOT NULL, mime VARCHAR(80) NOT NULL, tamano_bytes INT UNSIGNED NOT NULL, sha256 CHAR(64) NOT NULL,
  subido_por INT UNSIGNED, subido_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (documento_id) REFERENCES documentos(id), FOREIGN KEY (subido_por) REFERENCES usuarios(id)) ENGINE=InnoDB;

-- ===== INSPECCIONES =====
CREATE TABLE inspecciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, vehiculo_id INT UNSIGNED NOT NULL, conductor_id INT UNSIGNED NOT NULL, fecha_hora DATETIME NOT NULL,
  resultado ENUM('conforme','conforme_con_observaciones','no_conforme') NOT NULL, bloquea_vehiculo TINYINT(1) NOT NULL DEFAULT 0,
  observaciones TEXT, creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id), FOREIGN KEY (conductor_id) REFERENCES conductores(id), INDEX ix_insp_veh (vehiculo_id, fecha_hora)
) ENGINE=InnoDB;
CREATE TABLE inspeccion_detalles (inspeccion_id INT UNSIGNED NOT NULL, componente_id INT UNSIGNED NOT NULL,
  resultado ENUM('conforme','observado','no_conforme') NOT NULL, observacion VARCHAR(250), PRIMARY KEY (inspeccion_id, componente_id),
  FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id), FOREIGN KEY (componente_id) REFERENCES componentes_inspeccion(id)) ENGINE=InnoDB;
CREATE TABLE evidencias_inspeccion (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, inspeccion_id INT UNSIGNED NOT NULL, ruta_almacenada VARCHAR(300) NOT NULL,
  mime VARCHAR(80) NOT NULL, tamano_bytes INT UNSIGNED NOT NULL, FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id)) ENGINE=InnoDB;

-- ===== COMBUSTIBLE =====
CREATE TABLE abastecimientos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, vehiculo_id INT UNSIGNED NOT NULL, fecha DATETIME NOT NULL,
  tipo_combustible ENUM('diesel','gasolina','glp','gnv','electrico','otro') NOT NULL, litros DECIMAL(9,2) NOT NULL, precio_litro DECIMAL(8,3) NOT NULL,
  importe_total DECIMAL(12,2) GENERATED ALWAYS AS (ROUND(litros * precio_litro, 2)) STORED, kilometraje DECIMAL(10,1),
  proveedor_id INT UNSIGNED, responsable_id INT UNSIGNED, observaciones VARCHAR(250), creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (litros > 0 AND precio_litro > 0), FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id),
  FOREIGN KEY (proveedor_id) REFERENCES proveedores_combustible(id), FOREIGN KEY (responsable_id) REFERENCES usuarios(id), INDEX ix_abast_veh (vehiculo_id, fecha)
) ENGINE=InnoDB;

-- ===== INCIDENTES =====
CREATE TABLE incidentes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, codigo VARCHAR(20) NOT NULL UNIQUE, vehiculo_id INT UNSIGNED NOT NULL, conductor_id INT UNSIGNED,
  fecha_hora DATETIME NOT NULL, ubicacion VARCHAR(200), tipo_id INT UNSIGNED NOT NULL, gravedad_id TINYINT UNSIGNED NOT NULL, descripcion TEXT NOT NULL,
  danos TEXT, medidas_adoptadas TEXT, reportado_por INT UNSIGNED NOT NULL,
  estado_investigacion ENUM('pendiente','en_investigacion','cerrado') NOT NULL DEFAULT 'pendiente', eliminado_en DATETIME,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id), FOREIGN KEY (conductor_id) REFERENCES conductores(id), FOREIGN KEY (tipo_id) REFERENCES tipos_incidente(id),
  FOREIGN KEY (gravedad_id) REFERENCES niveles_gravedad(id), FOREIGN KEY (reportado_por) REFERENCES usuarios(id), INDEX ix_inc_estado (estado_investigacion, fecha_hora)
) ENGINE=InnoDB;
CREATE TABLE acciones_correctivas (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, incidente_id INT UNSIGNED NOT NULL, descripcion TEXT NOT NULL, responsable_id INT UNSIGNED,
  fecha_compromiso DATE, estado ENUM('pendiente','en_curso','cumplida') NOT NULL DEFAULT 'pendiente',
  FOREIGN KEY (incidente_id) REFERENCES incidentes(id), FOREIGN KEY (responsable_id) REFERENCES usuarios(id)) ENGINE=InnoDB;
CREATE TABLE evidencias_incidente (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, incidente_id INT UNSIGNED NOT NULL, ruta_almacenada VARCHAR(300) NOT NULL,
  mime VARCHAR(80) NOT NULL, tamano_bytes INT UNSIGNED NOT NULL, FOREIGN KEY (incidente_id) REFERENCES incidentes(id)) ENGINE=InnoDB;

-- ===== CONTROL =====
CREATE TABLE notificaciones (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, usuario_id INT UNSIGNED, rol_id INT UNSIGNED, tipo VARCHAR(40) NOT NULL,
  titulo VARCHAR(150) NOT NULL, mensaje VARCHAR(300), entidad VARCHAR(40), entidad_id INT UNSIGNED, leida TINYINT(1) NOT NULL DEFAULT 0,
  creada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (usuario_id) REFERENCES usuarios(id), FOREIGN KEY (rol_id) REFERENCES roles(id),
  INDEX ix_not_usr (usuario_id, leida)) ENGINE=InnoDB;
CREATE TABLE auditoria (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, usuario_id INT UNSIGNED, accion VARCHAR(40) NOT NULL, entidad VARCHAR(60) NOT NULL,
  entidad_id VARCHAR(40), valores_anteriores JSON, valores_nuevos JSON, ip VARCHAR(45), fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX ix_aud_ent (entidad, entidad_id), INDEX ix_aud_fecha (fecha)) ENGINE=InnoDB;
CREATE TABLE configuraciones (clave VARCHAR(80) PRIMARY KEY, valor VARCHAR(500) NOT NULL, descripcion VARCHAR(200),
  actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP) ENGINE=InnoDB;

-- ===== ASISTENTE IA (la clave API NUNCA se guarda aquí; va en variable de entorno) =====
CREATE TABLE asistente_consultas_log (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, usuario_id INT UNSIGNED NOT NULL, herramienta VARCHAR(60),
  parametros JSON, resultado ENUM('exito','error','denegado') NOT NULL, duracion_ms INT UNSIGNED, fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id), INDEX ix_ail_usr (usuario_id, fecha)) ENGINE=InnoDB;
CREATE TABLE asistente_uso_tokens (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, usuario_id INT UNSIGNED NOT NULL, proveedor VARCHAR(40) NOT NULL,
  modelo VARCHAR(80) NOT NULL, tokens_entrada INT UNSIGNED NOT NULL, tokens_salida INT UNSIGNED NOT NULL, fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id), INDEX ix_aut_fecha (usuario_id, fecha)) ENGINE=InnoDB;

-- ===== REGLAS DE NEGOCIO EN BD: asignaciones =====
DELIMITER $$
CREATE TRIGGER trg_asignaciones_validar BEFORE INSERT ON asignaciones FOR EACH ROW
BEGIN
  IF (SELECT e.permite_asignacion FROM vehiculos v JOIN estados_vehiculo e ON e.id = v.estado_id WHERE v.id = NEW.vehiculo_id) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El estado del vehículo no permite asignaciones';
  END IF;
  IF NEW.conductor_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM conductores c JOIN licencias l ON l.conductor_id = c.id
      WHERE c.id = NEW.conductor_id AND c.estado = 'activo' AND c.eliminado_en IS NULL
        AND l.fecha_vencimiento >= DATE(COALESCE(NEW.fecha_fin, NEW.fecha_inicio))) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conductor inhabilitado o con licencia vencida';
  END IF;
  IF EXISTS (SELECT 1 FROM asignaciones a WHERE a.estado IN ('programada','activa')
      AND (a.vehiculo_id = NEW.vehiculo_id OR (NEW.conductor_id IS NOT NULL AND a.conductor_id = NEW.conductor_id))
      AND a.fecha_inicio < COALESCE(NEW.fecha_fin, '9999-12-31') AND COALESCE(a.fecha_fin, '9999-12-31') > NEW.fecha_inicio) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Asignación duplicada: vehículo o conductor ya asignado en ese periodo';
  END IF;
END$$

-- Admin inicial: el hash lo genera la aplicación (PBKDF2/Argon2/BCrypt); jamás se escribe una contraseña aquí.
CREATE PROCEDURE sp_crear_admin_inicial(IN p_usuario VARCHAR(50), IN p_correo VARCHAR(120), IN p_hash VARCHAR(255))
BEGIN
  DECLARE v_id INT UNSIGNED;
  IF EXISTS (SELECT 1 FROM usuarios) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existen usuarios; el administrador inicial solo se crea una vez';
  END IF;
  START TRANSACTION;
  INSERT INTO usuarios (nombre_usuario, correo, nombres, apellidos, password_hash) VALUES (p_usuario, p_correo, 'Administrador', 'Sistema', p_hash);
  SET v_id = LAST_INSERT_ID();
  INSERT INTO usuario_roles SELECT v_id, id FROM roles WHERE nombre = 'Administrador';
  COMMIT;
END$$
DELIMITER ;

-- ===== DATOS INICIALES DE CONFIGURACIÓN (no son datos de prueba) =====
INSERT INTO estados_vehiculo (nombre, permite_asignacion, color) VALUES
 ('Operativo',1,'#26865B'),('En mantenimiento',0,'#D4AF37'),('Fuera de servicio',0,'#C64747'),('Alquilado',1,'#447BA8'),('De baja',0,'#42464B');
INSERT INTO niveles_gravedad VALUES (1,'Leve'),(2,'Moderado'),(3,'Grave'),(4,'Crítico');
INSERT INTO tipos_vehiculo (nombre) VALUES ('Camioneta'),('Camión'),('Volquete'),('Excavadora'),('Cargador frontal'),('Retroexcavadora'),('Tractor'),('Bus'),
 ('Minibús'),('Camión cisterna'),('Vehículo de transporte'),('Maquinaria pesada'),('Otro');
INSERT INTO tipos_mantenimiento (nombre) VALUES ('Preventivo'),('Correctivo'),('Predictivo'),('Emergencia');
INSERT INTO tipos_documento (nombre, aplica_a, dias_alerta) VALUES ('SOAT','vehiculo',30),('Tarjeta de propiedad','vehiculo',60),('Revisión técnica','vehiculo',30),
 ('Póliza','vehiculo',30),('Licencia de conducir','conductor',45),('Autorización','ambos',30),('Certificado','ambos',30),('Contrato','ambos',60),('Otro','ambos',30);
INSERT INTO componentes_inspeccion (nombre, es_critico) VALUES ('Frenos',1),('Neumáticos',1),('Luces',0),('Dirección',1),('Espejos',0),('Bocina',0),('Cinturones',1),
 ('Extintor',1),('Botiquín',0),('Niveles de fluidos',0),('Estado del motor',0),('Documentación',0),('Equipamiento de seguridad',0);
INSERT INTO tipos_incidente (nombre) VALUES ('Incidente'),('Accidente'),('Avería'),('Daño material');
INSERT INTO categorias_licencia (codigo, descripcion) VALUES ('A-I','Vehículos menores'),('A-IIa','Automóviles y camionetas'),('A-IIb','Transporte de pasajeros'),
 ('A-IIIa','Buses'),('A-IIIb','Camiones y volquetes'),('A-IIIc','Transporte especial');
INSERT INTO roles (nombre, descripcion) VALUES ('Administrador','Acceso completo'),('Supervisor de flota','Vehículos, asignaciones, mantenimientos y reportes'),
 ('Responsable de mantenimiento','Mantenimientos, repuestos e historial técnico'),('Conductor','Consulta autorizada, inspecciones e incidencias'),
 ('Personal de seguridad','Inspecciones, documentación, incidentes y alertas');
INSERT INTO permisos (modulo, accion)
 SELECT m.n, a.n FROM (SELECT 'dashboard' n UNION ALL SELECT 'vehiculos' UNION ALL SELECT 'conductores' UNION ALL SELECT 'asignaciones' UNION ALL SELECT 'mantenimiento'
  UNION ALL SELECT 'documentos' UNION ALL SELECT 'inspecciones' UNION ALL SELECT 'combustible' UNION ALL SELECT 'incidentes' UNION ALL SELECT 'historial'
  UNION ALL SELECT 'reportes' UNION ALL SELECT 'usuarios' UNION ALL SELECT 'notificaciones' UNION ALL SELECT 'configuracion' UNION ALL SELECT 'asistente') m
 CROSS JOIN (SELECT 'consultar' n UNION ALL SELECT 'crear' UNION ALL SELECT 'editar' UNION ALL SELECT 'eliminar' UNION ALL SELECT 'aprobar'
  UNION ALL SELECT 'exportar' UNION ALL SELECT 'configurar') a;
-- Administrador: todos los permisos. Los demás roles se ajustan desde Módulo 12 (mínimo inicial: consultar + asistente).
INSERT INTO rol_permisos SELECT r.id, p.id FROM roles r CROSS JOIN permisos p WHERE r.nombre = 'Administrador';
INSERT INTO rol_permisos SELECT r.id, p.id FROM roles r JOIN permisos p ON p.accion = 'consultar'
 WHERE r.nombre <> 'Administrador' AND p.modulo NOT IN ('usuarios','configuracion');
INSERT INTO configuraciones (clave, valor, descripcion) VALUES
 ('alerta.documentos.dias','30','Días de anticipación por defecto para vencimientos'),
 ('alerta.mantenimiento.dias','15','Días de anticipación para mantenimientos'),
 ('combustible.desviacion.pct','35','Desviación % sobre el promedio para marcar registro anormal'),
 ('archivos.max_mb','10','Tamaño máximo de adjuntos'),
 ('asistente.activo','1','Habilita el asistente IA'),('asistente.proveedor','anthropic','Proveedor activo'),('asistente.modelo','','Modelo del proveedor'),
 ('asistente.timeout_seg','30','Tiempo máximo de espera'),('asistente.max_tokens','1000','Máximo de tokens por respuesta'),
 ('asistente.max_filas_herramienta','50','Filas máximas por consulta'),('asistente.limite_diario_usuario','50','Mensajes por usuario y día'),
 ('retencion.auditoria.meses','60','Retención mínima de auditoría'),('retencion.asistente_log.meses','12','Retención de logs del asistente');
