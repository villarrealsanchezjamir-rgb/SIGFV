require('dotenv').config();
const express = require('express'), bcrypt = require('bcryptjs'), jwt = require('jsonwebtoken'), path = require('path'), pool = require('./db');
const { version } = require('./package.json');
const SECRET = process.env.JWT_SECRET;
if (!SECRET || SECRET.length < 32) { console.error('Defina JWT_SECRET (32+ caracteres) en el archivo .env'); process.exit(1); }

const q = async (s, p = []) => (await pool.query(s, p)).rows;
const bad = (m, c = 400) => Object.assign(new Error(m), { http: c });
const wrap = f => (req, res, next) => f(req, res, next).catch(next);

// Cliente Supabase (se usa para comprobar el proyecto y para futuras funciones de Storage).
let supabase = null;
if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY) {
  try {
    supabase = require('@supabase/supabase-js').createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY,
      { auth: { persistSession: false, autoRefreshToken: false } }
    );
  } catch (e) { console.error('No se pudo inicializar el cliente Supabase:', e.message); }
}

/* ---------- Definición de módulos (una sola fuente para API y pantallas) ---------- */
const F = (n, l, t = 'text', o = {}) => ({ n, l, t, ...o });
const ENUM = (...a) => a.map(x => [x, x.replace(/_/g, ' ')]);
const COMB = ENUM('diesel', 'gasolina', 'glp', 'gnv', 'electrico', 'otro');
const RES = {
  vehiculos: { mod: 'vehiculos', label: 'Vehículos', group: 'Operación', icon: 'truck', t: 'vehiculos', soft: 'eliminado_en',
    sel: "a.id,a.codigo_interno codigo,a.placa,(ma.nombre || ' ' || mo.nombre) modelo,tv.nombre tipo,a.kilometraje km,um.nombre unidad,ev.nombre estado,ev.color",
    from: 'FROM vehiculos a JOIN modelos mo ON mo.id=a.modelo_id JOIN marcas ma ON ma.id=mo.marca_id JOIN tipos_vehiculo tv ON tv.id=a.tipo_id JOIN estados_vehiculo ev ON ev.id=a.estado_id JOIN unidades_mineras um ON um.id=a.unidad_minera_id',
    search: ['a.codigo_interno', 'a.placa', 'a.vin', 'a.numero_serie'],
    cols: [['codigo', 'Código'], ['placa', 'Placa'], ['tipo', 'Tipo'], ['modelo', 'Marca / modelo'], ['km', 'Km'], ['unidad', 'Unidad minera'], ['estado', 'Estado', 'badge']],
    fields: [F('codigo_interno', 'Código interno', 'text', { req: 1 }), F('placa', 'Placa'), F('modelo_id', 'Marca y modelo', 'select', { cat: 'modelos', req: 1 }), F('tipo_id', 'Tipo de vehículo', 'select', { cat: 'tipos_vehiculo', req: 1 }),
      F('categoria_id', 'Categoría', 'select', { cat: 'categorias_vehiculo' }), F('anio_fabricacion', 'Año de fabricación', 'number'), F('numero_serie', 'Número de serie'), F('vin', 'VIN'), F('numero_motor', 'Número de motor'),
      F('kilometraje', 'Kilometraje', 'number'), F('capacidad', 'Capacidad'), F('tipo_combustible', 'Combustible', 'select', { o: COMB }), F('fecha_adquisicion', 'Fecha de adquisición', 'date'),
      F('propietario_id', 'Propietario', 'select', { cat: 'propietarios', req: 1 }), F('estado_id', 'Estado operativo', 'select', { cat: 'estados_vehiculo', req: 1 }),
      F('unidad_minera_id', 'Unidad minera', 'select', { cat: 'unidades_mineras', req: 1 }), F('observaciones', 'Observaciones', 'textarea')],
    after: async (id, b, req, c, nuevo, o, old) => { if (o.estado_id && (nuevo || +old.estado_id !== +o.estado_id))
      await c.query('INSERT INTO historial_estados_vehiculo (vehiculo_id,estado_anterior_id,estado_nuevo_id,usuario_id,motivo) VALUES ($1,$2,$3,$4,$5)', [id, nuevo ? null : old.estado_id, o.estado_id, req.user.id, nuevo ? 'Alta del vehículo' : 'Cambio de estado']); } },
  conductores: { mod: 'conductores', label: 'Conductores', group: 'Operación', icon: 'id-card', t: 'conductores', soft: 'eliminado_en',
    sel: "a.id,a.codigo,(a.nombres || ' ' || a.apellidos) nombre,a.documento_identidad dni,a.telefono,a.estado,(SELECT MAX(fecha_vencimiento) FROM licencias l WHERE l.conductor_id=a.id) licencia_vence",
    from: 'FROM conductores a', search: ['a.codigo', 'a.nombres', 'a.apellidos', 'a.documento_identidad'],
    cols: [['codigo', 'Código'], ['nombre', 'Nombre'], ['dni', 'Documento'], ['telefono', 'Teléfono'], ['licencia_vence', 'Licencia vence'], ['estado', 'Estado', 'badge']],
    fields: [F('codigo', 'Código de conductor', 'text', { req: 1 }), F('nombres', 'Nombres', 'text', { req: 1 }), F('apellidos', 'Apellidos', 'text', { req: 1 }), F('documento_identidad', 'Documento de identidad', 'text', { req: 1 }),
      F('telefono', 'Teléfono'), F('correo', 'Correo'), F('direccion', 'Dirección'), F('unidad_minera_id', 'Unidad minera', 'select', { cat: 'unidades_mineras' }), F('estado', 'Estado', 'select', { o: ENUM('activo', 'inactivo', 'inhabilitado') }),
      F('fecha_incorporacion', 'Fecha de incorporación', 'date'), F('lic_categoria_id', 'Categoría de licencia', 'select', { cat: 'categorias_licencia', virtual: 1 }), F('lic_numero', 'Número de licencia', 'text', { virtual: 1 }),
      F('lic_emision', 'Emisión de licencia', 'date', { virtual: 1 }), F('lic_vencimiento', 'Vencimiento de licencia', 'date', { virtual: 1 }), F('observaciones', 'Observaciones', 'textarea')],
    one: async r => { const rows = await q('SELECT categoria_id lic_categoria_id,numero lic_numero,fecha_emision lic_emision,fecha_vencimiento lic_vencimiento FROM licencias WHERE conductor_id=$1 ORDER BY id DESC LIMIT 1', [r.id]); Object.assign(r, rows[0] || {}); },
    after: async (id, b, req, c) => { if (!b.lic_numero) return;
      const vals = [b.lic_categoria_id || null, b.lic_numero, b.lic_emision || null, b.lic_vencimiento || null];
      const lr = await c.query('SELECT id FROM licencias WHERE conductor_id=$1 ORDER BY id DESC LIMIT 1', [id]);
      if (lr.rows[0]) await c.query('UPDATE licencias SET categoria_id=$1,numero=$2,fecha_emision=$3,fecha_vencimiento=$4 WHERE id=$5', [...vals, lr.rows[0].id]);
      else await c.query('INSERT INTO licencias (conductor_id,categoria_id,numero,fecha_emision,fecha_vencimiento) VALUES ($1,$2,$3,$4,$5)', [id, ...vals]); } },
  asignaciones: { mod: 'asignaciones', label: 'Asignaciones', group: 'Operación', icon: 'calendar-range', t: 'asignaciones', auto: ['responsable_id'],
    sel: "a.id,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,(c.nombres || ' ' || c.apellidos) conductor,um.nombre unidad,a.tipo,a.fecha_inicio inicio,a.fecha_fin fin,a.estado",
    from: 'FROM asignaciones a JOIN vehiculos v ON v.id=a.vehiculo_id LEFT JOIN conductores c ON c.id=a.conductor_id JOIN unidades_mineras um ON um.id=a.unidad_minera_id',
    search: ['v.codigo_interno', 'v.placa', 'c.apellidos', 'c.nombres'],
    cols: [['vehiculo', 'Vehículo'], ['conductor', 'Conductor'], ['unidad', 'Unidad minera'], ['tipo', 'Tipo'], ['inicio', 'Inicio'], ['fin', 'Fin'], ['estado', 'Estado', 'badge']],
    fields: [F('vehiculo_id', 'Vehículo', 'select', { cat: 'vehiculos', req: 1 }), F('conductor_id', 'Conductor', 'select', { cat: 'conductores' }), F('unidad_minera_id', 'Unidad minera', 'select', { cat: 'unidades_mineras', req: 1 }),
      F('tipo', 'Tipo de asignación', 'select', { o: ENUM('operativa', 'alquiler', 'temporal', 'permanente') }), F('fecha_inicio', 'Inicio', 'datetime', { req: 1 }), F('fecha_fin', 'Fin', 'datetime'),
      F('estado', 'Estado', 'select', { o: ENUM('programada', 'activa', 'finalizada', 'cancelada') }), F('observaciones', 'Observaciones', 'textarea')] },
  mantenimientos: { mod: 'mantenimiento', label: 'Mantenimiento', group: 'Control', icon: 'wrench', t: 'mantenimientos', soft: 'eliminado_en', auto: ['responsable_id'],
    sel: "a.id,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,tm.nombre tipo,a.fecha,a.costo,a.proximo_fecha proximo,a.estado",
    from: 'FROM mantenimientos a JOIN vehiculos v ON v.id=a.vehiculo_id JOIN tipos_mantenimiento tm ON tm.id=a.tipo_id', search: ['v.codigo_interno', 'v.placa', 'a.descripcion'],
    cols: [['vehiculo', 'Vehículo'], ['tipo', 'Tipo'], ['fecha', 'Fecha'], ['costo', 'Costo'], ['proximo', 'Próximo'], ['estado', 'Estado', 'badge']],
    fields: [F('vehiculo_id', 'Vehículo', 'select', { cat: 'vehiculos', req: 1 }), F('tipo_id', 'Tipo', 'select', { cat: 'tipos_mantenimiento', req: 1 }), F('fecha', 'Fecha', 'date', { req: 1 }), F('kilometraje', 'Kilometraje', 'number'),
      F('taller_id', 'Taller', 'select', { cat: 'talleres' }), F('costo', 'Costo', 'number'), F('proximo_fecha', 'Próximo mantenimiento', 'date'), F('proximo_km', 'Próximo (km)', 'number'),
      F('estado', 'Estado', 'select', { o: ENUM('programado', 'en_proceso', 'completado', 'cancelado') }), F('descripcion', 'Descripción', 'textarea'), F('diagnostico', 'Diagnóstico', 'textarea'), F('trabajo_realizado', 'Trabajo realizado', 'textarea')] },
  documentos: { mod: 'documentos', label: 'Documentación', group: 'Control', icon: 'file-text', t: 'documentos', soft: 'eliminado_en',
    sel: "a.id,td.nombre documento,COALESCE(v.codigo_interno,(c.nombres || ' ' || c.apellidos)) titular,a.numero,a.fecha_vencimiento vence,CASE WHEN a.fecha_vencimiento < sigfv_today() THEN 'vencido' WHEN a.fecha_vencimiento <= sigfv_today() + 30 THEN 'por vencer' ELSE 'vigente' END estado",
    from: 'FROM documentos a JOIN tipos_documento td ON td.id=a.tipo_id LEFT JOIN vehiculos v ON v.id=a.vehiculo_id LEFT JOIN conductores c ON c.id=a.conductor_id', search: ['td.nombre', 'a.numero', 'v.codigo_interno', 'c.apellidos'],
    cols: [['documento', 'Documento'], ['titular', 'Vehículo / conductor'], ['numero', 'Número'], ['vence', 'Vence'], ['estado', 'Estado', 'badge']],
    fields: [F('tipo_id', 'Tipo de documento', 'select', { cat: 'tipos_documento', req: 1 }), F('vehiculo_id', 'Vehículo (si aplica)', 'select', { cat: 'vehiculos' }), F('conductor_id', 'Conductor (si aplica)', 'select', { cat: 'conductores' }),
      F('numero', 'Número'), F('fecha_emision', 'Emisión', 'date'), F('fecha_vencimiento', 'Vencimiento', 'date', { req: 1 }), F('observaciones', 'Observaciones')] },
  inspecciones: { mod: 'inspecciones', label: 'Inspecciones', group: 'Control', icon: 'clipboard-check', t: 'inspecciones',
    sel: "a.id,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,(c.nombres || ' ' || c.apellidos) conductor,a.fecha_hora fecha,a.resultado,CASE WHEN a.bloquea_vehiculo THEN 'Sí' ELSE 'No' END bloqueo",
    from: 'FROM inspecciones a JOIN vehiculos v ON v.id=a.vehiculo_id JOIN conductores c ON c.id=a.conductor_id', search: ['v.codigo_interno', 'v.placa', 'c.apellidos'],
    cols: [['vehiculo', 'Vehículo'], ['conductor', 'Conductor'], ['fecha', 'Fecha'], ['resultado', 'Resultado', 'badge'], ['bloqueo', 'Bloqueó vehículo']],
    fields: [F('vehiculo_id', 'Vehículo', 'select', { cat: 'vehiculos', req: 1 }), F('conductor_id', 'Conductor', 'select', { cat: 'conductores', req: 1 }), F('fecha_hora', 'Fecha y hora', 'datetime', { req: 1 }),
      F('resultado', 'Resultado', 'select', { o: ENUM('conforme', 'conforme_con_observaciones', 'no_conforme'), req: 1 }), F('bloquea_vehiculo', 'Bloquear uso del vehículo', 'select', { o: [['0', 'No'], ['1', 'Sí (pasa a fuera de servicio)']] }), F('observaciones', 'Observaciones', 'textarea')],
    after: async (id, b, req, c, nuevo, o) => { if (nuevo && o.resultado === 'no_conforme' && o.bloquea_vehiculo === true) {
      const er = await c.query("SELECT id FROM estados_vehiculo WHERE nombre='Fuera de servicio'");
      const vr = await c.query('SELECT estado_id FROM vehiculos WHERE id=$1', [o.vehiculo_id]);
      await c.query('UPDATE vehiculos SET estado_id=$1 WHERE id=$2', [er.rows[0].id, o.vehiculo_id]);
      await c.query('INSERT INTO historial_estados_vehiculo (vehiculo_id,estado_anterior_id,estado_nuevo_id,usuario_id,motivo) VALUES ($1,$2,$3,$4,$5)', [o.vehiculo_id, vr.rows[0].estado_id, er.rows[0].id, req.user.id, 'Inspección no conforme #' + id]); } } },
  abastecimientos: { mod: 'combustible', label: 'Combustible', group: 'Control', icon: 'fuel', t: 'abastecimientos', auto: ['responsable_id'],
    sel: "a.id,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,a.fecha,a.tipo_combustible tipo,a.litros,a.precio_litro precio,a.importe_total importe",
    from: 'FROM abastecimientos a JOIN vehiculos v ON v.id=a.vehiculo_id', search: ['v.codigo_interno', 'v.placa'],
    cols: [['vehiculo', 'Vehículo'], ['fecha', 'Fecha'], ['tipo', 'Combustible'], ['litros', 'Litros'], ['precio', 'Precio/L'], ['importe', 'Importe']],
    fields: [F('vehiculo_id', 'Vehículo', 'select', { cat: 'vehiculos', req: 1 }), F('fecha', 'Fecha y hora', 'datetime', { req: 1 }), F('tipo_combustible', 'Combustible', 'select', { o: COMB, req: 1 }), F('litros', 'Litros', 'number', { req: 1 }),
      F('precio_litro', 'Precio por litro', 'number', { req: 1 }), F('kilometraje', 'Kilometraje', 'number'), F('proveedor_id', 'Estación / proveedor', 'select', { cat: 'proveedores_combustible' }), F('observaciones', 'Observaciones')] },
  incidentes: { mod: 'incidentes', label: 'Incidentes', group: 'Control', icon: 'triangle-alert', t: 'incidentes', soft: 'eliminado_en', auto: ['reportado_por'],
    sel: "a.id,a.codigo,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,ti.nombre tipo,g.nombre gravedad,a.fecha_hora fecha,a.estado_investigacion estado",
    from: 'FROM incidentes a JOIN vehiculos v ON v.id=a.vehiculo_id JOIN tipos_incidente ti ON ti.id=a.tipo_id JOIN niveles_gravedad g ON g.id=a.gravedad_id', search: ['a.codigo', 'v.codigo_interno', 'v.placa', 'a.descripcion'],
    cols: [['codigo', 'Código'], ['vehiculo', 'Vehículo'], ['tipo', 'Tipo'], ['gravedad', 'Gravedad'], ['fecha', 'Fecha'], ['estado', 'Investigación', 'badge']],
    fields: [F('vehiculo_id', 'Vehículo', 'select', { cat: 'vehiculos', req: 1 }), F('conductor_id', 'Conductor', 'select', { cat: 'conductores' }), F('fecha_hora', 'Fecha y hora', 'datetime', { req: 1 }), F('ubicacion', 'Ubicación'),
      F('tipo_id', 'Tipo', 'select', { cat: 'tipos_incidente', req: 1 }), F('gravedad_id', 'Gravedad', 'select', { cat: 'niveles_gravedad', req: 1 }), F('estado_investigacion', 'Estado de investigación', 'select', { o: ENUM('pendiente', 'en_investigacion', 'cerrado') }),
      F('descripcion', 'Descripción', 'textarea', { req: 1 }), F('danos', 'Daños registrados', 'textarea'), F('medidas_adoptadas', 'Medidas adoptadas', 'textarea')] },
  usuarios: { mod: 'usuarios', label: 'Usuarios', group: 'Sistema', icon: 'shield', t: 'usuarios', soft: 'eliminado_en',
    sel: "a.id,a.nombre_usuario usuario,(a.nombres || ' ' || a.apellidos) nombre,a.correo,(SELECT STRING_AGG(r.nombre, ',') FROM usuario_roles ur JOIN roles r ON r.id=ur.rol_id WHERE ur.usuario_id=a.id) rol,CASE WHEN a.activo THEN 'activo' ELSE 'inactivo' END estado",
    from: 'FROM usuarios a', search: ['a.nombre_usuario', 'a.nombres', 'a.apellidos', 'a.correo'],
    cols: [['usuario', 'Usuario'], ['nombre', 'Nombre'], ['correo', 'Correo'], ['rol', 'Rol'], ['estado', 'Estado', 'badge']],
    fields: [F('nombre_usuario', 'Usuario', 'text', { req: 1 }), F('correo', 'Correo', 'text', { req: 1 }), F('nombres', 'Nombres', 'text', { req: 1 }), F('apellidos', 'Apellidos', 'text', { req: 1 }),
      F('rol_id', 'Rol', 'select', { cat: 'roles', virtual: 1, req: 1 }), F('password', 'Contraseña (mín. 8; en blanco = no cambiar)', 'password', { virtual: 1 }), F('activo', 'Estado', 'select', { o: [['1', 'Activo'], ['0', 'Inactivo']] })],
    one: async r => { delete r.password_hash; const rows = await q('SELECT rol_id FROM usuario_roles WHERE usuario_id=$1 LIMIT 1', [r.id]); r.rol_id = rows[0] && rows[0].rol_id; },
    after: async (id, b, req, c) => { if (b.rol_id) { await c.query('DELETE FROM usuario_roles WHERE usuario_id=$1', [id]); await c.query('INSERT INTO usuario_roles (usuario_id,rol_id) VALUES ($1,$2)', [id, b.rol_id]); } } }
};

const cfg = (t, label, sel, cols, fields, from) => RES[t] = { mod: 'configuracion', label, group: 'Configuración', icon: 'settings', t, soft: 'activo', sel, from: from || `FROM ${t} a`, search: ['a.' + cols[0][0]], cols, fields };
cfg('empresas', 'Empresas', 'a.id,a.ruc,a.razon_social,a.telefono', [['ruc', 'RUC'], ['razon_social', 'Razón social'], ['telefono', 'Teléfono']], [F('ruc', 'RUC', 'text', { req: 1 }), F('razon_social', 'Razón social', 'text', { req: 1 }), F('direccion', 'Dirección'), F('telefono', 'Teléfono'), F('correo', 'Correo')]);
cfg('unidades_mineras', 'Unidades mineras', 'a.id,a.codigo,a.nombre,a.ubicacion', [['codigo', 'Código'], ['nombre', 'Nombre'], ['ubicacion', 'Ubicación']], [F('empresa_id', 'Empresa', 'select', { cat: 'empresas', req: 1 }), F('codigo', 'Código', 'text', { req: 1 }), F('nombre', 'Nombre', 'text', { req: 1 }), F('ubicacion', 'Ubicación')]);
cfg('marcas', 'Marcas', 'a.id,a.nombre', [['nombre', 'Nombre']], [F('nombre', 'Nombre', 'text', { req: 1 })]);
cfg('modelos', 'Modelos', 'a.id,ma.nombre marca,a.nombre', [['marca', 'Marca'], ['nombre', 'Modelo']], [F('marca_id', 'Marca', 'select', { cat: 'marcas', req: 1 }), F('nombre', 'Modelo', 'text', { req: 1 })], 'FROM modelos a JOIN marcas ma ON ma.id=a.marca_id');
cfg('propietarios', 'Propietarios', 'a.id,a.nombre,a.documento', [['nombre', 'Nombre'], ['documento', 'Documento']], [F('nombre', 'Nombre', 'text', { req: 1 }), F('documento', 'Documento')]);
cfg('proveedores_combustible', 'Estaciones de combustible', 'a.id,a.nombre,a.ubicacion', [['nombre', 'Nombre'], ['ubicacion', 'Ubicación']], [F('nombre', 'Nombre', 'text', { req: 1 }), F('ruc', 'RUC'), F('ubicacion', 'Ubicación')]);
cfg('talleres', 'Talleres', 'a.id,a.nombre,a.direccion', [['nombre', 'Nombre'], ['direccion', 'Dirección']], [F('nombre', 'Nombre', 'text', { req: 1 }), F('direccion', 'Dirección')]);
RES.modelos.search = ['a.nombre', 'ma.nombre']; RES.empresas.search = ['a.razon_social', 'a.ruc'];

const c = (t, e = 'nombre', w = 'activo=TRUE') => `SELECT id,${e} nombre FROM ${t} WHERE ${w} ORDER BY 2`;
const CAT = { modelos: "SELECT m.id,(ma.nombre || ' ' || m.nombre) nombre FROM modelos m JOIN marcas ma ON ma.id=m.marca_id WHERE m.activo=TRUE ORDER BY 2",
  tipos_vehiculo: c('tipos_vehiculo'), categorias_vehiculo: c('categorias_vehiculo'), estados_vehiculo: c('estados_vehiculo', 'nombre', '1=1'), propietarios: c('propietarios'), unidades_mineras: c('unidades_mineras'),
  empresas: c('empresas', 'razon_social'), marcas: c('marcas'), talleres: c('talleres'), tipos_mantenimiento: c('tipos_mantenimiento'), tipos_documento: c('tipos_documento'), proveedores_combustible: c('proveedores_combustible'),
  tipos_incidente: c('tipos_incidente'), niveles_gravedad: c('niveles_gravedad', 'nombre', '1=1'), categorias_licencia: c('categorias_licencia', 'codigo', '1=1'), roles: c('roles'),
  conductores: c('conductores', "(nombres || ' ' || apellidos)", 'eliminado_en IS NULL'), vehiculos: c('vehiculos', "(codigo_interno || ' ' || COALESCE(placa,''))", 'eliminado_en IS NULL') };

/* ---------- Seguridad ---------- */
const app = express();
app.set('trust proxy', 1);
app.disable('x-powered-by'); app.use(express.json({ limit: '200kb' }));
// CORS para la app móvil (APK) y clientes externos. La autenticación es por Bearer token.
app.use('/api', (req, res, nx) => {
  res.set({ 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS' });
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  nx();
});
app.use((req, res, nx) => { res.set({ 'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY', 'Referrer-Policy': 'same-origin',
  'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'" }); nx(); });

app.get('/api/health', wrap(async (req, res) => {
  await q('SELECT 1');
  let sb = { configured: !!supabase, ok: false };
  if (supabase) {
    const { error } = await supabase.from('configuraciones').select('clave').limit(1);
    sb.ok = !error; if (error) sb.error = error.message;
  }
  res.json({ ok: true, version, database: 'Supabase PostgreSQL', supabase: sb, hora: new Date().toISOString() });
}));

const auth = wrap(async (req, res, nx) => {
  const t = (req.headers.authorization || '').replace('Bearer ', '');
  try { req.user = jwt.verify(t, SECRET); } catch { throw bad('Sesión no iniciada o vencida.', 401); }
  const u = (await q('SELECT activo FROM usuarios WHERE id=$1 AND eliminado_en IS NULL', [req.user.id]))[0]; if (!u || !u.activo) throw bad('Usuario inactivo.', 401);
  req.perms = new Set((await q('SELECT DISTINCT p.modulo,p.accion FROM usuario_roles ur JOIN rol_permisos rp ON rp.rol_id=ur.rol_id JOIN permisos p ON p.id=rp.permiso_id WHERE ur.usuario_id=$1', [req.user.id])).map(r => r.modulo + ':' + r.accion));
  nx(); });
const need = (mod, acc) => (req, res, nx) => req.perms.has(mod + ':' + acc) ? nx() : nx(bad('No tiene permiso para esta acción.', 403));
const audit = (c2, req, accion, ent, id, nuevo) => c2.query('INSERT INTO auditoria (usuario_id,accion,entidad,entidad_id,valores_nuevos,ip) VALUES ($1,$2,$3,$4,$5::jsonb,$6)', [req.user.id, accion, ent, String(id), nuevo ? JSON.stringify(nuevo) : null, req.ip]);

app.post('/api/auth/login', wrap(async (req, res) => {
  const { usuario, password } = req.body || {}; if (!usuario || !password) throw bad('Ingrese usuario y contraseña.');
  const u = (await q('SELECT * FROM usuarios WHERE nombre_usuario=$1 AND activo=TRUE AND eliminado_en IS NULL', [usuario]))[0];
  const log = ok => q('INSERT INTO registros_acceso (usuario_id,nombre_usuario,ip,exitoso) VALUES ($1,$2,$3,$4)', [u ? u.id : null, String(usuario).slice(0, 50), req.ip, !!ok]);
  if (u && u.bloqueado_hasta && new Date(String(u.bloqueado_hasta).replace(' ', 'T')) > new Date()) { await log(0); throw bad('Cuenta bloqueada temporalmente. Intente más tarde.', 423); }
  if (!u || !(await bcrypt.compare(password, u.password_hash))) { await log(0);
    if (u) await q("UPDATE usuarios SET intentos_fallidos=intentos_fallidos+1, bloqueado_hasta=CASE WHEN intentos_fallidos+1>=5 THEN sigfv_now()+INTERVAL '15 minutes' ELSE NULL END WHERE id=$1", [u.id]);
    throw bad('Usuario o contraseña incorrectos.', 401); }
  await q('UPDATE usuarios SET intentos_fallidos=0,bloqueado_hasta=NULL,ultimo_acceso=sigfv_now() WHERE id=$1', [u.id]); await log(1);
  res.json({ token: jwt.sign({ id: u.id, u: u.nombre_usuario }, SECRET, { expiresIn: '8h' }) }); }));

app.get('/api/meta', auth, wrap(async (req, res) => {
  const out = {}; for (const [k, r] of Object.entries(RES)) if (req.perms.has(r.mod + ':consultar'))
    out[k] = { label: r.label, group: r.group, mod: r.mod, icon: r.icon, cols: r.cols, fields: r.fields, crear: req.perms.has(r.mod + ':crear'), editar: req.perms.has(r.mod + ':editar'), eliminar: req.perms.has(r.mod + ':eliminar') && !!r.soft, exportar: req.perms.has(r.mod + ':exportar') };
  const u = (await q("SELECT (nombres || ' ' || apellidos) nombre FROM usuarios WHERE id=$1", [req.user.id]))[0];
  res.json({ user: u.nombre, roles: (await q('SELECT r.nombre FROM usuario_roles ur JOIN roles r ON r.id=ur.rol_id WHERE ur.usuario_id=$1', [req.user.id])).map(r => r.nombre),
    dashboard: req.perms.has('dashboard:consultar'), notificaciones: req.perms.has('notificaciones:consultar'), resources: out }); }));

app.get('/api/cat/:n', auth, wrap(async (req, res) => { if (!CAT[req.params.n]) throw bad('Catálogo no válido.', 404); res.json(await q(CAT[req.params.n])); }));

app.get('/api/dashboard', auth, need('dashboard', 'consultar'), wrap(async (req, res) => {
  const cfgRow = (await q("SELECT valor FROM configuraciones WHERE clave='alerta.documentos.dias'"))[0];
  const dias = Math.max(0, parseInt(cfgRow && cfgRow.valor, 10) || 30);
  const [k] = await q(`SELECT
    (SELECT COUNT(*)::int FROM vehiculos WHERE eliminado_en IS NULL) total,
    (SELECT COUNT(*)::int FROM conductores WHERE estado='activo' AND eliminado_en IS NULL) conductores,
    (SELECT COUNT(*)::int FROM inspecciones WHERE resultado='no_conforme' AND fecha_hora>=sigfv_now()-INTERVAL '30 days') insp_nc,
    (SELECT COUNT(*)::int FROM documentos WHERE eliminado_en IS NULL AND fecha_vencimiento<=sigfv_today()+${dias}) docs,
    (SELECT COUNT(*)::int FROM mantenimientos WHERE estado='programado' AND eliminado_en IS NULL) mant,
    (SELECT COALESCE(SUM(litros),0) FROM abastecimientos WHERE fecha>=date_trunc('month',sigfv_now())) litros,
    (SELECT COUNT(*)::int FROM incidentes WHERE estado_investigacion<>'cerrado' AND eliminado_en IS NULL) incidentes`);
  const estados = await q('SELECT e.nombre,e.color,COUNT(v.id)::int n FROM estados_vehiculo e LEFT JOIN vehiculos v ON v.estado_id=e.id AND v.eliminado_en IS NULL GROUP BY e.id,e.nombre,e.color ORDER BY e.id');
  const mant = await q("SELECT v.codigo_interno vehiculo,t.nombre tipo,m.fecha FROM mantenimientos m JOIN vehiculos v ON v.id=m.vehiculo_id JOIN tipos_mantenimiento t ON t.id=m.tipo_id WHERE m.estado='programado' AND m.eliminado_en IS NULL ORDER BY m.fecha LIMIT 6");
  const docs = await q(`SELECT COALESCE(v.codigo_interno,(c.nombres || ' ' || c.apellidos)) titular,td.nombre documento,d.fecha_vencimiento vence FROM documentos d JOIN tipos_documento td ON td.id=d.tipo_id LEFT JOIN vehiculos v ON v.id=d.vehiculo_id LEFT JOIN conductores c ON c.id=d.conductor_id WHERE d.eliminado_en IS NULL AND d.fecha_vencimiento<=sigfv_today()+${dias} ORDER BY d.fecha_vencimiento LIMIT 6`);
  res.json({ k, estados, mant, docs }); }));

app.get('/api/notificaciones', auth, need('notificaciones', 'consultar'), wrap(async (req, res) => res.json(await q(`
  (SELECT CASE WHEN d.fecha_vencimiento<sigfv_today() THEN 'Documento vencido' ELSE 'Documento por vencer' END tipo,(td.nombre || ' · ' || COALESCE(v.codigo_interno,(c.nombres || ' ' || c.apellidos))) detalle,d.fecha_vencimiento fecha FROM documentos d JOIN tipos_documento td ON td.id=d.tipo_id LEFT JOIN vehiculos v ON v.id=d.vehiculo_id LEFT JOIN conductores c ON c.id=d.conductor_id WHERE d.eliminado_en IS NULL AND d.fecha_vencimiento<=sigfv_today()+30)
  UNION ALL (SELECT CASE WHEN l.fecha_vencimiento<sigfv_today() THEN 'Licencia vencida' ELSE 'Licencia por vencer' END,(c.nombres || ' ' || c.apellidos || ' · ' || l.numero),l.fecha_vencimiento FROM licencias l JOIN conductores c ON c.id=l.conductor_id WHERE c.eliminado_en IS NULL AND l.fecha_vencimiento<=sigfv_today()+30)
  UNION ALL (SELECT 'Inspección no conforme',v.codigo_interno,(i.fecha_hora)::date FROM inspecciones i JOIN vehiculos v ON v.id=i.vehiculo_id WHERE i.resultado='no_conforme' AND i.fecha_hora>=sigfv_now()-INTERVAL '30 days')
  UNION ALL (SELECT 'Vehículo fuera de servicio',v.codigo_interno,(v.actualizado_en)::date FROM vehiculos v JOIN estados_vehiculo e ON e.id=v.estado_id WHERE e.nombre='Fuera de servicio' AND v.eliminado_en IS NULL)
  UNION ALL (SELECT 'Incidente pendiente',(codigo || ' · ' || LEFT(descripcion,60)),(fecha_hora)::date FROM incidentes WHERE estado_investigacion<>'cerrado' AND eliminado_en IS NULL)
  ORDER BY fecha LIMIT 100`))));

/* ---------- CRUD genérico con permisos verificados en el servidor ---------- */
const R = (req, res, nx) => { req.R = RES[req.params.k]; req.R ? nx() : nx(bad('Módulo no encontrado.', 404)); };
const gate = acc => (req, res, nx) => need(req.R.mod, acc)(req, res, nx);
const where = R2 => R2.soft === 'eliminado_en' ? 'a.eliminado_en IS NULL' : R2.soft === 'activo' ? 'a.activo=TRUE' : '1=1';
const norm = v => typeof v === 'string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d/.test(v) ? v.replace('T', ' ').padEnd(19, ':00') : v;
const tbl = t => { if (!/^[a-z_][a-z0-9_]*$/.test(t)) throw bad('Tabla no válida.'); return '"' + t + '"'; };

app.get('/api/r/:k', auth, R, gate('consultar'), wrap(async (req, res) => {
  const r = req.R, lim = Math.min(+req.query.limit || 15, 5000), off = ((+req.query.pagina || 1) - 1) * lim, s = String(req.query.q || '').trim();
  const w = [where(r)], p = [];
  if (s) { w.push('(' + r.search.map((x, i) => `${x} ILIKE $${i + 1}`).join(' OR ') + ')'); r.search.forEach(() => p.push('%' + s + '%')); }
  const n = (await q(`SELECT COUNT(*)::int n ${r.from} WHERE ${w.join(' AND ')}`, p))[0].n;
  const items = await q(`SELECT ${r.sel} ${r.from} WHERE ${w.join(' AND ')} ORDER BY a.id DESC LIMIT $${p.length + 1} OFFSET $${p.length + 2}`, [...p, lim, off]);
  res.json({ total: n, items }); }));

app.get('/api/r/:k/:id', auth, R, gate('consultar'), wrap(async (req, res) => {
  const rows = await q(`SELECT a.* FROM ${tbl(req.R.t)} a WHERE a.id=$1 AND ${where(req.R)}`, [+req.params.id]);
  const row = rows[0]; if (!row) throw bad('Registro no encontrado.', 404);
  if (req.R.one) await req.R.one(row); res.json(row); }));

async function save(req, res, id) {
  const r = req.R, b = req.body || {}, cn = await pool.connect(), nuevo = !id, t = tbl(r.t);
  try { await cn.query('BEGIN'); const o = {};
    for (const f of r.fields) { if (f.virtual) continue; if (!nuevo && !(f.n in b)) continue; let v = norm(b[f.n]); if (v === '' || v === undefined) v = null;
      if (v !== null && (f.n === 'activo' || f.n === 'bloquea_vehiculo')) v = (v === '1' || v === 1 || v === true || v === 'true');
      if (f.req && v === null) throw bad(`${f.l} es obligatorio.`); if (v === null && nuevo) continue; o[f.n] = v; }
    if (r.t === 'usuarios') { if (b.password) { if (b.password.length < 8) throw bad('La contraseña debe tener al menos 8 caracteres.'); o.password_hash = await bcrypt.hash(b.password, 12); } else if (nuevo) throw bad('La contraseña es obligatoria.'); }
    if (nuevo) { (r.auto || []).forEach(a => o[a] = req.user.id); if (r.t === 'incidentes') o.codigo = 'INC-' + Date.now().toString(36).toUpperCase(); }
    let old = null; if (!nuevo) { old = (await cn.query(`SELECT * FROM ${t} WHERE id=$1`, [id])).rows[0]; if (!old) throw bad('Registro no encontrado.', 404); }
    if (nuevo) {
      const keys = Object.keys(o); if (!keys.length) throw bad('No hay datos para guardar.');
      const cols = keys.map(k => `"${k}"`).join(','), vals = keys.map((_, i) => `$${i + 1}`).join(',');
      id = (await cn.query(`INSERT INTO ${t} (${cols}) VALUES (${vals}) RETURNING id`, keys.map(k => o[k]))).rows[0].id;
    } else if (Object.keys(o).length) {
      const keys = Object.keys(o), sets = keys.map((k, i) => `"${k}"=$${i + 1}`).join(',');
      await cn.query(`UPDATE ${t} SET ${sets} WHERE id=$${keys.length + 1}`, [...keys.map(k => o[k]), id]);
    }
    if (r.after) await r.after(id, b, req, cn, nuevo, o, old);
    const log = { ...o }; delete log.password_hash; await audit(cn, req, nuevo ? 'crear' : 'editar', r.t, id, log);
    await cn.query('COMMIT'); res.status(nuevo ? 201 : 200).json({ id });
  } catch (e) { await cn.query('ROLLBACK').catch(() => {}); throw e; } finally { cn.release(); } }

app.post('/api/r/:k', auth, R, gate('crear'), wrap((req, res) => save(req, res, null)));
app.put('/api/r/:k/:id', auth, R, gate('editar'), wrap((req, res) => save(req, res, +req.params.id)));
app.delete('/api/r/:k/:id', auth, R, gate('eliminar'), wrap(async (req, res) => {
  const r = req.R; if (!r.soft) throw bad('Este registro es histórico y no puede eliminarse.', 405);
  const set = r.soft === 'activo' ? 'activo=FALSE' : 'eliminado_en=sigfv_now()' + (r.t === 'usuarios' ? ',activo=FALSE' : '');
  if (r.t === 'usuarios' && +req.params.id === req.user.id) throw bad('No puede eliminar su propio usuario.');
  const x = await pool.query(`UPDATE ${tbl(r.t)} SET ${set} WHERE id=$1`, [+req.params.id]); if (!x.rowCount) throw bad('Registro no encontrado.', 404);
  await audit(pool, req, 'eliminar', r.t, req.params.id); res.json({ ok: true }); }));

app.use('/api', (req, res) => res.status(404).json({ error: 'Ruta no encontrada.' }));
app.use(express.static(path.join(__dirname, 'public')));
app.use((e, req, res, nx) => {
  if (e.http) return res.status(e.http).json({ error: e.message });
  if (e.type === 'entity.parse.failed') return res.status(400).json({ error: 'El cuerpo de la solicitud no es JSON válido.' });
  if (e.code === 'P0001') return res.status(409).json({ error: e.message });
  if (e.code === '23505') return res.status(409).json({ error: 'Ya existe un registro con ese valor único (código, placa, documento, etc.).' });
  if (e.code === '23514') return res.status(400).json({ error: 'Algún valor no cumple las reglas de validación (fechas, cantidades o titular del documento).' });
  if (e.code === '23503') return res.status(400).json({ error: 'Alguno de los datos relacionados no existe.' });
  if (e.code === '23502') return res.status(400).json({ error: 'Falta un dato obligatorio.' });
  if (['22P02', '22007', '22008', '22003', '22001'].includes(e.code)) return res.status(400).json({ error: 'Formato de dato inválido.' });
  console.error(e); res.status(500).json({ error: 'Error interno del servidor.' }); });
const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => console.log('SIGFV escuchando en el puerto ' + PORT));

// Cierre ordenado para contenedores (Docker, Render, Fly, Railway, VPS).
function shutdown(signal) {
  console.log(signal + ' recibido. Cerrando SIGFV...');
  server.close(() => {
    pool.end()
      .then(() => process.exit(0))
      .catch(() => process.exit(1));
  });
  // Si alguna conexión queda colgada, no bloquear el reinicio del contenedor.
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
