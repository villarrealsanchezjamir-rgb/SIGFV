-- =====================================================================
-- SIGFV · Datos de prueba realistas para gestión de flota vehicular
-- Ejecutar DESPUÉS de 01_SIGFV_Supabase.sql, en Supabase → SQL Editor.
-- Es idempotente: puede ejecutarse varias veces sin duplicar registros.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Catálogos base (el esquema ya los trae; aquí se aseguran)
-- ---------------------------------------------------------------------
INSERT INTO estados_vehiculo (nombre, permite_asignacion, color) VALUES
  ('Operativo', TRUE, '#26865B'),
  ('En mantenimiento', FALSE, '#D4AF37'),
  ('Fuera de servicio', FALSE, '#C64747'),
  ('Alquilado', TRUE, '#447BA8'),
  ('De baja', FALSE, '#42464B')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO niveles_gravedad (id, nombre) VALUES
  (1, 'Leve'), (2, 'Moderado'), (3, 'Grave'), (4, 'Crítico')
ON CONFLICT (id) DO NOTHING;

INSERT INTO tipos_vehiculo (nombre) VALUES
  ('Camioneta'), ('Camión'), ('Volquete'), ('Excavadora'), ('Cargador frontal'),
  ('Retroexcavadora'), ('Tractor'), ('Bus'), ('Minibús'), ('Camión cisterna'),
  ('Vehículo de transporte'), ('Maquinaria pesada'), ('Otro')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipos_mantenimiento (nombre) VALUES
  ('Preventivo'), ('Correctivo'), ('Predictivo'), ('Emergencia')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipos_documento (nombre, aplica_a, dias_alerta) VALUES
  ('SOAT', 'vehiculo', 30),
  ('Tarjeta de propiedad', 'vehiculo', 60),
  ('Revisión técnica', 'vehiculo', 30),
  ('Póliza', 'vehiculo', 30),
  ('Licencia de conducir', 'conductor', 45),
  ('Autorización', 'ambos', 30),
  ('Certificado', 'ambos', 30),
  ('Contrato', 'ambos', 60),
  ('Otro', 'ambos', 30)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO componentes_inspeccion (nombre, es_critico) VALUES
  ('Frenos', TRUE), ('Neumáticos', TRUE), ('Luces', FALSE), ('Dirección', TRUE),
  ('Espejos', FALSE), ('Bocina', FALSE), ('Cinturones', TRUE), ('Extintor', TRUE),
  ('Botiquín', FALSE), ('Niveles de fluidos', FALSE), ('Estado del motor', FALSE),
  ('Documentación', FALSE), ('Equipamiento de seguridad', FALSE)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipos_incidente (nombre) VALUES
  ('Incidente'), ('Accidente'), ('Avería'), ('Daño material')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO categorias_licencia (codigo, descripcion) VALUES
  ('A-I', 'Vehículos menores'),
  ('A-IIa', 'Automóviles y camionetas'),
  ('A-IIb', 'Transporte de pasajeros'),
  ('A-IIIa', 'Buses'),
  ('A-IIIb', 'Camiones y volquetes'),
  ('A-IIIc', 'Transporte especial')
ON CONFLICT (codigo) DO NOTHING;

-- ---------------------------------------------------------------------
-- 1. Empresa y unidades mineras
-- ---------------------------------------------------------------------
INSERT INTO empresas (ruc, razon_social, direccion, telefono, correo) VALUES
  ('20512345678', 'Compañía Minera Andina del Perú S.A.C.',
   'Av. Javier Prado Este 4200, Santiago de Surco, Lima',
   '(01) 615-8000', 'operaciones@mineraandina.pe')
ON CONFLICT (ruc) DO NOTHING;

INSERT INTO unidades_mineras (empresa_id, codigo, nombre, ubicacion)
SELECT e.id, v.codigo, v.nombre, v.ubicacion
FROM (VALUES
  ('UM-ANT', 'Unidad Minera Antamina', 'San Marcos, Huari, Áncash'),
  ('UM-LBA', 'Unidad Minera Las Bambas', 'Challhuahuacho, Cotabambas, Apurímac'),
  ('UM-QVE', 'Unidad Minera Quellaveco', 'Torata, Mariscal Nieto, Moquegua'),
  ('UM-CVE', 'Unidad Minera Cerro Verde', 'Yarabamba, Arequipa')
) AS v(codigo, nombre, ubicacion)
JOIN empresas e ON e.ruc = '20512345678'
ON CONFLICT (codigo) DO NOTHING;

-- ---------------------------------------------------------------------
-- 2. Áreas y proyectos
-- ---------------------------------------------------------------------
INSERT INTO areas (unidad_minera_id, nombre)
SELECT um.id, v.area
FROM (VALUES
  ('UM-ANT', 'Operaciones Mina'), ('UM-ANT', 'Mantenimiento'),
  ('UM-ANT', 'Seguridad y Salud Ocupacional'), ('UM-ANT', 'Logística'),
  ('UM-LBA', 'Operaciones Mina'), ('UM-LBA', 'Mantenimiento'), ('UM-LBA', 'Transporte'),
  ('UM-QVE', 'Operaciones Mina'), ('UM-QVE', 'Mantenimiento'), ('UM-QVE', 'Planta'),
  ('UM-CVE', 'Operaciones Mina'), ('UM-CVE', 'Mantenimiento'), ('UM-CVE', 'Seguridad')
) AS v(unidad, area)
JOIN unidades_mineras um ON um.codigo = v.unidad
ON CONFLICT DO NOTHING;

INSERT INTO proyectos (unidad_minera_id, codigo, nombre, fecha_inicio, fecha_fin, activo)
SELECT um.id, v.codigo, v.nombre,
       CURRENT_DATE + v.inicio::int, CURRENT_DATE + v.fin::int, TRUE
FROM (VALUES
  ('UM-ANT', 'PRY-2026-01', 'Ampliación Tajo Norte',            -180,  300),
  ('UM-ANT', 'PRY-2026-02', 'Explotación Banco 2450',           -120,  240),
  ('UM-LBA', 'PRY-2026-03', 'Transporte de mineral Las Bambas',  -90,  400),
  ('UM-QVE', 'PRY-2026-04', 'Profundización Tajo Quellaveco',   -150,  500),
  ('UM-CVE', 'PRY-2026-05', 'Mantenimiento de flota Cerro Verde', -60, 180)
) AS v(unidad, codigo, nombre, inicio, fin)
JOIN unidades_mineras um ON um.codigo = v.unidad
ON CONFLICT (codigo) DO NOTHING;

-- ---------------------------------------------------------------------
-- 3. Marcas y modelos
-- ---------------------------------------------------------------------
INSERT INTO marcas (nombre) VALUES
  ('Volvo'), ('Scania'), ('Toyota'), ('Hino'), ('Isuzu'), ('Mercedes-Benz'),
  ('Hyundai'), ('Mitsubishi Fuso'), ('Caterpillar'), ('Komatsu'),
  ('John Deere'), ('Freightliner'), ('International'), ('Volkswagen'),
  ('Nissan'), ('Ford'), ('Chevrolet'), ('JAC'), ('Sinotruk'), ('Maxus')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO modelos (marca_id, nombre)
SELECT m.id, v.modelo
FROM (VALUES
  ('Toyota', 'Hilux 2.8 4x4'), ('Toyota', 'Land Cruiser Prado 2.8'),
  ('Toyota', 'Hiace'), ('Toyota', 'Fortuner'),
  ('Volvo', 'FH 460'), ('Volvo', 'FMX 440'), ('Volvo', 'FH 540'),
  ('Scania', 'R 450'), ('Scania', 'P 360'), ('Scania', 'G 410'),
  ('Hino', '300 Series'), ('Hino', '500 Series'),
  ('Isuzu', 'NPR'), ('Isuzu', 'FVR'), ('Isuzu', 'D-Max'),
  ('Mercedes-Benz', 'Actros 2645'), ('Mercedes-Benz', 'Atego 1725'),
  ('Mercedes-Benz', 'Sprinter 416'),
  ('Hyundai', 'H100'), ('Hyundai', 'HD65'),
  ('Mitsubishi Fuso', 'Canter 6.0'), ('Mitsubishi Fuso', 'Fighter FM'),
  ('Caterpillar', '320D'), ('Caterpillar', '336D'), ('Caterpillar', '950GC'),
  ('Caterpillar', '430F'),
  ('Komatsu', 'PC200'), ('Komatsu', 'WA380'), ('Komatsu', 'HD465'),
  ('John Deere', '310L'), ('John Deere', '672G'),
  ('Freightliner', 'Cascadia 113'), ('Freightliner', 'M2 106'),
  ('International', 'WorkStar 7600'),
  ('Volkswagen', 'Amarok'), ('Volkswagen', 'Constellation 17.230'),
  ('Nissan', 'Frontier'), ('Nissan', 'NP300'),
  ('Ford', 'Ranger'), ('Ford', 'F-350'),
  ('Chevrolet', 'Silverado'), ('Chevrolet', 'N300'),
  ('JAC', 'T8'), ('JAC', '1040'),
  ('Sinotruk', 'Howo 371'), ('Maxus', 'T60'), ('Maxus', 'V90')
) AS v(marca, modelo)
JOIN marcas m ON m.nombre = v.marca
ON CONFLICT DO NOTHING;

INSERT INTO categorias_vehiculo (nombre) VALUES
  ('Vehículo liviano'), ('Vehículo pesado'), ('Maquinaria pesada'),
  ('Transporte de personal'), ('Unidad cisterna'), ('Unidad de emergencia')
ON CONFLICT (nombre) DO NOTHING;

-- ---------------------------------------------------------------------
-- 4. Propietarios y proveedores
-- ---------------------------------------------------------------------
INSERT INTO propietarios (nombre, documento, es_empresa) VALUES
  ('Compañía Minera Andina del Perú S.A.C.', '20512345678', TRUE),
  ('Leasing Total Perú S.A.', '20556677889', TRUE),
  ('Transportes y Servicios San Martín S.R.L.', '20445566778', TRUE),
  ('José Antonio Ríos Delgado', '09876543', FALSE)
ON CONFLICT DO NOTHING;

INSERT INTO proveedores (ruc, nombre, telefono, correo) VALUES
  ('20100123456', 'Volvo Perú S.A.', '(01) 618-7000', 'servicio@volvoperu.com.pe'),
  ('20100234567', 'Scania del Perú S.A.', '(01) 615-9000', 'taller@scaniaperu.com.pe'),
  ('20100345678', 'Toyota del Perú S.A.', '(01) 219-3000', 'servicio@toyotaperu.com.pe'),
  ('20100456789', 'Derco Perú S.A.', '(01) 712-3000', 'postventa@derco.com.pe'),
  ('20100567890', 'Automotriz Andina S.A.', '(01) 348-2200', 'taller@automotrizandina.pe'),
  ('20100678901', 'Maquinarias Perú S.A.', '(01) 513-8000', 'soporte@maquinariasperu.pe'),
  ('20100789012', 'Komatsu Mitsui Maquinarias Perú S.A.', '(01) 518-6000', 'servicio@kmp.com.pe'),
  ('20100890123', 'Llantas del Perú S.A.C.', '(01) 471-9900', 'ventas@llantasdelperu.pe'),
  ('20100901234', 'Repuestos Diésel Lima S.A.C.', '(01) 452-1717', 'repuestos@dieselima.pe'),
  ('20556677889', 'Leasing Total Perú S.A.', '(01) 705-4000', 'operaciones@leasingtotal.pe'),
  ('20445566778', 'Transportes y Servicios San Martín S.R.L.', '(064) 421-500', 'contacto@transportessanmartin.pe')
ON CONFLICT DO NOTHING;

INSERT INTO talleres (proveedor_id, nombre, direccion)
SELECT p.id, v.nombre, v.direccion
FROM (VALUES
  ('Taller Autorizado Volvo - Ate', 'Av. Nicolás Ayllón 2450, Ate, Lima', '20100123456'),
  ('Scania Service Center - Callao', 'Av. Elmer Faucett 2850, Callao', '20100234567'),
  ('Toyota Servicio Técnico - Surquillo', 'Av. Domingo Orué 145, Surquillo, Lima', '20100345678'),
  ('Derco Servicio Automotriz - La Molina', 'Av. Raúl Ferrero 1150, La Molina, Lima', '20100456789'),
  ('Automotriz Andina - Ate', 'Carretera Central km 12.5, Ate, Lima', '20100567890'),
  ('Maquinarias Perú - La Joya', 'Km 28 Panamericana Sur, La Joya, Arequipa', '20100678901'),
  ('Komatsu Service - Quellaveco', 'Campiña Alta, Torata, Moquegua', '20100789012'),
  ('Servicio Integral Diésel Andino', 'Av. Los Frutales 340, Ate, Lima', '20100901234'),
  ('Llantas y Alineamiento Rímac', 'Av. Alcázar 780, Rímac, Lima', '20100890123')
) AS v(nombre, direccion, ruc)
JOIN proveedores p ON p.ruc = v.ruc
WHERE NOT EXISTS (SELECT 1 FROM talleres t WHERE t.nombre = v.nombre);

INSERT INTO proveedores_combustible (nombre, ruc, ubicacion) VALUES
  ('Primax Perú S.A.', '20200123456', 'Av. República de Panamá 3418, San Isidro, Lima'),
  ('Repsol Perú S.A.C.', '20200234567', 'Av. Víctor Andrés Belaunde 147, San Isidro, Lima'),
  ('Petroperú S.A.', '20100999999', 'Av. Enrique Canaval Moreyra 150, San Isidro, Lima'),
  ('Pecsa (Coesti S.A.)', '20200345678', 'Av. Paseo de la República 5695, Miraflores, Lima'),
  ('Gazel Perú S.A.C.', '20200456789', 'Av. Javier Prado Este 1066, San Isidro, Lima')
ON CONFLICT (ruc) DO NOTHING;

-- ---------------------------------------------------------------------
-- 5. Repuestos
-- ---------------------------------------------------------------------
INSERT INTO repuestos (codigo, nombre, costo_referencial) VALUES
  ('REP-001', 'Filtro de aceite Fleetguard LF9070', 85.50),
  ('REP-002', 'Filtro de combustible Fleetguard FS1000', 120.00),
  ('REP-003', 'Filtro de aire Donaldson P181052', 145.00),
  ('REP-004', 'Aceite motor 15W-40 Mobil Delvac (galón)', 95.00),
  ('REP-005', 'Pastillas de freno delanteras Volvo FH', 480.00),
  ('REP-006', 'Neumático 295/80 R22.5 Michelin XDE2', 1450.00),
  ('REP-007', 'Batería 12V 100Ah Bosch', 620.00),
  ('REP-008', 'Amortiguador delantero Scania R', 780.00),
  ('REP-009', 'Correa de distribución Gates', 210.00),
  ('REP-010', 'Refrigerante concentrado 50/50 (galón)', 65.00),
  ('REP-011', 'Kit de embrague Volvo FMX', 2850.00),
  ('REP-012', 'Bomba de agua Hino 500', 950.00)
ON CONFLICT (codigo) DO NOTHING;

-- ---------------------------------------------------------------------
-- 6. Conductores y licencias
-- ---------------------------------------------------------------------
INSERT INTO conductores (codigo, nombres, apellidos, documento_identidad, telefono,
                         correo, direccion, unidad_minera_id, estado, fecha_incorporacion,
                         observaciones)
SELECT v.codigo, v.nombres, v.apellidos, v.dni, v.telefono, v.correo, v.direccion,
       um.id, v.estado::estado_conductor, v.incorporacion::date, v.obs
FROM (VALUES
  ('CD-001', 'Carlos Alberto', 'Mendoza Ríos', '41234567', '+51 987 654 321',
   'carlos.mendoza@mineraandina.pe', 'Av. Los Álamos 245, San Juan de Lurigancho, Lima',
   'UM-ANT', 'activo', '2019-03-11', 'Conductor de camioneta de supervisión.'),
  ('CD-002', 'Luis Fernando', 'Quispe Mamani', '42345678', '+51 986 123 456',
   'luis.quispe@mineraandina.pe', 'Jr. Los Andes 812, El Tambo, Huancayo',
   'UM-LBA', 'activo', '2018-07-02', 'Operador de camión de 30 toneladas.'),
  ('CD-003', 'Jorge Luis', 'Huamán Choque', '43456789', '+51 985 234 567',
   'jorge.huaman@mineraandina.pe', 'Av. Independencia 1450, Arequipa',
   'UM-CVE', 'activo', '2020-01-20', 'Operador de camión volquete.'),
  ('CD-004', 'Miguel Ángel', 'Flores Castro', '44567890', '+51 984 345 678',
   'miguel.flores@mineraandina.pe', 'Calle Los Pinos 320, Wanchaq, Cusco',
   'UM-ANT', 'activo', '2021-05-17', 'Conductor de transporte de personal.'),
  ('CD-005', 'Percy', 'Apaza Condori', '45678901', '+51 983 456 789',
   'percy.apaza@mineraandina.pe', 'Av. Simón Bolívar 210, Moquegua',
   'UM-QVE', 'activo', '2019-11-05', 'Operador de volquete en zona de carguío.'),
  ('CD-006', 'Ronald', 'Sánchez Vílchez', '46789012', '+51 982 567 890',
   'ronald.sanchez@mineraandina.pe', 'Calle Grau 178, Arequipa',
   'UM-CVE', 'activo', '2022-02-14', 'Operador de maquinaria pesada.'),
  ('CD-007', 'Segundo', 'Ccahuana Torres', '47890123', '+51 981 678 901',
   'segundo.ccahuana@mineraandina.pe', 'Av. Huayna Cápac 540, Cusco',
   'UM-ANT', 'activo', '2017-09-30', 'Licencia vencida; pendiente de renovación.'),
  ('CD-008', 'Wilmer', 'Rojas Paredes', '48901234', '+51 980 789 012',
   'wilmer.rojas@mineraandina.pe', 'Jr. San Martín 233, Huancayo',
   'UM-LBA', 'inactivo', '2016-04-08', 'Cesado temporalmente por reestructuración.')
) AS v(codigo, nombres, apellidos, dni, telefono, correo, direccion, unidad,
       estado, incorporacion, obs)
JOIN unidades_mineras um ON um.codigo = v.unidad
ON CONFLICT DO NOTHING;

INSERT INTO licencias (conductor_id, categoria_id, numero, fecha_emision, fecha_vencimiento)
SELECT c.id, cl.id, v.numero,
       CURRENT_DATE + v.emision::int, CURRENT_DATE + v.vencimiento::int
FROM (VALUES
  ('CD-001', 'A-IIIb', 'Q41234567',  -900,  900),
  ('CD-002', 'A-IIIb', 'Q42345678', -1200,  700),
  ('CD-003', 'A-IIIb', 'Q43456789',  -800, 1000),
  ('CD-004', 'A-IIb',  'Q44567890',  -600, 1200),
  ('CD-005', 'A-IIIb', 'Q45678901', -1400,    6),
  ('CD-006', 'A-IIIc', 'Q46789012', -1000,  800),
  ('CD-007', 'A-IIb',  'Q47890123', -1800, -120),
  ('CD-008', 'A-IIIb', 'Q48901234', -2000, -400)
) AS v(conductor, categoria, numero, emision, vencimiento)
JOIN conductores c ON c.codigo = v.conductor
JOIN categorias_licencia cl ON cl.codigo = v.categoria
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 7. Vehículos
-- ---------------------------------------------------------------------
INSERT INTO vehiculos (codigo_interno, placa, modelo_id, tipo_id, categoria_id,
                       anio_fabricacion, numero_serie, vin, numero_motor, kilometraje,
                       capacidad, tipo_combustible, fecha_adquisicion, propietario_id,
                       proveedor_id, estado_id, unidad_minera_id, observaciones)
SELECT v.codigo, v.placa, mo.id, tv.id, cv.id, v.anio::smallint, v.serie, v.vin,
       v.motor, v.km::numeric, v.capacidad, v.comb::tipo_combustible,
       v.adquisicion::date, p.id, pr.id, ev.id, um.id, v.obs
FROM (VALUES
  ('VEH-001', 'V1A-234', 'Toyota', 'Hilux 2.8 4x4', 'Camioneta', 'Vehículo liviano',
   2023, 'HILUX-2023-001', 'MR0HA3CD5P0123456', '2GD-8845123', '45230.5',
   '5 pasajeros', 'diesel', '2023-03-15', '20512345678', '20100345678',
   'Operativo', 'UM-ANT', 'Asignada a supervisión de operaciones.'),
  ('VEH-002', 'V1B-567', 'Toyota', 'Land Cruiser Prado 2.8', 'Camioneta', 'Vehículo liviano',
   2022, 'PRADO-2022-002', 'JTEBH9FJ7N0123456', '1GD-5532100', '78900.0',
   '7 pasajeros', 'diesel', '2022-07-20', '20512345678', '20100345678',
   'Operativo', 'UM-ANT', 'Vehículo de gerencia de operaciones.'),
  ('VEH-003', 'V2C-890', 'Volvo', 'FH 460', 'Camión', 'Vehículo pesado',
   2021, 'FH460-2021-003', 'YV2RT40A8MB123456', 'D13K-460-778812', '312450.0',
   '30 toneladas', 'diesel', '2021-05-10', '20556677889', '20100123456',
   'Operativo', 'UM-LBA', 'Unidad tractocamión para transporte de concentrado.'),
  ('VEH-004', 'V3D-123', 'Scania', 'R 450', 'Camión', 'Vehículo pesado',
   2020, 'R450-2020-004', 'YS2R4X20002123456', 'DC13-450-112233', '428900.5',
   '32 toneladas', 'diesel', '2020-11-02', '20556677889', '20100234567',
   'En mantenimiento', 'UM-LBA', 'En taller por cambio de embrague.'),
  ('VEH-005', 'V4E-456', 'Volvo', 'FMX 440', 'Volquete', 'Vehículo pesado',
   2022, 'FMX440-2022-005', 'YV2FMB0C6NA123456', 'D13K-440-998877', '187300.0',
   '25 m³', 'diesel', '2022-02-18', '20512345678', '20100123456',
   'Operativo', 'UM-QVE', 'Volquete de 25 m³ para acarreo interno.'),
  ('VEH-006', 'MAQ-006', 'Caterpillar', '320D', 'Excavadora', 'Maquinaria pesada',
   2019, 'CAT320-2019-006', 'CAT0320DALN123456', 'C6.4-4421133', '12450.0',
   '1.2 m³', 'diesel', '2019-08-05', '20512345678', '20100678901',
   'Operativo', 'UM-QVE', 'Excavadora hidráulica de 20 toneladas.'),
  ('VEH-007', 'MAQ-007', 'Komatsu', 'WA380', 'Cargador frontal', 'Maquinaria pesada',
   2020, 'WA380-2020-007', 'KMTWA380CLM123456', 'SAA6D114E-556677', '9870.0',
   '3.5 m³', 'diesel', '2020-01-22', '20512345678', '20100789012',
   'Operativo', 'UM-CVE', 'Cargador frontal para patio de mineral.'),
  ('VEH-008', 'V5F-789', 'Hino', '500 Series', 'Camión', 'Vehículo pesado',
   2021, 'HINO500-2021-008', 'JHDFC4JLXMX123456', 'J08E-UV-334455', '245600.0',
   '16 toneladas', 'diesel', '2021-09-14', '20445566778', '20100567890',
   'Operativo', 'UM-CVE', 'Camión de carga general de 16 toneladas.'),
  ('VEH-009', 'V6G-012', 'Mercedes-Benz', 'Actros 2645', 'Camión cisterna', 'Unidad cisterna',
   2023, 'ACTROS-2023-009', 'WDB9634031L123456', 'OM471-998877', '92300.0',
   '20 000 litros', 'diesel', '2023-04-03', '20556677889', '20100456789',
   'Operativo', 'UM-LBA', 'Cisterna de combustible para equipos en mina.'),
  ('VEH-010', 'V7H-345', 'Toyota', 'Hiace', 'Minibús', 'Transporte de personal',
   2022, 'HIACE-2022-010', 'JTFSK22P8N0123456', '1GD-7711223', '134500.0',
   '15 pasajeros', 'diesel', '2022-06-12', '20512345678', '20100345678',
   'Operativo', 'UM-ANT', 'Transporte de personal entre campamento y mina.'),
  ('VEH-011', 'V8I-678', 'Isuzu', 'NPR', 'Camión', 'Vehículo pesado',
   2020, 'NPR-2020-011', 'JAANPR75LJ1234567', '4HK1-556677', '198700.0',
   '5 toneladas', 'diesel', '2020-10-27', '20445566778', '20100567890',
   'Operativo', 'UM-QVE', 'Camión de abastecimiento de almacén.'),
  ('VEH-012', 'V9J-901', 'Ford', 'Ranger', 'Camioneta', 'Vehículo liviano',
   2023, 'RANGER-2023-012', 'MNBUMFF50P0123456', 'P4AT-2233445', '32100.0',
   '5 pasajeros', 'diesel', '2023-01-16', '20512345678', '20100456789',
   'Fuera de servicio', 'UM-CVE', 'Unidad siniestrada; en evaluación de reparación.')
) AS v(codigo, placa, marca, modelo, tipo, categoria, anio, serie, vin, motor, km,
       capacidad, comb, adquisicion, prop_doc, prov_ruc, estado, unidad, obs)
JOIN marcas ma ON ma.nombre = v.marca
JOIN modelos mo ON mo.marca_id = ma.id AND mo.nombre = v.modelo
JOIN tipos_vehiculo tv ON tv.nombre = v.tipo
JOIN categorias_vehiculo cv ON cv.nombre = v.categoria
JOIN propietarios p ON p.documento = v.prop_doc
LEFT JOIN proveedores pr ON pr.ruc = v.prov_ruc
JOIN estados_vehiculo ev ON ev.nombre = v.estado
JOIN unidades_mineras um ON um.codigo = v.unidad
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 8. Contratos de alquiler y asignaciones
-- ---------------------------------------------------------------------
INSERT INTO contratos_alquiler (numero, proveedor_id, fecha_inicio, fecha_fin, tarifa,
                                condiciones, estado)
SELECT v.numero, p.id, CURRENT_DATE + v.inicio::int, CURRENT_DATE + v.fin::int,
       v.tarifa::numeric, v.condiciones, v.estado::estado_alquiler
FROM (VALUES
  ('CTR-2026-001', '20556677889',  -120,  245, '4800.00',
   'Arrendamiento financiero de 3 tractocamiones Volvo FH 460. Unidad: USD/mes.',
   'vigente'),
  ('CTR-2026-002', '20445566778',  -200,  160, '3200.00',
   'Alquiler de 2 camiones Hino 500 para transporte de carga general.',
   'vigente')
) AS v(numero, prov_ruc, inicio, fin, tarifa, condiciones, estado)
JOIN proveedores p ON p.ruc = v.prov_ruc
ON CONFLICT (numero) DO NOTHING;

INSERT INTO asignaciones (vehiculo_id, conductor_id, responsable_id, area_id,
                          unidad_minera_id, proyecto_id, tipo, fecha_inicio,
                          estado, observaciones)
SELECT veh.id, cond.id, u.id, a.id, um.id, pr.id, v.tipo::tipo_asignacion,
       (CURRENT_DATE + v.inicio::int)::timestamp + TIME '07:00',
       v.estado::estado_asignacion, v.obs
FROM (VALUES
  ('VEH-001', 'CD-001', 'UM-ANT', 'Operaciones Mina', 'PRY-2026-01',
   'operativa', -20, 'activa', 'Asignación vigente, turno día.'),
  ('VEH-003', 'CD-002', 'UM-LBA', 'Transporte', 'PRY-2026-03',
   'operativa', -10, 'activa', 'Transporte de concentrado a planta.'),
  ('VEH-010', 'CD-004', 'UM-ANT', 'Operaciones Mina', 'PRY-2026-01',
   'temporal', -5, 'activa', 'Traslado de personal al tajo.')
) AS v(cod_veh, cod_cond, unidad, area, proyecto, tipo, inicio, estado, obs)
JOIN vehiculos veh ON veh.codigo_interno = v.cod_veh
JOIN conductores cond ON cond.codigo = v.cod_cond
JOIN unidades_mineras um ON um.codigo = v.unidad
JOIN areas a ON a.unidad_minera_id = um.id AND a.nombre = v.area
JOIN proyectos pr ON pr.codigo = v.proyecto
JOIN (SELECT id FROM usuarios WHERE activo ORDER BY id LIMIT 1) u ON TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM asignaciones x
  WHERE x.estado IN ('programada', 'activa')
    AND (x.vehiculo_id = veh.id OR x.conductor_id = cond.id)
);

-- ---------------------------------------------------------------------
-- 9. Mantenimientos
-- ---------------------------------------------------------------------
INSERT INTO mantenimientos (vehiculo_id, tipo_id, fecha, kilometraje, descripcion,
                            diagnostico, trabajo_realizado, taller_id, costo,
                            proximo_fecha, proximo_km, estado)
SELECT veh.id, tm.id, CURRENT_DATE + v.fecha::int, v.km::numeric, v.descripcion,
       v.diagnostico, v.trabajo, t.id, v.costo::numeric,
       CASE WHEN v.prox_fecha IS NULL THEN NULL
            ELSE CURRENT_DATE + v.prox_fecha::int END,
       CASE WHEN v.prox_km IS NULL THEN NULL ELSE v.prox_km::numeric END,
       v.estado::estado_mantenimiento
FROM (VALUES
  ('VEH-001', 'Preventivo', -45, '44200.0',
   'Mantenimiento preventivo de 45 000 km.', 'Sin hallazgos.',
   'Cambio de aceite, filtros y revisión general.', 'Toyota Servicio Técnico - Surquillo',
   1250.50, 45, '50000.0', 'completado'),
  ('VEH-003', 'Preventivo', -90, '305000.0',
   'Servicio preventivo de 300 000 km.', 'Desgaste normal.',
   'Cambio de aceite, filtros y lubricación de chasis.', 'Taller Autorizado Volvo - Ate',
   980.00, 30, '315000.0', 'completado'),
  ('VEH-004', 'Correctivo', -3, '429100.0',
   'Pérdida de potencia y olor a quemado.', 'Embrague desgastado.',
   'Desmontaje de caja y cambio de kit de embrague.', 'Scania Service Center - Callao',
   0.00, NULL, NULL, 'en_proceso'),
  ('VEH-005', 'Correctivo', -15, '185000.0',
   'Fuga en cilindro hidráulico de tolva.', 'Sello hidráulico dañado.',
   'Cambio de sellos y prueba de presión.', 'Maquinarias Perú - La Joya',
   3400.00, 15, NULL, 'completado'),
  ('VEH-006', 'Preventivo', -7, '12300.0',
   'Mantenimiento de 500 horas.', 'Sin hallazgos.',
   'Cambio de aceite hidráulico y filtros.', 'Maquinarias Perú - La Joya',
   2750.00, 83, '13000.0', 'programado'),
  ('VEH-007', 'Predictivo', 5, '10000.0',
   'Análisis de aceite programado.', NULL, NULL, 'Komatsu Service - Quellaveco',
   450.00, 5, '10200.0', 'programado'),
  ('VEH-008', 'Correctivo', -120, '240000.0',
   'Sobrecalentamiento del motor.', 'Bomba de agua defectuosa.',
   'Cambio de bomba de agua y refrigerante.', 'Automotriz Andina - Ate',
   1800.00, NULL, NULL, 'completado'),
  ('VEH-009', 'Preventivo', 12, '95000.0',
   'Servicio de 100 000 km.', NULL, NULL, 'Derco Servicio Automotriz - La Molina',
   1500.00, 12, '100000.0', 'programado'),
  ('VEH-010', 'Preventivo', -30, '130000.0',
   'Mantenimiento preventivo.', 'Sin hallazgos.',
   'Cambio de aceite y filtros.', 'Toyota Servicio Técnico - Surquillo',
   620.00, 60, '140000.0', 'completado'),
  ('VEH-012', 'Correctivo', -2, '32100.0',
   'Evaluación de daños por siniestro.', 'Por determinar.',
   'Inspección estructural y presupuesto de reparación.',
   'Servicio Integral Diésel Andino', 0.00, NULL, NULL, 'en_proceso')
) AS v(cod_veh, tipo, fecha, km, descripcion, diagnostico, trabajo, taller,
       costo, prox_fecha, prox_km, estado)
JOIN vehiculos veh ON veh.codigo_interno = v.cod_veh
JOIN tipos_mantenimiento tm ON tm.nombre = v.tipo
JOIN talleres t ON t.nombre = v.taller
WHERE NOT EXISTS (
  SELECT 1 FROM mantenimientos m
  WHERE m.vehiculo_id = veh.id AND m.fecha = CURRENT_DATE + v.fecha::int
);

-- ---------------------------------------------------------------------
-- 10. Documentos (vehículos y conductores)
-- ---------------------------------------------------------------------
INSERT INTO documentos (tipo_id, vehiculo_id, numero, fecha_emision,
                        fecha_vencimiento, dias_alerta, observaciones)
SELECT td.id, veh.id, v.numero, CURRENT_DATE + v.emision::int,
       CURRENT_DATE + v.vencimiento::int, v.alerta, v.obs
FROM (VALUES
  ('VEH-001', 'SOAT', 'SOAT-2026-001', -300, 25, 30, 'SOAT vigente por vencer.'),
  ('VEH-001', 'Revisión técnica', 'RT-2026-001', -330, 12, 30, 'Revisión técnica por vencer.'),
  ('VEH-002', 'SOAT', 'SOAT-2026-002', -200, 160, 30, NULL),
  ('VEH-002', 'Póliza', 'POL-2026-002', -200, 165, 30, 'Póliza todo riesgo.'),
  ('VEH-003', 'SOAT', 'SOAT-2026-003', -370, -5, 30, 'SOAT vencido; regularizar.'),
  ('VEH-003', 'Póliza', 'POL-2026-003', -200, 90, 30, NULL),
  ('VEH-004', 'Tarjeta de propiedad', 'TP-2020-004', -1800, 3000, 60, NULL),
  ('VEH-005', 'SOAT', 'SOAT-2026-005', -100, 150, 30, NULL),
  ('VEH-006', 'Póliza', 'POL-2026-006', -320, 45, 30, 'Póliza de maquinaria pesada.'),
  ('VEH-007', 'SOAT', 'SOAT-2026-007', -340, 30, 30, NULL),
  ('VEH-008', 'SOAT', 'SOAT-2026-008', -380, -20, 30, 'SOAT vencido; unidad observada.'),
  ('VEH-009', 'SOAT', 'SOAT-2026-009', -50, 320, 30, NULL),
  ('VEH-010', 'SOAT', 'SOAT-2026-010', -290, 60, 30, NULL),
  ('VEH-011', 'SOAT', 'SOAT-2026-011', -360, 5, 30, 'SOAT por vencer en 5 días.'),
  ('VEH-012', 'SOAT', 'SOAT-2026-012', -420, -60, 30, 'SOAT vencido; unidad fuera de servicio.')
) AS v(cod_veh, tipo, numero, emision, vencimiento, alerta, obs)
JOIN vehiculos veh ON veh.codigo_interno = v.cod_veh
JOIN tipos_documento td ON td.nombre = v.tipo
WHERE NOT EXISTS (
  SELECT 1 FROM documentos d
  WHERE d.tipo_id = td.id AND d.vehiculo_id = veh.id AND d.numero = v.numero
);

INSERT INTO documentos (tipo_id, conductor_id, numero, fecha_emision,
                        fecha_vencimiento, dias_alerta, observaciones)
SELECT td.id, c.id, v.numero, CURRENT_DATE + v.emision::int,
       CURRENT_DATE + v.vencimiento::int, v.alerta, v.obs
FROM (VALUES
  ('CD-001', 'Q41234567',  -900,  900, 45, NULL),
  ('CD-005', 'Q45678901', -1400,    6, 45, 'Licencia por vencer en 6 días.'),
  ('CD-007', 'Q47890123', -1800, -120, 45, 'Licencia vencida; no puede operar.')
) AS v(conductor, numero, emision, vencimiento, alerta, obs)
JOIN conductores c ON c.codigo = v.conductor
JOIN tipos_documento td ON td.nombre = 'Licencia de conducir'
WHERE NOT EXISTS (
  SELECT 1 FROM documentos d
  WHERE d.tipo_id = td.id AND d.conductor_id = c.id AND d.numero = v.numero
);

-- ---------------------------------------------------------------------
-- 11. Inspecciones y sus detalles
-- ---------------------------------------------------------------------
INSERT INTO inspecciones (vehiculo_id, conductor_id, fecha_hora, resultado,
                          bloquea_vehiculo, observaciones)
SELECT veh.id, cond.id,
       (CURRENT_DATE + v.dias::int)::timestamp + v.hora::time,
       v.resultado::resultado_inspeccion, v.bloquea, v.obs
FROM (VALUES
  ('VEH-001', 'CD-001', -10, '08:30', 'conforme', FALSE,
   'Inspección preoperacional sin observaciones.'),
  ('VEH-003', 'CD-002', -6, '09:15', 'conforme_con_observaciones', FALSE,
   'Se observó desgaste en neumático delantero derecho.'),
  ('VEH-008', 'CD-003', -4, '07:45', 'no_conforme', TRUE,
   'Fuga de refrigerante; vehículo bloqueado hasta reparación.'),
  ('VEH-010', 'CD-004', -8, '06:30', 'conforme', FALSE,
   'Unidad apta para transporte de personal.')
) AS v(cod_veh, cod_cond, dias, hora, resultado, bloquea, obs)
JOIN vehiculos veh ON veh.codigo_interno = v.cod_veh
JOIN conductores cond ON cond.codigo = v.cod_cond
WHERE NOT EXISTS (
  SELECT 1 FROM inspecciones i
  WHERE i.vehiculo_id = veh.id
    AND i.fecha_hora = (CURRENT_DATE + v.dias::int)::timestamp + v.hora::time
);

INSERT INTO inspeccion_detalles (inspeccion_id, componente_id, resultado, observacion)
SELECT i.id, ci.id, v.resultado::resultado_componente, v.obs
FROM (VALUES
  ('VEH-001', -10, '08:30', 'Frenos', 'conforme', NULL),
  ('VEH-001', -10, '08:30', 'Neumáticos', 'conforme', NULL),
  ('VEH-001', -10, '08:30', 'Luces', 'conforme', NULL),
  ('VEH-001', -10, '08:30', 'Dirección', 'conforme', NULL),
  ('VEH-001', -10, '08:30', 'Cinturones', 'conforme', NULL),
  ('VEH-003', -6, '09:15', 'Frenos', 'conforme', NULL),
  ('VEH-003', -6, '09:15', 'Neumáticos', 'observado',
   'Desgaste irregular en neumático delantero derecho.'),
  ('VEH-003', -6, '09:15', 'Luces', 'conforme', NULL),
  ('VEH-003', -6, '09:15', 'Dirección', 'conforme', NULL),
  ('VEH-003', -6, '09:15', 'Cinturones', 'conforme', NULL),
  ('VEH-008', -4, '07:45', 'Frenos', 'conforme', NULL),
  ('VEH-008', -4, '07:45', 'Neumáticos', 'conforme', NULL),
  ('VEH-008', -4, '07:45', 'Luces', 'conforme', NULL),
  ('VEH-008', -4, '07:45', 'Dirección', 'conforme', NULL),
  ('VEH-008', -4, '07:45', 'Niveles de fluidos', 'no_conforme',
   'Fuga de refrigerante en manguera superior.'),
  ('VEH-008', -4, '07:45', 'Estado del motor', 'observado',
   'Temperatura elevada durante la prueba.'),
  ('VEH-008', -4, '07:45', 'Extintor', 'conforme', NULL),
  ('VEH-010', -8, '06:30', 'Frenos', 'conforme', NULL),
  ('VEH-010', -8, '06:30', 'Neumáticos', 'conforme', NULL),
  ('VEH-010', -8, '06:30', 'Luces', 'conforme', NULL),
  ('VEH-010', -8, '06:30', 'Dirección', 'conforme', NULL),
  ('VEH-010', -8, '06:30', 'Cinturones', 'conforme', NULL),
  ('VEH-010', -8, '06:30', 'Extintor', 'conforme', NULL)
) AS v(cod_veh, dias, hora, componente, resultado, obs)
JOIN vehiculos veh ON veh.codigo_interno = v.cod_veh
JOIN inspecciones i ON i.vehiculo_id = veh.id
   AND i.fecha_hora = (CURRENT_DATE + v.dias::int)::timestamp + v.hora::time
JOIN componentes_inspeccion ci ON ci.nombre = v.componente
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 12. Abastecimientos de combustible
-- ---------------------------------------------------------------------
INSERT INTO abastecimientos (vehiculo_id, fecha, tipo_combustible, litros,
                             precio_litro, kilometraje, proveedor_id, observaciones)
SELECT veh.id, (CURRENT_DATE + v.dias::int)::timestamp + v.hora::time,
       v.comb::tipo_combustible, v.litros::numeric, v.precio::numeric,
       v.km::numeric, pc.id, v.obs
FROM (VALUES
  ('VEH-001', -2, '07:45', 'diesel', '45.50', '15.890', '45120.0', 'Primax Perú S.A.', NULL),
  ('VEH-003', -1, '18:20', 'diesel', '180.00', '15.750', '312300.0', 'Repsol Perú S.A.C.', NULL),
  ('VEH-005', -5, '09:10', 'diesel', '160.00', '15.800', '187100.0', 'Petroperú S.A.', NULL),
  ('VEH-006', -6, '11:30', 'diesel', '200.00', '15.700', '12440.0', 'Petroperú S.A.',
   'Abastecimiento con cisterna interna en mina.'),
  ('VEH-008', -3, '16:05', 'diesel', '120.00', '15.720', '245500.0', 'Pecsa (Coesti S.A.)', NULL),
  ('VEH-010', -7, '06:50', 'diesel', '60.00', '15.900', '134400.0', 'Primax Perú S.A.', NULL),
  ('VEH-011', -4, '13:15', 'diesel', '80.00', '15.810', '198600.0', 'Repsol Perú S.A.C.', NULL),
  ('VEH-012', -12, '10:00', 'diesel', '50.00', '15.850', '32050.0', 'Primax Perú S.A.',
   'Último abastecimiento antes del siniestro.')
) AS v(cod_veh, dias, hora, comb, litros, precio, km, prov, obs)
JOIN vehiculos veh ON veh.codigo_interno = v.cod_veh
JOIN proveedores_combustible pc ON pc.nombre = v.prov
WHERE NOT EXISTS (
  SELECT 1 FROM abastecimientos a
  WHERE a.vehiculo_id = veh.id
    AND a.fecha = (CURRENT_DATE + v.dias::int)::timestamp + v.hora::time
);

-- ---------------------------------------------------------------------
-- 13. Incidentes y acciones correctivas
--    (requiere al menos un usuario activo; si no existe, se omiten)
-- ---------------------------------------------------------------------
INSERT INTO incidentes (codigo, vehiculo_id, conductor_id, fecha_hora, ubicacion,
                        tipo_id, gravedad_id, descripcion, danos, medidas_adoptadas,
                        reportado_por, estado_investigacion)
SELECT v.codigo, veh.id, cond.id,
       (CURRENT_DATE + v.dias::int)::timestamp + v.hora::time,
       v.ubicacion, ti.id, v.gravedad::smallint,
       v.descripcion, v.danos, v.medidas, u.id,
       v.estado::estado_investigacion
FROM (VALUES
  ('INC-2026-001', 'VEH-012', 'CD-006', -2, '14:35',
   'Ruta de acceso a tajo, Unidad Minera Cerro Verde', 'Daño material', 2,
   'Desprendimiento de roca impactó la tolva durante el carguío.',
   'Abolladura en tolva y faro posterior derecho.',
   'Señalización del área y revisión estructural de la unidad.', 'en_investigacion'),
  ('INC-2026-002', 'VEH-004', 'CD-002', -20, '22:10',
   'Carretera Lima–Huancayo, km 84', 'Avería', 1,
   'El vehículo perdió potencia y se detuvo en la berma.',
   'Sin daños materiales.', 'Remolque a taller autorizado.', 'cerrado'),
  ('INC-2026-003', 'VEH-008', 'CD-003', -35, '08:50',
   'Patio de maniobras, Unidad Minera Cerro Verde', 'Incidente', 1,
   'Derrame menor de refrigerante durante la maniobra de estacionamiento.',
   'Mancha en el pavimento.', 'Limpieza y contención con material absorbente.', 'cerrado'),
  ('INC-2026-004', 'VEH-005', 'CD-005', -10, '16:20',
   'Zona de carguío, Unidad Minera Quellaveco', 'Accidente', 3,
   'Contacto lateral con berma de seguridad al maniobrar en retroceso.',
   'Daño en estribo y guardafango derecho.',
   'Retiro de la unidad, evaluación médica y reporte a seguridad.', 'en_investigacion')
) AS v(codigo, cod_veh, cod_cond, dias, hora, ubicacion, tipo, gravedad,
       descripcion, danos, medidas, estado)
JOIN vehiculos veh ON veh.codigo_interno = v.cod_veh
LEFT JOIN conductores cond ON cond.codigo = v.cod_cond
JOIN tipos_incidente ti ON ti.nombre = v.tipo
JOIN (SELECT id FROM usuarios WHERE activo ORDER BY id LIMIT 1) u ON TRUE
ON CONFLICT DO NOTHING;

INSERT INTO acciones_correctivas (incidente_id, descripcion, fecha_compromiso, estado)
SELECT i.id, v.descripcion, CURRENT_DATE + v.dias::int, v.estado::estado_accion
FROM (VALUES
  ('INC-2026-001', 'Reforzar el procedimiento de carguío en taludes y señalizar la zona.', 10, 'en_curso'),
  ('INC-2026-002', 'Actualizar el plan de mantenimiento preventivo del sistema de inyección.', 15, 'cumplida'),
  ('INC-2026-003', 'Reemplazar mangueras de refrigerante y verificar abrazaderas.', -5, 'cumplida'),
  ('INC-2026-004', 'Capacitar en maniobras en retroceso y señalización de zona de carguío.', 20, 'pendiente')
) AS v(codigo, descripcion, dias, estado)
JOIN incidentes i ON i.codigo = v.codigo
WHERE NOT EXISTS (
  SELECT 1 FROM acciones_correctivas a
  WHERE a.incidente_id = i.id AND a.descripcion = v.descripcion
);
