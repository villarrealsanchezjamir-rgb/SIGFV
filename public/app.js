'use strict';
/* SIGFV · interfaz de escritorio */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = t => String(t ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sleep = ms => new Promise(r => setTimeout(r, ms));

const ICONS = {
  dashboard: '<rect x="3" y="3" width="7" height="9" rx="1"/><rect x="14" y="3" width="7" height="5" rx="1"/><rect x="14" y="12" width="7" height="9" rx="1"/><rect x="3" y="16" width="7" height="5" rx="1"/>',
  truck: '<path d="M14 18V6a1 1 0 0 0-1-1H3a1 1 0 0 0-1 1v11a1 1 0 0 0 1 1h1"/><path d="M14 9h4l4 4v5a1 1 0 0 1-1 1h-1"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/>',
  'id-card': '<rect x="2" y="5" width="20" height="14" rx="2"/><circle cx="8" cy="11" r="2"/><path d="M8 15c-1.7 0-3 .8-3 2h6c0-1.2-1.3-2-3-2Z"/><path d="M14 9h5M14 13h5"/>',
  calendar: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  wrench: '<path d="M14.7 6.3a4 4 0 0 0 5 5l-9.4 9.4a2.8 2.8 0 0 1-4-4l9.4-9.4Z"/><path d="M14.7 6.3 17 4a4 4 0 0 1 3 3l-2.3 2.3"/>',
  file: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6M8 13h8M8 17h6"/>',
  clipboard: '<rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><path d="m9 14 2 2 4-4"/>',
  fuel: '<path d="M3 22V6a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16"/><path d="M3 22h10M5 10h6"/><path d="M13 8h2l3 3v7a2 2 0 0 0 4 0v-6l-3-3"/>',
  alert: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
  shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z"/>',
  bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10.3 21a2 2 0 0 0 3.4 0"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5M21 12H9"/>',
  search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  down: '<path d="m6 9 6 6 6-6"/>',
  x: '<path d="M18 6 6 18M6 6l12 12"/>',
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  edit: '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.1 2.1 0 0 1 3 3L12 15l-4 1 1-4Z"/>',
  trash: '<path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/>',
  download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5M12 15V3"/>',
  refresh: '<path d="M21 12a9 9 0 1 1-2.6-6.4"/><path d="M21 3v6h-6"/>',
  building: '<rect x="4" y="2" width="16" height="20" rx="2"/><path d="M9 22v-4h6v4M8 6h.01M12 6h.01M16 6h.01M8 10h.01M12 10h.01M16 10h.01M8 14h.01M12 14h.01M16 14h.01"/>',
  package: '<path d="m21 8-9-5-9 5v8l9 5 9-5Z"/><path d="m3 8 9 5 9-5M12 13v8"/>',
  gauge: '<path d="M12 14 8 8"/><path d="M3.3 18a9 9 0 1 1 17.4 0"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  check: '<path d="m20 6-11 11-5-5"/>',
  key: '<circle cx="7.5" cy="15.5" r="4.5"/><path d="m10.5 12.5 9-9M16 7l3 3M19 4l2 2"/>',
  back: '<path d="m15 18-6-6 6-6"/>',
  eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
  eyeoff: '<path d="m3 3 18 18M10.6 10.6a3 3 0 0 0 4.2 4.2"/><path d="M9.9 5.2A10.6 10.6 0 0 1 12 5c6.5 0 10 7 10 7a18 18 0 0 1-3 4M6.6 6.6A18 18 0 0 0 2 12s3.5 7 10 7a10.7 10.7 0 0 0 4.1-.8"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/>',
  map: '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>'
};
const ICON_ALIAS = {
  'calendar-range': 'calendar', 'file-text': 'file', 'clipboard-check': 'clipboard',
  'triangle-alert': 'alert', 'circle-alert': 'alert', 'badge-check': 'shield'
};
function ic(name, cls = '') {
  const key = ICON_ALIAS[name] || name;
  const p = ICONS[key] || ICONS.package;
  return `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true">${p}</svg>`;
}

/* ---------- Agrupación de módulos ---------- */
const GROUP_DEFS = [
  { id: 'operaciones', title: 'Gestión de Operaciones', icon: 'truck', desc: 'Flota, conductores y asignaciones' },
  { id: 'mantenimiento', title: 'Gestión de Mantenimiento', icon: 'wrench', desc: 'Servicios e inspecciones técnicas' },
  { id: 'logistica', title: 'Gestión Logística', icon: 'fuel', desc: 'Combustible y documentación' },
  { id: 'seguridad', title: 'Gestión de Seguridad', icon: 'shield', desc: 'Incidentes y acciones correctivas' },
  { id: 'administracion', title: 'Administración', icon: 'settings', desc: 'Usuarios y catálogos maestros' }
];
const GROUP_MAP = {
  vehiculos: 'operaciones', conductores: 'operaciones', asignaciones: 'operaciones',
  mantenimientos: 'mantenimiento', inspecciones: 'mantenimiento',
  abastecimientos: 'logistica', documentos: 'logistica',
  incidentes: 'seguridad',
  solicitudes: 'administracion',
  usuarios: 'administracion', empresas: 'administracion', unidades_mineras: 'administracion',
  marcas: 'administracion', modelos: 'administracion', propietarios: 'administracion',
  proveedores_combustible: 'administracion', talleres: 'administracion', roles: 'administracion'
};
const GROUP_OWNERS = {
  operaciones: 'Supervisor de flota',
  mantenimiento: 'Responsable de mantenimiento',
  logistica: 'Encargado de logística',
  seguridad: 'Personal de seguridad',
  administracion: 'Administrador'
};
const MODULE_ORDER = [
  'vehiculos', 'conductores', 'asignaciones',
  'mantenimientos', 'inspecciones',
  'abastecimientos', 'documentos',
  'incidentes',
  'solicitudes',
  'usuarios', 'roles', 'empresas', 'unidades_mineras',
  'marcas', 'modelos', 'propietarios', 'proveedores_combustible', 'talleres'
];

const state = {
  token: sessionStorage.getItem('sigfv_token') || '',
  meta: null, current: null, page: 1, q: '', limit: 20,
  cats: {}, request: 0, dirty: false, collapsed: JSON.parse(localStorage.getItem('sigfv_nav_collapsed') || '{}'),
  companies: [], contextLoaded: false, rolesCache: [], companyDetail: null
};

const BADGE_COLORS = {
  conforme: '#26865B', activo: '#26865B', vigente: '#26865B', completado: '#26865B', cerrado: '#26865B', finalizada: '#26865B',
  no_conforme: '#C64747', vencido: '#C64747', inhabilitado: '#C64747', inactivo: '#C64747', cancelada: '#C64747', cancelado: '#C64747',
  'por vencer': '#A98624', programado: '#447BA8', programada: '#447BA8', activa: '#447BA8', en_proceso: '#A98624',
  en_investigacion: '#A98624', pendiente: '#C64747', en_curso: '#447BA8', cumplida: '#26865B',
  operativo: '#26865B', 'en mantenimiento': '#A98624', 'fuera de servicio': '#C64747', alquilado: '#447BA8', 'de baja': '#42464B'
};
const badge = v => {
  const k = String(v ?? '').toLowerCase();
  return `<span class="tag" style="background:${BADGE_COLORS[k] || '#42464B'}"><span class="d"></span>${esc(String(v ?? '').replace(/_/g, ' '))}</span>`;
};

async function api(path, opts = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), opts.timeout || 25000);
  const headers = { 'Content-Type': 'application/json' };
  if (state.token) headers.Authorization = 'Bearer ' + state.token;
  try {
    const res = await fetch(path, {
      method: opts.method || 'GET',
      headers,
      body: opts.body != null ? JSON.stringify(opts.body) : undefined,
      signal: ctrl.signal,
      cache: 'no-store'
    });
    let data = {};
    try { data = await res.json(); } catch { }
    if (res.status === 401 && path !== '/api/auth/login') { logout(true); throw new Error('La sesión venció. Vuelva a ingresar.'); }
    if (!res.ok) throw new Error(data.error || 'Error ' + res.status);
    return data;
  } catch (e) {
    if (e.name === 'AbortError') throw new Error('El servidor tardó demasiado. Verifique la conexión e intente de nuevo.');
    if (e instanceof TypeError) throw new Error('No se pudo conectar con el servidor. Reintentando…');
    throw e;
  } finally { clearTimeout(timer); }
}
async function apiRetry(path, opts = {}, tries = 2) {
  let last;
  for (let i = 0; i < tries; i++) {
    try { return await api(path, opts); } catch (e) { last = e; if (i < tries - 1) await sleep(900); }
  }
  throw last;
}

function toast(msg, isError = false) {
  const t = $('#toast');
  t.innerHTML = ic(isError ? 'alert' : 'check') + '<span>' + esc(msg) + '</span>';
  t.className = 'on' + (isError ? ' err' : '');
  clearTimeout(t._t);
  t._t = setTimeout(() => { t.className = ''; }, 3600);
}

function fmt(v) {
  if (v == null || v === '') return '—';
  const s = String(v);
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    const [y, m, d] = s.split('-').map(Number);
    return new Date(y, m - 1, d).toLocaleDateString('es-PE', { day: '2-digit', month: 'short', year: 'numeric' });
  }
  if (/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}/.test(s)) {
    const d = new Date(s.replace(' ', 'T'));
    if (!isNaN(d)) return d.toLocaleString('es-PE', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  }
  return s;
}
function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n.toLocaleString('es-PE', { maximumFractionDigits: 2 }) : '—';
}
function initials(name) {
  return String(name || '?').trim().split(/\s+/).slice(0, 2).map(x => x[0]).join('').toUpperCase();
}

/* ---------- Agrupación y navegación ---------- */
function buildGroups() {
  const groups = GROUP_DEFS.map(g => ({ ...g, owner: GROUP_OWNERS[g.id] || 'Administrador', items: [] }));
  const byId = Object.fromEntries(groups.map(g => [g.id, g]));
  for (const [key, r] of Object.entries(state.meta.resources)) {
    if (r.custom) continue; // se muestra como acceso directo con contador
    const gid = GROUP_MAP[key] || (r.group === 'Catálogos' || r.group === 'Configuración' ? 'administracion' : 'operaciones');
    (byId[gid] || byId.operaciones).items.push({ key, ...r });
  }
  const order = key => {
    const i = MODULE_ORDER.indexOf(key);
    return i < 0 ? 999 : i;
  };
  for (const g of groups) g.items.sort((a, b) => (a.order ?? order(a.key)) - (b.order ?? order(b.key)) || a.label.localeCompare(b.label));
  return groups.filter(g => g.items.length);
}
function groupNameOf(key) {
  const gid = GROUP_MAP[key];
  const g = GROUP_DEFS.find(x => x.id === gid);
  return g ? g.title : 'Módulos';
}
function toastError(e) { toast(e.message || 'Ocurrió un error.', true); }

/* ---------- Sesión ---------- */
function showLogin() {
  $('#app').classList.add('hidden');
  $('#login').classList.remove('hidden');
  setTimeout(() => $('#empresa').focus(), 60);
}
function logout(silent = false) {
  sessionStorage.removeItem('sigfv_token');
  sessionStorage.removeItem('sigfv_session');
  state.token = ''; state.meta = null; state.current = null;
  closeDrawer();
  showLogin();
  if (!silent) toast('Sesión cerrada.');
}
function can(mod, action) {
  return !!state.meta && (state.meta.permissions || []).includes(`${mod}:${action}`);
}
async function loadContext(force = false) {
  if (state.contextLoaded && !force) return;
  const ctx = await api('/api/auth/context', { timeout: 35000 });
  state.companies = ctx.empresas || [];
  state.contextLoaded = true;
  const sel = $('#empresa');
  const keep = sel.value;
  sel.innerHTML = '<option value="">Seleccione su empresa…</option>' + state.companies
    .map(c => `<option value="${c.id}">${esc(c.razonSocial)}${c.id === 0 ? ' · acceso global' : ''}</option>`).join('');
  if (keep && state.companies.some(c => String(c.id) === keep)) {
    sel.value = keep;
    fillRoles();
  } else {
    $('#rol').innerHTML = '<option value="">Seleccione una empresa</option>';
    $('#rol').disabled = true;
  }
}
function fillRoles() {
  const company = state.companies.find(c => String(c.id) === $('#empresa').value);
  const sel = $('#rol');
  if (!company) {
    sel.disabled = true;
    sel.innerHTML = '<option value="">Seleccione una empresa</option>';
    return;
  }
  sel.disabled = false;
  sel.innerHTML = '<option value="">Seleccione su rol…</option>' + company.roles
    .map(r => `<option value="${r.rolId}">${esc(r.nombre)}${r.descripcion ? ' · ' + esc(r.descripcion) : ''}</option>`).join('');
}
async function login(empresaId, rolId, password, operador) {
  const r = await api('/api/auth/login', {
    method: 'POST',
    body: { empresaId, rolId, password, operador: operador || null },
    timeout: 45000
  });
  state.token = r.token;
  sessionStorage.setItem('sigfv_token', r.token);
  sessionStorage.setItem('sigfv_session', JSON.stringify({
    rol: r.rol, empresa: r.empresa, empresaId: r.empresaId, operador: r.operador
  }));
}
async function boot() {
  loadContext().catch(() => {
    $('#empresa').innerHTML = '<option value="">No se pudieron cargar las empresas</option>';
    $('#loginError').textContent = 'No se pudo conectar con el servidor. Verifique su conexión.';
  });
  if (!state.token) { showLogin(); return; }
  try {
    state.meta = await apiRetry('/api/meta');
    renderShell();
    navigate(state.meta.dashboard ? 'dashboard' : Object.keys(state.meta.resources)[0] || '');
  } catch (e) {
    if (e.message.includes('sesión')) return;
    showLogin();
    $('#loginError').textContent = e.message;
  }
}

/* ---------- Shell ---------- */
function renderShell() {
  $('#login').classList.add('hidden');
  $('#app').classList.remove('hidden');
  const name = state.meta.user || 'Usuario';
  const roles = (state.meta.roles || []).join(', ');
  const company = state.meta.empresa || '';
  $('#avatar').textContent = initials(name);
  $('#avatar').title = name + (roles ? ' · ' + roles : '') + (company ? ' · ' + company : '');
  $('#sideAvatar').textContent = initials(name);
  $('#sideName').textContent = name;
  $('#sideRoles').textContent = [roles, company].filter(Boolean).join(' · ') || 'Sin rol asignado';
  renderNav();
  $('#nav').onclick = e => {
    const item = e.target.closest('.nav-item');
    if (item) { navigate(item.dataset.key); return; }
    const head = e.target.closest('.nav-head');
    if (head) {
      const g = head.parentElement;
      g.classList.toggle('closed');
      const id = g.dataset.group;
      state.collapsed[id] = g.classList.contains('closed');
      localStorage.setItem('sigfv_nav_collapsed', JSON.stringify(state.collapsed));
    }
  };
  $('#logout').onclick = () => logout();
  $('#bell').onclick = () => navigate('notificaciones');
  $('#menuBtn').onclick = () => $('#sidebar').classList.add('open') || $('#scrim').classList.add('on');
  $('#scrim').onclick = closeSidebar;
  $('#moduleFilter').oninput = e => filterNav(e.target.value);
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') { closeSidebar(); closeDrawer(); }
    if (e.key === '/' && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) {
      e.preventDefault();
      const s = $('#q'); if (s) s.focus();
    }
  });
  if (state.meta.notificaciones) {
    $('#bell').classList.remove('hidden');
    api('/api/notificaciones').then(n => setBell(n.length)).catch(() => { });
  } else $('#bell').classList.add('hidden');
}
function setBell(n) {
  const b = $('#bellCount');
  if (!b) return;
  b.textContent = n > 99 ? '99+' : n;
  b.classList.toggle('hidden', !n);
}
function renderNav() {
  const groups = buildGroups();
  let html = '';
  if (state.meta.dashboard) html += `<div class="nav-title">Principal</div><button class="nav-item" data-key="dashboard">${ic('dashboard')}Dashboard</button>`;
  if (state.meta.notificaciones) html += `<button class="nav-item" data-key="notificaciones">${ic('bell')}Notificaciones<span class="pill" id="navBell">0</span></button>`;
  html += `<button class="nav-item" data-key="cuenta">${ic('user')}Mi cuenta</button>`;
  for (const g of groups) {
    const closed = state.collapsed[g.id] ? ' closed' : '';
    html += `<div class="nav-group${closed}" data-group="${g.id}">
      <button class="nav-head">${ic(g.icon)}<span>${esc(g.title)}</span><small class="nav-owner" title="Encargado del área">${esc(g.owner)}</small>${ic('down', 'sm chev')}</button>
      <div class="nav-items">${g.items.map(r => `<button class="nav-item" data-key="${r.key}">${ic(r.icon || 'package')}${esc(r.label)}</button>`).join('')}</div>
    </div>`;
  }
  const extras = [];
  extras.push(`<button class="nav-item" data-key="responsables">${ic('shield')}Módulos y responsables</button>`);
  if (can('configuracion', 'consultar')) {
    const pend = Number(state.meta.solicitudesPendientes || 0);
    extras.push(`<button class="nav-item" data-key="solicitudes">${ic('building')}Solicitudes de empresas${pend ? `<span class="pill">${pend}</span>` : ''}</button>`);
    extras.push(`<button class="nav-item" data-key="empresas">${ic('building')}Empresas clientes</button>`);
    extras.push(`<button class="nav-item" data-key="auditoria">${ic('shield')}Auditoría</button>`);
  }
  const exportables = Object.values(state.meta.resources).some(r => r.exportar);
  if (exportables) extras.push(`<button class="nav-item" data-key="export-all">${ic('download')}Exportar todos los módulos</button>`);
  if (extras.length) html += `<div class="nav-title">Reportes y administración</div>${extras.join('')}`;
  $('#nav').innerHTML = html;
  const navBell = $('#navBell'), bellCount = $('#bellCount');
  if (navBell && bellCount) navBell.textContent = bellCount.textContent;
}
function filterNav(q) {
  q = q.toLowerCase().trim();
  $$('#nav .nav-group').forEach(g => {
    let visible = 0;
    $$('.nav-item', g).forEach(a => {
      const show = !q || a.textContent.toLowerCase().includes(q);
      a.style.display = show ? '' : 'none';
      if (show) visible++;
    });
    g.style.display = visible ? '' : 'none';
    if (q) g.classList.remove('closed');
  });
}
function closeSidebar() { $('#sidebar').classList.remove('open'); $('#scrim').classList.remove('on'); }

function navigate(key) {
  closeSidebar();
  state.current = key;
  state.page = 1;
  state.q = '';
  $$('.nav-item').forEach(a => a.classList.toggle('active', a.dataset.key === key));
  if (key === 'dashboard') renderDashboard();
  else if (key === 'notificaciones') renderNotifications();
  else if (key === 'cuenta') renderAccount();
  else if (key === 'responsables') renderOwners();
  else if (key === 'roles') renderRoles();
  else if (key === 'solicitudes') renderSolicitudes();
  else if (key === 'empresas') renderCompanies();
  else if (key === 'auditoria') renderAudit();
  else if (key === 'export-all') exportAll();
  else if (key.startsWith('empresa/')) renderCompany(+key.split('/')[1]);
  else renderList(key);
}
function crumb(parts) {
  $('#crumb').innerHTML = parts.map((p, i) => i ? `<span class="sep">/</span><span>${esc(p)}</span>` : `<b>${esc(p)}</b>`).join('');
}

/* ---------- Dashboard ---------- */
const KPI_DEFS = [
  ['total', 'Vehículos registrados', 'truck', 'gold', 'en la flota'],
  ['conductores', 'Conductores activos', 'id-card', 'ok', 'habilitados'],
  ['insp_nc', 'Inspecciones no conformes', 'clipboard', 'bad', 'últimos 30 días'],
  ['docs', 'Documentos por vencer', 'file', 'warn', 'requieren atención'],
  ['mant', 'Mantenimientos programados', 'wrench', 'info', 'pendientes'],
  ['litros', 'Combustible del mes', 'fuel', '', 'litros registrados'],
  ['incidentes', 'Incidentes abiertos', 'alert', 'bad', 'en investigación']
];
async function renderDashboard() {
  crumb(['Dashboard']);
  const view = $('#view');
  view.innerHTML = `<div class="page-head"><div><h1>Dashboard general</h1><p>Resumen operativo calculado desde la base de datos.</p></div><div class="spacer"></div><div class="head-actions"><button class="btn ghost" id="refreshDash">${ic('refresh')}Actualizar</button></div></div>
  <div class="kpis">${Array.from({ length: 7 }, () => '<div class="kpi"><div class="skel" style="width:70%"></div><div class="skel" style="width:40%;height:30px;margin-top:12px"></div></div>').join('')}</div>`;
  $('#refreshDash').onclick = renderDashboard;
  try {
    const d = await apiRetry('/api/dashboard');
    const k = d.k || {};
    const total = Math.max(1, ...(d.estados || []).map(e => e.n));
    const quick = Object.entries(state.meta.resources).slice(0, 6);
    view.innerHTML = `
      <div class="page-head"><div><h1>Dashboard general</h1><p>Resumen operativo calculado desde la base de datos.</p></div><div class="spacer"></div>
      <div class="head-actions"><button class="btn ghost" id="refreshDash">${ic('refresh')}Actualizar</button><button class="btn primary" id="dashNew">${ic('plus')}Nuevo registro</button></div></div>
      <div class="kpis">${KPI_DEFS.map(([key, label, icon, tone, hint]) => `
        <article class="kpi ${tone}"><div class="k-top"><span>${label}</span><span class="k-ico">${ic(icon)}</span></div>
        <strong>${key === 'litros' ? num(k[key]) : Number(k[key] || 0).toLocaleString('es-PE')}</strong><small>${hint}</small></article>`).join('')}
      </div>
      <div class="dash-grid">
        <div>
          <section class="card" style="margin-bottom:14px">
            <div class="card-head">${ic('gauge')}<h3>Disponibilidad de la flota</h3><span class="spacer"></span><span class="muted" style="font-size:12px">${(d.estados || []).reduce((a, e) => a + e.n, 0)} unidades</span></div>
            <div class="card-body bars">${(d.estados || []).map(e => `<div class="bar-row"><span>${esc(e.nombre)}</span><div class="track"><div class="fill" style="width:${e.n / total * 100}%;background:${esc(e.color || '#42464B')}"></div></div><b>${e.n}</b></div>`).join('') || '<span class="muted">Sin datos de estado.</span>'}</div>
          </section>
          <section class="card">
            <div class="card-head">${ic('plus')}<h3>Accesos rápidos</h3></div>
            <div class="card-body"><div class="quick" style="margin-top:0">${quick.map(([key, r]) => `<a href="#" data-go="${key}">${ic(r.icon || 'package')}<span>${esc(r.label)}</span></a>`).join('')}</div></div>
          </section>
        </div>
        <div>
          <section class="card" style="margin-bottom:14px">
            <div class="card-head">${ic('wrench')}<h3>Próximos mantenimientos</h3><span class="spacer"></span><a href="#" data-go="mantenimientos" class="muted" style="font-size:12px">Ver todos</a></div>
            <div class="card-body mini-list">${(d.mant || []).map(m => `<div class="mini-row"><span class="m-ico">${ic('wrench')}</span><div class="m-main"><strong>${esc(m.vehiculo)}</strong><small>${esc(m.tipo)}</small></div><span class="m-date">${fmt(m.fecha)}</span></div>`).join('') || '<span class="muted">No hay mantenimientos programados.</span>'}</div>
          </section>
          <section class="card">
            <div class="card-head">${ic('file')}<h3>Documentos por vencer</h3><span class="spacer"></span><a href="#" data-go="documentos" class="muted" style="font-size:12px">Ver todos</a></div>
            <div class="card-body mini-list">${(d.docs || []).map(x => `<div class="mini-row"><span class="m-ico">${ic('file')}</span><div class="m-main"><strong>${esc(x.titular || '—')}</strong><small>${esc(x.documento)}</small></div><span class="m-date">${fmt(x.vence)}</span></div>`).join('') || '<span class="muted">No hay documentos próximos a vencer.</span>'}</div>
          </section>
        </div>
      </div>`;
    $('#refreshDash').onclick = renderDashboard;
    $('#dashNew').onclick = () => { const first = Object.keys(state.meta.resources).find(k => state.meta.resources[k].crear); if (first) { navigate(first); setTimeout(() => openForm(first), 220); } else toast('No tiene permisos para crear registros.', true); };
    view.querySelectorAll('[data-go]').forEach(a => a.onclick = e => { e.preventDefault(); navigate(a.dataset.go); });
  } catch (e) {
    view.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudo cargar el dashboard</strong><span>${esc(e.message)}</span><button class="btn primary" id="retryDash">Reintentar</button></div>`;
    $('#retryDash').onclick = renderDashboard;
  }
}

/* ---------- Módulos y responsables ---------- */
function renderOwners() {
  crumb(['Administración', 'Módulos y responsables']);
  const groups = buildGroups();
  const owners = Array.isArray(state.meta.owners) && state.meta.owners.length
    ? state.meta.owners
    : groups.map(g => ({ id: g.id, title: g.title, desc: g.desc, responsable: g.owner, modules: g.items }));
  const cards = owners.map(a => {
    const group = groups.find(g => g.id === a.id);
    const modules = (a.modules || []).filter(m => m.key === 'roles' || state.meta.resources[m.key]).map(m => {
      const r = state.meta.resources[m.key] || {};
      const label = m.label || r.label || m.key;
      const resp = m.responsable || r.responsable || a.responsable;
      const actions = Array.isArray(m.acciones) && m.acciones.length ? m.acciones : ['consultar'];
      return `<div class="owner-mod"><div class="om-main"><strong>${esc(label)}</strong><small>${esc(resp)}</small><div class="om-actions">${actions.map(x => `<span>${esc(x)}</span>`).join('')}</div></div><button class="btn ghost sm" data-go="${esc(m.key)}">Abrir</button></div>`;
    }).join('');
    return `<section class="card owner-card">
      <div class="card-head">${ic(group?.icon || 'package')}<h3>${esc(a.title)}</h3><span class="spacer"></span><span class="owner-chip">${ic('user')}${esc(a.responsable)}</span></div>
      <div class="card-body"><p class="muted" style="margin-bottom:12px;font-size:12.5px">${esc(a.desc || '')}</p>${modules || '<span class="muted">Sin módulos disponibles para su rol.</span>'}</div>
    </section>`;
  }).join('');
  $('#view').innerHTML = `<div class="page-head"><div><h1>Módulos y responsables</h1><p>Cada módulo pertenece a un área y tiene un responsable funcional. Se muestran únicamente los módulos permitidos para el rol con el que ingresó.</p></div></div><div class="owner-grid">${cards}</div>`;
  $('#view').querySelectorAll('[data-go]').forEach(b => b.onclick = () => navigate(b.dataset.go));
}

/* ---------- Listados ---------- */
const isNumeric = v => v != null && v !== '' && !isNaN(Number(v)) && !/^\d{4}-\d{2}-\d{2}/.test(String(v));
function renderList(key) {
  const r = state.meta.resources[key];
  if (!r) { $('#view').innerHTML = '<div class="empty"><strong>Módulo no disponible.</strong></div>'; return; }
  crumb([groupNameOf(key), r.label]);
  state.q = '';
  $('#view').innerHTML = `
    <div class="page-head">
      <div><h1>${esc(r.label)}</h1><p>Consulte, registre y administre ${esc(r.label.toLowerCase())}.<span class="owner-chip">${ic('user')}Encargado: ${esc(r.responsable || GROUP_OWNERS[GROUP_MAP[key]] || 'Administrador')}</span></p></div>
      <div class="spacer"></div>
      <div class="head-actions">
        ${r.exportar ? `<button class="btn ghost" id="btnExport">${ic('download')}Exportar Excel</button>` : ''}
        ${r.crear ? `<button class="btn primary" id="btnNew">${ic('plus')}Registrar</button>` : ''}
      </div>
    </div>
    <div class="toolbar">
      <div class="search">${ic('search')}<input id="q" placeholder="Buscar en ${esc(r.label.toLowerCase())}…" autocomplete="off"></div>
      <span class="muted" id="count" style="font-size:12.5px"></span>
    </div>
    <div class="table-card"><div class="table-wrap" id="tableWrap"></div><div class="pager" id="pager"></div></div>`;
  $('#q').oninput = e => {
    state.q = e.target.value.trim();
    state.page = 1;
    clearTimeout(renderList._t);
    renderList._t = setTimeout(loadRows, 300);
  };
  if ($('#btnNew')) $('#btnNew').onclick = () => openForm(key);
  if ($('#btnExport')) $('#btnExport').onclick = () => exportModule(key);
  loadRows();
}
async function loadRows() {
  const key = state.current, r = state.meta.resources[key];
  if (!r) return;
  const req = ++state.request;
  const wrap = $('#tableWrap'), pager = $('#pager');
  wrap.innerHTML = `<div style="padding:18px 16px;display:grid;gap:10px">${Array.from({ length: 7 }, () => '<div class="skel" style="width:' + (55 + Math.random() * 35).toFixed(0) + '%"></div>').join('')}</div>`;
  pager.innerHTML = '';
  try {
    const d = await apiRetry(`/api/r/${key}?pagina=${state.page}&limit=${state.limit}&q=${encodeURIComponent(state.q)}`);
    if (req !== state.request) return;
    $('#count').textContent = `${d.total} registro${d.total === 1 ? '' : 's'}`;
    if (!d.items.length) {
      wrap.innerHTML = `<div class="empty"><span class="big">${ic(state.q ? 'search' : 'package')}</span><strong>${state.q ? 'Ningún resultado' : 'Aún no hay registros'}</strong><span>${state.q ? 'Pruebe con otro término de búsqueda.' : 'Use «Registrar» para crear el primero.'}</span></div>`;
      pager.innerHTML = '';
      return;
    }
    const cols = r.cols;
    wrap.innerHTML = `<table><thead><tr>${cols.map(c => `<th>${esc(c[1])}</th>`).join('')}<th style="text-align:right">Acciones</th></tr></thead><tbody>
      ${d.items.map(x => `<tr data-id="${x.id}">
        ${cols.map(c => {
          const raw = x[c[0]];
          const content = c[2] === 'badge' ? badge(raw) : esc(isNumeric(raw) ? num(raw) : fmt(raw));
          return `<td class="${isNumeric(raw) ? 'num' : ''}">${content}</td>`;
        }).join('')}
        <td><div class="row-actions">
          ${r.editar ? `<button title="Editar" data-edit="${x.id}">${ic('edit')}</button>` : ''}
          ${r.eliminar ? `<button class="del" title="Eliminar" data-del="${x.id}">${ic('trash')}</button>` : ''}
        </div></td></tr>`).join('')}
    </tbody></table>`;
    wrap.querySelectorAll('tbody tr').forEach(tr => {
      tr.onclick = e => {
        if (e.target.closest('button')) return;
        openForm(key, +tr.dataset.id);
      };
    });
    wrap.querySelectorAll('[data-edit]').forEach(b => b.onclick = () => openForm(key, +b.dataset.edit));
    wrap.querySelectorAll('[data-del]').forEach(b => b.onclick = () => confirmDelete(key, +b.dataset.del));
    renderPager(d.total);
  } catch (e) {
    if (req !== state.request) return;
    wrap.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudo cargar</strong><span>${esc(e.message)}</span><button class="btn primary" id="retryRows">Reintentar</button></div>`;
    const b = $('#retryRows'); if (b) b.onclick = loadRows;
  }
}
function renderPager(total) {
  const pages = Math.max(1, Math.ceil(total / state.limit));
  const cur = Math.min(state.page, pages);
  if (state.page > pages) { state.page = pages; loadRows(); return; }
  const nums = [];
  const from = Math.max(1, Math.min(cur - 2, pages - 4));
  const to = Math.min(pages, from + 4);
  for (let i = from; i <= to; i++) nums.push(i);
  $('#pager').innerHTML = `
    <button id="pgPrev" ${cur < 2 ? 'disabled' : ''}>${ic('back', 'sm')} Anterior</button>
    <div class="pages">${nums.map(n => `<button class="${n === cur ? 'on' : ''}" data-p="${n}">${n}</button>`).join('')}</div>
    <span class="spacer"></span>
    <span>Página ${cur} de ${pages} · ${total} registros</span>
    <button id="pgNext" ${cur >= pages ? 'disabled' : ''}>Siguiente ${ic('chevron', 'sm')}</button>`;
  const go = n => { state.page = n; loadRows(); window.scrollTo({ top: 0, behavior: 'smooth' }); };
  $('#pgPrev').onclick = () => cur > 1 && go(cur - 1);
  $('#pgNext').onclick = () => cur < pages && go(cur + 1);
  $$('#pager [data-p]').forEach(b => b.onclick = () => go(+b.dataset.p));
}

/* ---------- Formulario (drawer) ---------- */
function openDrawer() {
  $('#drawer').classList.add('open');
  $('#drawerScrim').classList.add('on');
  document.body.style.overflow = 'hidden';
}
function closeDrawer(force = false) {
  if (!force && state.dirty) {
    if (!confirm('Hay cambios sin guardar. ¿Desea descartarlos?')) return;
  }
  $('#drawer').classList.remove('open');
  $('#drawerScrim').classList.remove('on');
  document.body.style.overflow = '';
  state.dirty = false;
}
$('#drawerScrim') && ($('#drawerScrim').onclick = () => closeDrawer());
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && $('#drawer').classList.contains('open')) closeDrawer();
});

async function openForm(key, id) {
  const r = state.meta.resources[key];
  if (!r) return;
  if (key !== state.current) { state.current = key; }
  state.dirty = false;
  $('#drawerHead').innerHTML = `<div><small>${esc(groupNameOf(key))}</small><h2>${id ? 'Editar' : 'Registrar'} · ${esc(r.label)}</h2></div><button class="icon-btn" id="drawerClose" title="Cerrar">${ic('x')}</button>`;
  $('#drawerBody').innerHTML = '<div style="display:grid;gap:12px;padding-top:8px">' + Array.from({ length: 6 }, () => '<div class="skel" style="height:38px"></div>').join('') + '</div>';
  $('#drawerFoot').innerHTML = '';
  openDrawer();
  $('#drawerClose').onclick = () => closeDrawer();
  try {
    let v = {};
    const [item, catPairs] = await Promise.all([
      id ? api(`/api/r/${key}/${id}`) : Promise.resolve({}),
      Promise.all(r.fields.filter(f => f.cat).map(async f => [f.cat, await getCat(f.cat)]))
    ]);
    v = item || {};
    const cats = Object.fromEntries(catPairs);
    renderForm(key, r, v, cats, id);
  } catch (e) {
    $('#drawerBody').innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudo abrir el formulario</strong><span>${esc(e.message)}</span></div>`;
  }
}
async function getCat(name) {
  if (!state.cats[name]) state.cats[name] = await api(`/api/cat/${name}`);
  return state.cats[name];
}
function dtLocal(val) {
  if (!val) return '';
  const s = String(val);
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(s) && /([zZ]|[+-]\d{2}:?\d{2})$/.test(s)) {
    const d = new Date(s);
    if (!isNaN(d)) {
      const p = n => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
    }
  }
  return s.replace(' ', 'T').slice(0, 16);
}
function fieldControl(f, value) {
  const val = value ?? '';
  const attrs = `name="${esc(f.n)}" id="f_${esc(f.n)}" ${f.req ? 'required' : ''}`;
  if (f.t === 'select') {
    let opts;
    if (f.cat) opts = (state.cats[f.cat] || []).map(x => [x.id, x.nombre]);
    else opts = f.o || [];
    return `<select class="input" ${attrs}><option value="">${f.req ? 'Seleccione…' : '—'}</option>${opts.map(([a, b]) => `<option value="${esc(a)}" ${String(val) === String(a) ? 'selected' : ''}>${esc(b)}</option>`).join('')}</select>`;
  }
  if (f.t === 'textarea') return `<textarea class="input" ${attrs} rows="3" placeholder="${esc(f.l)}">${esc(val)}</textarea>`;
  let type = f.t === 'datetime' ? 'datetime-local' : f.t;
  let v = val;
  if (f.t === 'datetime' && val) v = dtLocal(val);
  return `<input class="input" ${attrs} type="${type}" ${f.t === 'number' ? 'step="any" inputmode="decimal"' : ''} ${f.t === 'password' ? 'autocomplete="new-password" minlength="8"' : ''} value="${esc(v)}">`;
}
function renderForm(key, r, v, cats, id) {
  state.cats = cats;
  const short = /^(text|number|date|datetime|password)$/;
  const fields = r.fields.map(f => {
    const wide = f.t === 'textarea' || f.t === 'password';
    return `<div class="field ${wide ? 'wide' : ''}"><label for="f_${esc(f.n)}">${esc(f.l)}${f.req ? ' <span class="req">*</span>' : ''}</label>${fieldControl(f, v[f.n])}</div>`;
  }).join('');
  $('#drawerBody').innerHTML = `
    <div class="form-grid">
      <div class="form-section">Datos del registro</div>
      ${fields}
    </div>
    ${id && r.eliminar ? `<div class="danger-zone"><button type="button" class="btn danger" id="btnDelete">${ic('trash')}Eliminar registro</button><p class="muted" style="font-size:11.5px;margin-top:6px">El registro quedará dado de baja y no aparecerá en los listados.</p></div>` : ''}`;
  $('#drawerFoot').innerHTML = `<button type="button" class="btn ghost" id="btnCancel">Cancelar</button><span class="spacer"></span><button type="submit" class="btn primary" id="btnSave">${ic('check')}${id ? 'Guardar cambios' : 'Registrar'}</button>`;
  $('#drawerBody').querySelectorAll('input,select,textarea').forEach(el => {
    el.addEventListener('input', () => { state.dirty = true; });
    el.addEventListener('change', () => { state.dirty = true; });
  });
  $('#btnCancel').onclick = () => closeDrawer();
  if ($('#btnDelete')) $('#btnDelete').onclick = () => confirmDelete(key, id);
  $('#drawerForm').onsubmit = async e => {
    e.preventDefault();
    const body = {};
    new FormData($('#drawerForm')).forEach((x, k) => { body[k] = x; });
    const btn = $('#btnSave');
    btn.disabled = true;
    btn.innerHTML = '<span class="skel" style="width:16px;height:16px;border-radius:50%"></span>Guardando…';
    try {
      await api(id ? `/api/r/${key}/${id}` : `/api/r/${key}`, { method: id ? 'PUT' : 'POST', body });
      state.cats = {};
      state.dirty = false;
      closeDrawer(true);
      toast(id ? 'Cambios guardados.' : 'Registro creado.');
      if (state.current === key && !$('#view').querySelector('.empty')) loadRows(); else navigate(key);
    } catch (x) {
      btn.disabled = false;
      btn.innerHTML = ic('check') + (id ? 'Guardar cambios' : 'Registrar');
      toast(x.message, true);
    }
  };
  setTimeout(() => { const first = $('#drawerBody input,#drawerBody select,#drawerBody textarea'); if (first) first.focus(); }, 120);
}

/* ---------- Eliminar ---------- */
function confirmDelete(key, id) {
  const r = state.meta.resources[key] || {};
  const dlg = $('#confirmDlg');
  $('#confirmTitle').textContent = 'Eliminar registro';
  $('#confirmText').textContent = `¿Confirma que desea eliminar este registro de ${r.label || 'la lista'}? Esta acción lo dará de baja.`;
  dlg.showModal();
  const done = ok => { dlg.close(); if (ok) doDelete(key, id); };
  $('#confirmOk').onclick = () => done(true);
  $('#confirmCancel').onclick = () => done(false);
  dlg.oncancel = () => { dlg.close(); };
}
async function doDelete(key, id) {
  try {
    await api(`/api/r/${key}/${id}`, { method: 'DELETE' });
    state.dirty = false;
    closeDrawer(true);
    toast('Registro eliminado.');
    loadRows();
  } catch (e) { toast(e.message, true); }
}

/* ---------- Notificaciones ---------- */
let notifData = [];
let notifFilter = 'todas';
async function renderNotifications() {
  crumb(['Alertas', 'Notificaciones']);
  const view = $('#view');
  view.innerHTML = `<div class="page-head"><div><h1>Notificaciones</h1><p>Alertas generadas a partir de los registros vigentes.</p></div></div><div class="card"><div class="card-body"><div class="skel" style="width:60%"></div></div></div>`;
  try {
    notifData = await apiRetry('/api/notificaciones');
    setBell(notifData.length);
    const filters = ['todas', 'documentos', 'licencias', 'inspecciones', 'incidentes', 'vehículos'];
    const matchType = tipo => {
      const t = String(tipo).toLowerCase();
      if (notifFilter === 'todas') return true;
      if (notifFilter === 'documentos') return t.startsWith('documento');
      if (notifFilter === 'licencias') return t.startsWith('licencia');
      if (notifFilter === 'inspecciones') return t.startsWith('inspecci');
      if (notifFilter === 'incidentes') return t.startsWith('incidente');
      return t.startsWith('vehículo');
    };
    const count = f => {
      if (f === 'todas') return notifData.length;
      const t0 = f === 'documentos' ? 'documento' : f === 'licencias' ? 'licencia' : f === 'inspecciones' ? 'inspecci' : f === 'incidentes' ? 'incidente' : 'vehículo';
      return notifData.filter(n => String(n.tipo).toLowerCase().startsWith(t0)).length;
    };
    const items = notifData.filter(n => matchType(n.tipo));
    view.innerHTML = `
      <div class="page-head"><div><h1>Notificaciones</h1><p>${notifData.length} alertas activas en el sistema.</p></div><div class="spacer"></div><button class="btn ghost" id="refreshNotif">${ic('refresh')}Actualizar</button></div>
      <div class="toolbar" id="notifChips">${filters.map(f => `<button class="btn ${f === notifFilter ? 'primary' : 'ghost'}" data-f="${f}" style="padding:7px 12px;font-size:12.5px">${esc(f[0].toUpperCase() + f.slice(1))} <span style="opacity:.7">${count(f)}</span></button>`).join('')}</div>
      <div class="table-card"><div class="card-body mini-list">${items.length ? items.map(n => {
        const t = String(n.tipo).toLowerCase();
        const icon = t.startsWith('documento') ? 'file' : t.startsWith('licencia') ? 'id-card' : t.startsWith('inspección') ? 'clipboard' : t.startsWith('incidente') ? 'alert' : 'truck';
        const color = t.includes('vencid') ? '#C64747' : t.includes('por vencer') ? '#A98624' : '#447BA8';
        return `<div class="mini-row"><span class="m-ico" style="color:${color}">${ic(icon)}</span><div class="m-main"><strong>${esc(n.detalle)}</strong><small>${esc(n.tipo)}</small></div><span class="m-date">${fmt(n.fecha)}</span></div>`;
      }).join('') : '<div class="empty"><span class="big">' + ic('check') + '</span><strong>Sin alertas en esta categoría</strong><span>Todo en orden por ahora.</span></div>'}</div></div>`;
    $('#refreshNotif').onclick = renderNotifications;
    $$('#notifChips [data-f]').forEach(b => b.onclick = () => { notifFilter = b.dataset.f; renderNotifications(); });
  } catch (e) {
    view.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudieron cargar las alertas</strong><span>${esc(e.message)}</span><button class="btn primary" id="retryNotif">Reintentar</button></div>`;
    $('#retryNotif').onclick = renderNotifications;
  }
}

/* ---------- Exportar (Excel real) ---------- */
async function downloadFile(url, fallbackName) {
  const res = await fetch(url, { headers: { Authorization: 'Bearer ' + state.token }, cache: 'no-store' });
  if (!res.ok) {
    let data = {};
    try { data = await res.json(); } catch { }
    throw new Error(data.error || 'No se pudo generar el archivo.');
  }
  const blob = await res.blob();
  const cd = res.headers.get('Content-Disposition') || '';
  const star = /filename\*=UTF-8''([^;]+)/i.exec(cd);
  const plain = /filename="?([^";]+)"?/i.exec(cd);
  const name = star ? decodeURIComponent(star[1]) : plain ? plain[1] : fallbackName;
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 8000);
  return name;
}
async function exportModule(key) {
  const r = state.meta.resources[key];
  toast('Generando Excel de ' + r.label + '…');
  try {
    const name = await downloadFile(`/api/export/${key}?q=${encodeURIComponent(state.q || '')}`, `SIGFV_${key}.xlsx`);
    toast('Excel generado: ' + name);
  } catch (e) { toast(e.message, true); }
}
async function exportAll() {
  toast('Generando libro con todos los módulos…');
  try {
    const name = await downloadFile('/api/export/all', 'SIGFV_todos.xlsx');
    toast('Libro generado: ' + name);
  } catch (e) { toast(e.message, true); }
}

/* ---------- Mi cuenta ---------- */
function renderAccount() {
  crumb(['Mi cuenta']);
  const s = JSON.parse(sessionStorage.getItem('sigfv_session') || '{}');
  const meta = state.meta;
  const count = (meta.permissions || []).length;
  $('#view').innerHTML = `
    <div class="page-head"><div><h1>Mi cuenta</h1><p>Sesión activa y cambio de contraseña del rol.</p></div></div>
    <div class="dash-grid">
      <div>
        <section class="card" style="margin-bottom:14px">
          <div class="card-head">${ic('user')}<h3>Datos de la sesión</h3></div>
          <div class="card-body mini-list">
            <div class="mini-row"><span class="m-ico">${ic('shield')}</span><div class="m-main"><strong>${esc(meta.roles?.[0] || s.rol || '—')}</strong><small>Rol con el que ingresó</small></div></div>
            <div class="mini-row"><span class="m-ico">${ic('building')}</span><div class="m-main"><strong>${esc(meta.empresa || s.empresa || '—')}</strong><small>Empresa seleccionada</small></div></div>
            <div class="mini-row"><span class="m-ico">${ic('id-card')}</span><div class="m-main"><strong>${esc(meta.user || '—')}</strong><small>Operador registrado en auditoría</small></div></div>
            <div class="mini-row"><span class="m-ico">${ic('check')}</span><div class="m-main"><strong>${count} permisos</strong><small>Módulos y acciones autorizadas</small></div></div>
          </div>
        </section>
        <section class="card">
          <div class="card-head">${ic('key')}<h3>Permisos del rol</h3></div>
          <div class="card-body" style="display:flex;flex-wrap:wrap;gap:6px">
            ${(meta.permissions || []).slice().sort().map(p => `<span class="tag" style="background:#42464B">${esc(p.replace(':', ' · '))}</span>`).join('') || '<span class="muted">Sin permisos asignados.</span>'}
          </div>
        </section>
      </div>
      <div>
        <section class="card">
          <div class="card-head">${ic('key')}<h3>Cambiar contraseña</h3></div>
          <div class="card-body">
            <form id="pwForm">
              <div class="field"><label for="pwActual">Contraseña actual</label><input class="input" id="pwActual" type="password" autocomplete="current-password" required></div>
              <div class="field"><label for="pwNueva">Nueva contraseña</label><input class="input" id="pwNueva" type="password" minlength="8" autocomplete="new-password" required></div>
              <div class="field"><label for="pwRepite">Repetir nueva contraseña</label><input class="input" id="pwRepite" type="password" minlength="8" autocomplete="new-password" required></div>
              <button class="btn primary full" type="submit">${ic('check')}Actualizar contraseña</button>
              <p class="muted" style="font-size:11.5px;margin-top:10px">La contraseña es del rol: todos los que ingresen con este rol usarán la nueva clave.</p>
            </form>
          </div>
        </section>
      </div>
    </div>`;
  $('#pwForm').onsubmit = async e => {
    e.preventDefault();
    const actual = $('#pwActual').value, nueva = $('#pwNueva').value, repite = $('#pwRepite').value;
    if (nueva !== repite) { toast('Las contraseñas nuevas no coinciden.', true); return; }
    try {
      await api('/api/auth/change-password', { method: 'POST', body: { actual, nueva } });
      e.target.reset();
      toast('Contraseña actualizada.');
    } catch (x) { toast(x.message, true); }
  };
}

/* ---------- Roles y permisos ---------- */
function askConfirm(title, text, okLabel = 'Sí, continuar') {
  return new Promise(resolve => {
    const dlg = $('#confirmDlg');
    $('#confirmTitle').textContent = title;
    $('#confirmText').textContent = text;
    $('#confirmOk').textContent = okLabel;
    dlg.showModal();
    const finish = value => { dlg.close(); resolve(value); };
    $('#confirmOk').onclick = () => finish(true);
    $('#confirmCancel').onclick = () => finish(false);
    dlg.oncancel = () => finish(false);
  });
}
async function renderRoles() {
  crumb(['Administración', 'Roles y accesos']);
  const view = $('#view');
  view.innerHTML = '<div class="table-card"><div class="card-body"><div class="skel" style="width:60%"></div></div></div>';
  try {
    const [roles, perms, companies] = await Promise.all([
      api('/api/admin/roles'),
      api('/api/admin/permissions'),
      api('/api/admin/empresas').catch(() => [])
    ]);
    state.rolesCache = roles;
    state.perms = perms;
    state.companyList = companies;
    const open = state.meta.resources.roles || {};
    view.innerHTML = `
      <div class="page-head"><div><h1>Roles y accesos</h1><p>Cada rol define la contraseña de acceso y los módulos que puede usar.</p></div><div class="spacer"></div>
      <div class="head-actions">${open.crear || can('usuarios', 'crear') || can('usuarios', 'editar') ? `<button class="btn primary" id="btnNewRole">${ic('plus')}Nuevo rol</button>` : ''}</div></div>
      <div class="table-card"><div class="table-wrap"><table>
        <thead><tr><th>Rol</th><th>Empresa</th><th>Descripción</th><th>Acceso</th><th>Permisos</th><th style="text-align:right">Acciones</th></tr></thead>
        <tbody>${roles.map(r => `<tr data-role="${r.id}">
          <td><strong>${esc(r.nombre)}</strong></td>
          <td>${r.empresaId ? esc(r.empresa || '—') : '<span class="muted">Todas las empresas</span>'}</td>
          <td>${esc(r.descripcion || '—')}</td>
          <td>${r.tienePassword ? '<span class="tag" style="background:#26865B"><span class="d"></span>Con contraseña</span>' : '<span class="tag" style="background:#A98624"><span class="d"></span>Sin contraseña</span>'}</td>
          <td>${(r.permisos || []).length} acciones</td>
          <td><div class="row-actions">
            ${can('usuarios', 'editar') ? `<button title="Editar" data-edit-role="${r.id}">${ic('edit')}</button>` : ''}
            ${can('usuarios', 'eliminar') && r.id !== 1 ? `<button class="del" title="Desactivar" data-del-role="${r.id}">${ic('trash')}</button>` : ''}
          </div></td></tr>`).join('')}</tbody>
      </table></div></div>`;
    if ($('#btnNewRole')) $('#btnNewRole').onclick = () => openRoleForm();
    view.querySelectorAll('[data-edit-role]').forEach(b => b.onclick = () => openRoleForm(+b.dataset.editRole));
    view.querySelectorAll('[data-del-role]').forEach(b => b.onclick = async () => {
      const role = roles.find(x => x.id === +b.dataset.delRole);
      if (await askConfirm('Desactivar rol', `¿Confirma desactivar el rol «${role.nombre}»? Dejará de poder iniciar sesión.`, 'Sí, desactivar')) {
        try { await api('/api/admin/roles/' + role.id, { method: 'DELETE' }); toast('Rol desactivado.'); renderRoles(); }
        catch (e) { toast(e.message, true); }
      }
    });
  } catch (e) {
    view.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudieron cargar los roles</strong><span>${esc(e.message)}</span></div>`;
  }
}
function openRoleForm(id) {
  const role = id ? state.rolesCache.find(r => r.id === id) : null;
  const companies = state.companyList || [];
  const selected = role ? role.permisos || [] : [];
  const groups = (state.perms || []).map(g => `
    <div class="perm-group">
      <div class="perm-head"><strong>${esc(g.label)}</strong><span class="muted">${esc(g.modulo)}</span></div>
      <div class="perm-actions">${g.acciones.map(a => `<label class="perm-chip"><input type="checkbox" data-perm="${esc(g.modulo)}:${esc(a)}" ${selected.includes(`${g.modulo}:${a}`) ? 'checked' : ''}>${esc(a)}</label>`).join('')}</div>
    </div>`).join('');
  $('#drawerHead').innerHTML = `<div><small>Administración</small><h2>${id ? 'Editar' : 'Nuevo'} rol</h2></div><button class="icon-btn" id="drawerClose" title="Cerrar">${ic('x')}</button>`;
  $('#drawerBody').innerHTML = `
    <div class="form-grid">
      <div class="form-section">Datos del rol</div>
      <div class="field"><label>Nombre del rol</label><input class="input" id="roleNombre" maxlength="60" required value="${esc(role?.nombre || '')}"></div>
      <div class="field"><label>Descripción</label><input class="input" id="roleDesc" maxlength="200" value="${esc(role?.descripcion || '')}"></div>
      <div class="field"><label>Empresa</label><select class="input" id="roleEmpresa"><option value="">Todas las empresas (global)</option>${companies.map(c => `<option value="${c.id}" ${role?.empresaId === c.id ? 'selected' : ''}>${esc(c.razonSocial)}</option>`).join('')}</select></div>
      <div class="field"><label>Contraseña de acceso ${id ? '<span style="font-weight:400;color:#9aa0a6">(dejar vacío para conservar)</span>' : ''}</label><input class="input" id="rolePassword" type="password" minlength="8" autocomplete="new-password" placeholder="Mínimo 8 caracteres"></div>
      <div class="field"><label>Color</label><input class="input" id="roleColor" type="color" value="${esc(role?.color || '#42464B')}" style="padding:4px;height:42px"></div>
      <div class="field"><label>Icono</label><input class="input" id="roleIcono" maxlength="40" value="${esc(role?.icono || 'key')}" placeholder="shield, truck, wrench…"></div>
      <div class="field"><label><input type="checkbox" id="roleActivo" ${role?.activo === false ? '' : 'checked'}> Rol activo</label></div>
      <div class="form-section" style="grid-column:1/-1">Módulos y acciones permitidas</div>
      <div class="perm-grid" style="grid-column:1/-1">${groups || '<span class="muted">Sin permisos disponibles.</span>'}</div>
    </div>`;
  $('#drawerFoot').innerHTML = `<button type="button" class="btn ghost" id="btnCancel">Cancelar</button><span class="spacer"></span><button type="submit" class="btn primary" id="btnSaveRole">${ic('check')}Guardar rol</button>`;
  openDrawer();
  $('#drawerClose').onclick = () => closeDrawer(true);
  $('#btnCancel').onclick = () => closeDrawer(true);
  $('#drawerForm').onsubmit = async e => {
    e.preventDefault();
    const permisos = $$('#drawerBody [data-perm]').filter(x => x.checked).map(x => x.dataset.perm);
    const body = {
      nombre: $('#roleNombre').value.trim(),
      descripcion: $('#roleDesc').value.trim() || null,
      empresaId: $('#roleEmpresa').value ? +$('#roleEmpresa').value : null,
      password: $('#rolePassword').value || null,
      color: $('#roleColor').value,
      icono: $('#roleIcono').value.trim() || null,
      activo: $('#roleActivo').checked,
      permisos
    };
    try {
      await api(id ? '/api/admin/roles/' + id : '/api/admin/roles', { method: id ? 'PUT' : 'POST', body });
      closeDrawer(true);
      toast(id ? 'Rol actualizado.' : 'Rol creado.');
      renderRoles();
    } catch (x) { toast(x.message, true); }
  };
}

/* ---------- Empresas clientes ---------- */
async function renderCompanies() {
  crumb(['Administración', 'Empresas clientes']);
  const view = $('#view');
  view.innerHTML = '<div class="table-card"><div class="card-body"><div class="skel" style="width:60%"></div></div></div>';
  try {
    const companies = await api('/api/admin/empresas');
    state.companyList = companies;
    view.innerHTML = `
      <div class="page-head"><div><h1>Empresas clientes</h1><p>Empresas que contratan el servicio, sus módulos, vehículos, conductores y requerimientos.</p></div><div class="spacer"></div>
      <div class="head-actions">${can('configuracion', 'crear') ? `<button class="btn primary" id="btnNewCompany">${ic('plus')}Registrar empresa</button>` : ''}</div></div>
      <div class="table-card"><div class="table-wrap"><table>
        <thead><tr><th>Empresa</th><th>RUC</th><th>Unidades</th><th>Vehículos</th><th>Conductores</th><th>Estado</th><th style="text-align:right">Acciones</th></tr></thead>
        <tbody>${companies.map(c => `<tr data-company="${c.id}">
          <td><strong>${esc(c.razonSocial)}</strong></td>
          <td>${esc(c.ruc || '—')}</td>
          <td class="num">${c.unidades}</td><td class="num">${c.vehiculos}</td><td class="num">${c.conductores}</td>
          <td>${c.activo ? '<span class="tag" style="background:#26865B"><span class="d"></span>Activa</span>' : '<span class="tag" style="background:#C64747"><span class="d"></span>Inactiva</span>'}</td>
          <td><div class="row-actions"><button title="Ver detalle" data-view="${c.id}">${ic('chevron')}</button>
          ${can('configuracion', 'editar') ? `<button title="Editar" data-edit-company="${c.id}">${ic('edit')}</button>` : ''}</div></td></tr>`).join('') || '<tr><td colspan="7"><div class="empty"><strong>Sin empresas registradas</strong><span>Registre la primera empresa cliente.</span></div></td></tr>'}</tbody>
      </table></div></div>`;
    if ($('#btnNewCompany')) $('#btnNewCompany').onclick = () => openCompanyForm();
    view.querySelectorAll('[data-view]').forEach(b => b.onclick = e => { e.stopPropagation(); navigate('empresa/' + b.dataset.view); });
    view.querySelectorAll('[data-edit-company]').forEach(b => b.onclick = e => { e.stopPropagation(); openCompanyForm(+b.dataset.editCompany); });
    view.querySelectorAll('[data-company]').forEach(tr => tr.onclick = () => navigate('empresa/' + tr.dataset.company));
  } catch (e) {
    view.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudieron cargar las empresas</strong><span>${esc(e.message)}</span></div>`;
  }
}
async function renderCompany(id) {
  crumb(['Empresas clientes', 'Detalle']);
  const view = $('#view');
  view.innerHTML = '<div class="card"><div class="card-body"><div class="skel" style="width:60%"></div></div></div>';
  try {
    const d = await api('/api/admin/empresas/' + id);
    state.companyDetail = d;
    const e = d.empresa || {};
    const r = d.resumen || {};
    const roles = d.roles || [];
    view.innerHTML = `
      <div class="page-head">
        <button class="btn ghost" id="backCompanies">${ic('back')}Volver</button>
        <div><h1>${esc(e.razon_social || e.razonSocial || 'Empresa')}</h1><p>RUC ${esc(e.ruc || '—')} · ${e.activo === false ? 'Inactiva' : 'Activa'}${e.contacto ? ' · Contacto: ' + esc(e.contacto) : ''}</p></div>
        <div class="spacer"></div>
        <div class="head-actions">${can('configuracion', 'editar') ? `<button class="btn primary" id="editCompany">${ic('edit')}Editar empresa</button>` : ''}</div>
      </div>
      <div class="kpis">
        <article class="kpi gold"><div class="k-top"><span>Unidades mineras</span><span class="k-ico">${ic('map')}</span></div><strong>${r.unidades ?? 0}</strong><small>sedes registradas</small></article>
        <article class="kpi ok"><div class="k-top"><span>Vehículos</span><span class="k-ico">${ic('truck')}</span></div><strong>${r.vehiculos ?? 0}</strong><small>en la flota</small></article>
        <article class="kpi info"><div class="k-top"><span>Conductores</span><span class="k-ico">${ic('id-card')}</span></div><strong>${r.conductores ?? 0}</strong><small>registrados</small></article>
        <article class="kpi warn"><div class="k-top"><span>Docs. por vencer</span><span class="k-ico">${ic('file')}</span></div><strong>${r.documentosPorVencer ?? 0}</strong><small>próximos 30 días</small></article>
      </div>
      <div class="dash-grid">
        <div>
          <section class="card" style="margin-bottom:14px">
            <div class="card-head">${ic('truck')}<h3>Vehículos</h3><span class="spacer"></span><span class="muted" style="font-size:12px">${(d.vehiculos || []).length} unidades</span></div>
            <div class="table-wrap"><table><thead><tr><th>Código</th><th>Placa</th><th>Modelo</th><th>Km</th><th>Estado</th></tr></thead><tbody>
              ${(d.vehiculos || []).map(v => `<tr><td><strong>${esc(v.codigo)}</strong></td><td>${esc(v.placa || '—')}</td><td>${esc(v.modelo || '—')}</td><td class="num">${num(v.km)}</td><td>${badge(v.estado)}</td></tr>`).join('') || '<tr><td colspan="5"><span class="muted">Sin vehículos.</span></td></tr>'}
            </tbody></table></div>
          </section>
          <section class="card">
            <div class="card-head">${ic('id-card')}<h3>Conductores</h3><span class="spacer"></span><span class="muted" style="font-size:12px">${(d.conductores || []).length} personas</span></div>
            <div class="table-wrap"><table><thead><tr><th>Nombre</th><th>Documento</th><th>Teléfono</th><th>Unidad</th><th>Estado</th></tr></thead><tbody>
              ${(d.conductores || []).map(c => `<tr><td><strong>${esc(c.nombre)}</strong></td><td>${esc(c.documento || '—')}</td><td>${esc(c.telefono || '—')}</td><td>${esc(c.unidad || '—')}</td><td>${badge(c.estado)}</td></tr>`).join('') || '<tr><td colspan="5"><span class="muted">Sin conductores.</span></td></tr>'}
            </tbody></table></div>
          </section>
        </div>
        <div>
          <section class="card" style="margin-bottom:14px">
            <div class="card-head">${ic('key')}<h3>Módulos y roles</h3></div>
            <div class="card-body mini-list">
              ${roles.map(x => `<div class="mini-row"><span class="m-ico" style="color:${esc(x.color || '#42464B')}">${ic(x.global ? 'shield' : 'key')}</span><div class="m-main"><strong>${esc(x.nombre)}</strong><small>${(x.permisos || []).length} permisos${x.global ? ' · rol global' : ''}${x.tienePassword ? '' : ' · sin contraseña'}</small></div></div>`).join('') || '<span class="muted">Sin roles asignados.</span>'}
            </div>
          </section>
          <section class="card" style="margin-bottom:14px">
            <div class="card-head">${ic('package')}<h3>Requerimientos</h3></div>
            <div class="card-body">${(d.requerimientos || []).length ? `<ul style="margin:0;padding-left:18px;font-size:13px;display:grid;gap:6px">${d.requerimientos.map(x => `<li>${esc(x)}</li>`).join('')}</ul>` : '<span class="muted">Sin requerimientos registrados. Use «Editar empresa» y escriba uno por línea.</span>'}</div>
          </section>
          <section class="card">
            <div class="card-head">${ic('map')}<h3>Unidades mineras</h3></div>
            <div class="card-body mini-list">${(d.unidades || []).map(u => `<div class="mini-row"><span class="m-ico">${ic('map')}</span><div class="m-main"><strong>${esc(u.nombre)}</strong><small>${esc(u.codigo || '')} ${esc(u.ubicacion || '')}</small></div></div>`).join('') || '<span class="muted">Sin unidades.</span>'}</div>
          </section>
        </div>
      </div>`;
    $('#backCompanies').onclick = () => navigate('empresas');
    if ($('#editCompany')) $('#editCompany').onclick = () => openCompanyForm(id);
  } catch (e) {
    view.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudo cargar la empresa</strong><span>${esc(e.message)}</span><button class="btn primary" id="backCompanies2">Volver</button></div>`;
    $('#backCompanies2').onclick = () => navigate('empresas');
  }
}
async function openCompanyForm(id) {
  let company = {};
  if (id) {
    try {
      const d = await api('/api/admin/empresas/' + id);
      company = d.empresa || {};
    } catch (e) { toast(e.message, true); return; }
  }
  $('#drawerHead').innerHTML = `<div><small>Empresas clientes</small><h2>${id ? 'Editar' : 'Registrar'} empresa</h2></div><button class="icon-btn" id="drawerClose" title="Cerrar">${ic('x')}</button>`;
  $('#drawerBody').innerHTML = `
    <div class="form-grid">
      <div class="form-section">Datos de la empresa</div>
      <div class="field wide"><label>Razón social <span class="req">*</span></label><input class="input" id="coName" required maxlength="200" value="${esc(company.razon_social || '')}" placeholder="Compañía Minera … S.A.C."></div>
      <div class="field"><label>RUC</label><input class="input" id="coRuc" maxlength="20" value="${esc(company.ruc || '')}" placeholder="20512345678"></div>
      <div class="field"><label>Contacto</label><input class="input" id="coContacto" maxlength="120" value="${esc(company.contacto || '')}" placeholder="Nombre del contacto"></div>
      <div class="field"><label>Teléfono</label><input class="input" id="coTelefono" maxlength="40" value="${esc(company.telefono || '')}"></div>
      <div class="field"><label>Correo</label><input class="input" id="coCorreo" type="email" maxlength="120" value="${esc(company.correo || '')}"></div>
      <div class="field wide"><label>Dirección</label><input class="input" id="coDireccion" maxlength="200" value="${esc(company.direccion || '')}"></div>
      <div class="field wide"><label>Requerimientos y alcance del servicio</label><textarea class="input" id="coNotas" rows="5" placeholder="Un requerimiento por línea&#10;Ej. Control de documentos de conductores&#10;Ej. Reporte mensual de combustible">${esc(company.notas || '')}</textarea><small class="muted" style="font-size:11px">Escriba un requerimiento por línea; se mostrarán en el detalle de la empresa.</small></div>
      <div class="field"><label><input type="checkbox" id="coActivo" ${company.activo === false ? '' : 'checked'}> Empresa activa</label></div>
    </div>`;
  $('#drawerFoot').innerHTML = `<button type="button" class="btn ghost" id="btnCancel">Cancelar</button><span class="spacer"></span><button type="submit" class="btn primary" id="btnSaveCompany">${ic('check')}${id ? 'Guardar cambios' : 'Registrar empresa'}</button>`;
  openDrawer();
  $('#drawerClose').onclick = () => closeDrawer(true);
  $('#btnCancel').onclick = () => closeDrawer(true);
  $('#drawerForm').onsubmit = async e => {
    e.preventDefault();
    const body = {
      razonSocial: $('#coName').value.trim(),
      ruc: $('#coRuc').value.trim(),
      contacto: $('#coContacto').value.trim(),
      telefono: $('#coTelefono').value.trim(),
      correo: $('#coCorreo').value.trim(),
      direccion: $('#coDireccion').value.trim(),
      notas: $('#coNotas').value,
      activo: $('#coActivo').checked
    };
    try {
      const saved = await api(id ? '/api/admin/empresas/' + id : '/api/admin/empresas', { method: id ? 'PUT' : 'POST', body });
      closeDrawer(true);
      toast(id ? 'Empresa actualizada.' : 'Empresa registrada.');
      if (id) renderCompany(id); else navigate('empresa/' + saved.id);
    } catch (x) { toast(x.message, true); }
  };
}

/* ---------- Auditoría ---------- */
async function renderAudit() {
  crumb(['Administración', 'Auditoría']);
  const view = $('#view');
  view.innerHTML = '<div class="table-card"><div class="card-body"><div class="skel" style="width:60%"></div></div></div>';
  try {
    const rows = await api('/api/admin/auditoria?limit=200');
    view.innerHTML = `
      <div class="page-head"><div><h1>Auditoría</h1><p>Últimos ${rows.length} movimientos registrados por los usuarios y roles.</p></div><div class="spacer"></div>
      <div class="head-actions"><button class="btn ghost" id="refreshAudit">${ic('refresh')}Actualizar</button></div></div>
      <div class="table-card"><div class="table-wrap"><table>
        <thead><tr><th>Fecha</th><th>Usuario</th><th>Acción</th><th>Entidad</th><th>Registro</th><th>IP</th></tr></thead>
        <tbody>${rows.map(a => `<tr><td>${fmt(a.fecha)}</td><td>${esc(a.usuario)}</td><td>${badge(a.accion)}</td><td>${esc(a.entidad)}</td><td>#${esc(a.entidad_id || '—')}</td><td>${esc(a.ip || '—')}</td></tr>`).join('') || '<tr><td colspan="6"><div class="empty"><strong>Sin movimientos</strong></div></td></tr>'}</tbody>
      </table></div></div>`;
    $('#refreshAudit').onclick = renderAudit;
  } catch (e) {
    view.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudo cargar la auditoría</strong><span>${esc(e.message)}</span></div>`;
  }
}

/* ---------- Registro público de empresas (2.4) ---------- */
let regCtx = null;
const regState = { rows: 0 };
const regVal = (id) => ($(id) ? $(id).value.trim() : '');

async function openRegistro() {
  $('#registro').classList.remove('hidden');
  document.body.style.overflow = 'hidden';
  $('#regError').textContent = '';
  $('#regSuccess').classList.add('hidden');
  $('#regForm').classList.remove('hidden');
  if (!regCtx) {
    try {
      regCtx = await api('/api/public/registro/opciones');
      if (!regCtx || !regCtx.tipos) regCtx = { tipos: [], categorias: [], requisitos: [] };
    } catch (e) {
      regCtx = { tipos: [], categorias: [], requisitos: [] };
      $('#regError').textContent = 'No se pudieron cargar los catálogos. Verifique su conexión.';
    }
  }
  $('#regRequisitos').innerHTML = (regCtx.requisitos || []).map(r => `<li>${ic('check')}<span>${esc(r)}</span></li>`).join('');
  if (!regState.rows) addRegRow();
  setTimeout(() => $('#regRuc') && $('#regRuc').focus(), 120);
}
function closeRegistro() {
  $('#registro').classList.add('hidden');
  document.body.style.overflow = '';
}
function renumberRegRows() {
  $$('#regRows .reg-veh').forEach((el, i) => {
    const t = el.querySelector('.reg-veh-head strong');
    if (t) t.textContent = 'Vehículo ' + (i + 1);
  });
}
function addRegRow() {
  if (regState.rows >= 10) { toast('Puede agregar hasta 10 pedidos de vehículos.', true); return; }
  regState.rows++;
  const tipos = (regCtx?.tipos || []).map(t => `<option value="${t.id}">${esc(t.nombre)}</option>`).join('');
  const cats = (regCtx?.categorias || []).map(c => `<option value="${c.id}">${esc(c.nombre)}</option>`).join('');
  const wrap = document.createElement('div');
  wrap.className = 'reg-veh';
  wrap.innerHTML = `
    <div class="reg-veh-head"><strong>Vehículo ${regState.rows}</strong><button type="button" class="icon-btn" data-del-row title="Quitar">${ic('trash')}</button></div>
    <div class="reg-veh-grid">
      <div class="field"><label>Tipo de vehículo <span class="req">*</span></label><select class="input" data-f="tipo"><option value="">Seleccione…</option>${tipos}</select></div>
      <div class="field"><label>Categoría</label><select class="input" data-f="categoria"><option value="">Cualquiera</option>${cats}</select></div>
      <div class="field"><label>Cantidad</label><input class="input" data-f="cantidad" type="number" min="1" max="50" value="1"></div>
      <div class="field"><label>Desde</label><input class="input" data-f="inicio" type="date"></div>
      <div class="field"><label>Hasta</label><input class="input" data-f="fin" type="date"></div>
      <label class="reg-check wide"><input type="checkbox" data-f="conductor"> Requiere conductor</label>
      <div class="field wide"><label>Detalles del servicio</label><input class="input" data-f="detalles" maxlength="500" placeholder="Ruta, turno, horario o condiciones especiales"></div>
    </div>`;
  $('#regRows').appendChild(wrap);
  wrap.querySelector('[data-del-row]').onclick = () => {
    if ($$('#regRows .reg-veh').length === 1) { toast('Debe registrar al menos un vehículo.', true); return; }
    wrap.remove();
    renumberRegRows();
  };
}
function collectRegVehiculos() {
  return $$('#regRows .reg-veh').map(el => {
    const val = f => el.querySelector(`[data-f="${f}"]`);
    return {
      tipoVehiculoId: Number(val('tipo').value || 0) || null,
      categoriaVehiculoId: Number(val('categoria').value || 0) || null,
      cantidad: Number(val('cantidad').value || 1),
      fechaInicio: val('inicio').value || null,
      fechaFin: val('fin').value || null,
      requiereConductor: !!(val('conductor') && val('conductor').checked),
      detalles: val('detalles').value.trim() || null
    };
  });
}
async function submitRegistro(e) {
  e.preventDefault();
  const err = $('#regError');
  err.textContent = '';
  const body = {
    ruc: regVal('#regRuc').replace(/\D/g, ''),
    razonSocial: regVal('#regRazon'),
    contacto: regVal('#regContacto'),
    cargo: regVal('#regCargo'),
    telefono: regVal('#regTelefono'),
    correo: regVal('#regCorreo'),
    direccion: regVal('#regDireccion'),
    actividad: regVal('#regActividad'),
    unidadSolicitada: regVal('#regUnidad'),
    requisitos: regVal('#regRequisitosTexto'),
    observaciones: regVal('#regObservaciones'),
    website: regVal('#regWebsite'),
    origen: 'web',
    vehiculos: collectRegVehiculos()
  };
  if (body.ruc.length !== 11) { err.textContent = 'Ingrese un RUC válido de 11 dígitos.'; return; }
  if (body.razonSocial.length < 3) { err.textContent = 'Ingrese la razón social de la empresa.'; return; }
  if (body.contacto.length < 3) { err.textContent = 'Ingrese la persona de contacto.'; return; }
  if (body.telefono.replace(/\D/g, '').length < 6) { err.textContent = 'Ingrese un teléfono válido.'; return; }
  if (!/^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$/.test(body.correo)) { err.textContent = 'Ingrese un correo electrónico válido.'; return; }
  if (body.requisitos.length < 10) { err.textContent = 'Describa los requisitos o el servicio que necesita.'; return; }
  if (!body.vehiculos.length) { err.textContent = 'Agregue al menos un vehículo.'; return; }
  const sinTipo = body.vehiculos.findIndex(v => !v.tipoVehiculoId);
  if (sinTipo >= 0) { err.textContent = `Seleccione el tipo de vehículo en el pedido ${sinTipo + 1}.`; return; }
  const malas = body.vehiculos.find(v => v.fechaInicio && v.fechaFin && v.fechaFin < v.fechaInicio);
  if (malas) { err.textContent = 'La fecha final no puede ser anterior a la fecha de inicio.'; return; }

  const btn = $('#regSubmit');
  btn.disabled = true;
  btn.textContent = 'Enviando solicitud…';
  try {
    const r = await api('/api/public/solicitudes', { method: 'POST', body, timeout: 45000 });
    $('#regForm').classList.add('hidden');
    $('#regSuccess').classList.remove('hidden');
    $('#regCode').textContent = r.codigo || ('#' + r.id);
    $('#regForm').reset();
    $('#regRows').innerHTML = '';
    regState.rows = 0;
  } catch (x) {
    err.textContent = x.message;
  } finally {
    btn.disabled = false;
    btn.textContent = 'Enviar solicitud';
  }
}

/* ---------- Bandeja de solicitudes (administrador) ---------- */
const solState = { estado: 'pendiente', q: '', items: [] };

function renderSolicitudes() {
  crumb(['Administración', 'Solicitudes de empresas']);
  solState.q = '';
  const chips = [['pendiente', 'Pendientes'], ['aprobada', 'Aprobadas'], ['rechazada', 'Rechazadas'], ['', 'Todas']];
  $('#view').innerHTML = `
    <div class="page-head">
      <div><h1>Solicitudes de empresas</h1><p>Revise el registro de clientes, los requisitos y los vehículos pedidos.<span class="owner-chip">${ic('user')}Encargado: Administrador</span></p></div>
      <div class="spacer"></div>
      <div class="head-actions"><button class="btn ghost" id="solRefresh">${ic('refresh')}Actualizar</button></div>
    </div>
    <div class="toolbar">
      <div class="sol-chips" id="solChips">${chips.map(([e, l]) => `<button class="chip ${solState.estado === e ? 'on' : ''}" data-e="${e}">${l}</button>`).join('')}</div>
      <div class="search">${ic('search')}<input id="solQ" placeholder="Buscar por RUC, empresa, código o contacto…" autocomplete="off"></div>
      <span class="muted" id="solCount" style="font-size:12.5px"></span>
    </div>
    <div class="table-card"><div class="table-wrap" id="solWrap"></div></div>`;
  $$('#solChips [data-e]').forEach(b => b.onclick = () => {
    solState.estado = b.dataset.e;
    $$('#solChips .chip').forEach(x => x.classList.toggle('on', x === b));
    loadSolicitudes();
  });
  $('#solQ').oninput = e => {
    solState.q = e.target.value.trim();
    clearTimeout(renderSolicitudes._t);
    renderSolicitudes._t = setTimeout(loadSolicitudes, 320);
  };
  $('#solRefresh').onclick = loadSolicitudes;
  loadSolicitudes();
}
async function loadSolicitudes() {
  const wrap = $('#solWrap');
  if (!wrap) return;
  wrap.innerHTML = `<div style="padding:18px 16px;display:grid;gap:10px">${Array.from({ length: 6 }, () => '<div class="skel" style="width:' + (50 + Math.random() * 40).toFixed(0) + '%"></div>').join('')}</div>`;
  try {
    const rows = await api(`/api/solicitudes?estado=${encodeURIComponent(solState.estado)}&q=${encodeURIComponent(solState.q)}`);
    solState.items = rows || [];
    $('#solCount').textContent = `${solState.items.length} solicitud${solState.items.length === 1 ? '' : 'es'}`;
    if (!solState.items.length) {
      wrap.innerHTML = `<div class="empty"><span class="big">${ic('building')}</span><strong>No hay solicitudes ${solState.estado ? 'en este estado' : 'registradas'}</strong><span>Las empresas pueden registrarse desde la pantalla de acceso o desde la APK.</span></div>`;
      return;
    }
    wrap.innerHTML = `<table><thead><tr><th>Código</th><th>Empresa</th><th>RUC</th><th>Contacto</th><th>Vehículos</th><th>Estado</th><th>Registrada</th><th style="text-align:right">Acciones</th></tr></thead><tbody>
      ${solState.items.map(s => `<tr data-sol="${s.id}">
        <td><strong>${esc(s.codigo)}</strong><br><small class="muted">${esc(s.origen || 'web')}</small></td>
        <td><strong>${esc(s.razon_social)}</strong><br><small class="muted">${esc(s.unidad_solicitada || '—')}</small></td>
        <td>${esc(s.ruc)}</td>
        <td>${esc(s.contacto)}<br><small class="muted">${esc(s.telefono)} · ${esc(s.correo)}</small></td>
        <td>${Number(s.unidades || 0)} pedido(s)<br><small class="muted">${Number(s.asignados || 0)} asignado(s)</small></td>
        <td>${badge(s.estado)}</td>
        <td>${fmt(s.creado_en)}</td>
        <td><div class="row-actions"><button title="Revisar solicitud" data-review="${s.id}">${ic('eye')}</button></div></td>
      </tr>`).join('')}</tbody></table>`;
    wrap.querySelectorAll('tbody tr').forEach(tr => tr.onclick = e => {
      if (e.target.closest('button')) return;
      openSolicitud(+tr.dataset.sol);
    });
    wrap.querySelectorAll('[data-review]').forEach(b => b.onclick = () => openSolicitud(+b.dataset.review));
  } catch (e) {
    wrap.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudieron cargar las solicitudes</strong><span>${esc(e.message)}</span><button class="btn ghost" id="solRetry">Reintentar</button></div>`;
    const b = $('#solRetry'); if (b) b.onclick = loadSolicitudes;
  }
}
async function refreshMetaPendientes() {
  try {
    state.meta = await apiRetry('/api/meta');
    renderNav();
  } catch { }
}
async function openSolicitud(id) {
  state.dirty = false;
  $('#drawerHead').innerHTML = `<div><small>Solicitud de empresa</small><h2>Revisando solicitud…</h2></div><button class="icon-btn" id="drawerClose" title="Cerrar">${ic('x')}</button>`;
  $('#drawerBody').innerHTML = '<div style="display:grid;gap:12px;padding-top:8px">' + Array.from({ length: 6 }, () => '<div class="skel" style="height:38px"></div>').join('') + '</div>';
  $('#drawerFoot').innerHTML = '';
  openDrawer();
  $('#drawerClose').onclick = () => closeDrawer();
  try {
    const [s, asignables] = await Promise.all([
      api('/api/solicitudes/' + id),
      api('/api/solicitudes/asignables').catch(() => ({ vehiculos: [], conductores: [] }))
    ]);
    renderSolicitudDetail(s, asignables || { vehiculos: [], conductores: [] });
  } catch (e) {
    $('#drawerBody').innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudo abrir la solicitud</strong><span>${esc(e.message)}</span></div>`;
  }
}
function renderSolicitudDetail(s, asignables) {
  const pendiente = String(s.estado) === 'pendiente';
  const editable = pendiente && can('configuracion', 'editar');
  const items = s.items || [];
  $('#drawerHead').innerHTML = `<div><small>${esc(s.codigo)} · ${fmt(s.creado_en)}</small><h2>${esc(s.razon_social)}</h2><div style="margin-top:7px">${badge(s.estado)}</div></div><button class="icon-btn" id="drawerClose" title="Cerrar">${ic('x')}</button>`;
  $('#drawerClose').onclick = () => closeDrawer();

  const vehOpts = (asignables.vehiculos || []).map(v => `<option value="${v.id}">${esc(v.codigo_interno)}${v.placa ? ' · ' + esc(v.placa) : ''}${v.estado ? ' · ' + esc(v.estado) : ''}</option>`).join('');
  const condOpts = (asignables.conductores || []).map(c => `<option value="${c.id}">${esc(c.apellidos + ', ' + c.nombres)}${c.licencia_vence ? ' · licencia hasta ' + esc(c.licencia_vence) : ' · sin licencia'}</option>`).join('');

  const itemHtml = items.map(it => {
    const asignado = it.vehiculo_id
      ? `<div class="sol-assigned">${ic('truck')}${esc(it.vehiculo_codigo || 'Vehículo')}${it.vehiculo_placa ? ' · ' + esc(it.vehiculo_placa) : ''}${it.conductor ? ' · ' + esc(it.conductor) : ''}</div>`
      : (pendiente ? '' : '<div class="sol-assigned muted">Sin vehículo asignado</div>');
    const form = editable ? `<div class="sol-assign">
      <div class="field"><label>Vehículo a asignar</label><select class="input sol-veh"><option value="">— Sin asignar —</option>${vehOpts}</select></div>
      <div class="field"><label>Conductor</label><select class="input sol-cond"><option value="">— Sin conductor —</option>${condOpts}</select></div>
    </div>` : asignado;
    return `<div class="sol-item" data-item="${it.id}">
      <div class="sol-item-head"><strong>${esc(it.tipo || 'Vehículo')}${it.categoria ? ' · ' + esc(it.categoria) : ''}</strong>${badge(it.estado)}</div>
      <div class="sol-item-meta">
        <span><b>Cantidad:</b> ${it.cantidad ?? 1}</span>
        <span><b>Desde:</b> ${fmt(it.fecha_inicio)}</span>
        <span><b>Hasta:</b> ${fmt(it.fecha_fin)}</span>
        <span><b>Conductor:</b> ${it.requiere_conductor ? 'Sí' : 'No'}</span>
      </div>
      ${it.detalles ? `<p class="sol-note">${esc(it.detalles)}</p>` : ''}
      ${form}
    </div>`;
  }).join('') || '<div class="empty"><strong>Sin vehículos registrados</strong></div>';

  $('#drawerBody').innerHTML = `
    <section class="sol-block">
      <h3>${ic('building')}Datos de la empresa</h3>
      <div class="sol-grid">
        <div><small>RUC</small><strong>${esc(s.ruc)}</strong></div>
        <div><small>Contacto</small><strong>${esc(s.contacto)}${s.cargo ? ' · ' + esc(s.cargo) : ''}</strong></div>
        <div><small>Teléfono</small><strong>${esc(s.telefono)}</strong></div>
        <div><small>Correo</small><strong>${esc(s.correo)}</strong></div>
        <div class="wide"><small>Dirección</small><strong>${esc(s.direccion || '—')}</strong></div>
        <div><small>Actividad</small><strong>${esc(s.actividad || '—')}</strong></div>
        <div><small>Unidad solicitada</small><strong>${esc(s.unidad_solicitada || '—')}</strong></div>
        <div><small>Origen</small><strong>${esc(s.origen || 'web')}</strong></div>
      </div>
    </section>
    <section class="sol-block">
      <h3>${ic('clipboard')}Requisitos y alcance</h3>
      <p class="sol-text">${esc(s.requisitos || '—')}</p>
      ${s.observaciones ? `<p class="sol-text muted"><b>Observaciones:</b> ${esc(s.observaciones)}</p>` : ''}
      ${s.respuesta_admin ? `<p class="sol-text"><b>Respuesta del administrador:</b> ${esc(s.respuesta_admin)}</p>` : ''}
    </section>
    <section class="sol-block">
      <h3>${ic('truck')}Vehículos solicitados (${items.length})</h3>
      ${itemHtml}
    </section>
    ${editable ? `<section class="sol-block">
      <h3>${ic('check')}Aprobación y asignación</h3>
      <div class="field"><label>Unidad minera del cliente</label><input class="input" id="solUnidad" maxlength="150" value="${esc(s.unidad_solicitada || s.razon_social)}"></div>
      <div class="field"><label>Observación para la empresa</label><textarea class="input" id="solObs" rows="3" maxlength="1000" placeholder="Condiciones de la asignación, disponibilidad o motivo del rechazo.">${esc(s.respuesta_admin || '')}</textarea></div>
      <p class="muted" style="font-size:11.5px">Al aprobar se crea la empresa por RUC, su unidad minera, se reasignan los vehículos y se registra la asignación en la base de datos.</p>
    </section>` : ''}`;

  if (editable) {
    // Preseleccionar el vehículo/conductor ya guardado, si existe.
    $$('#drawerBody .sol-item').forEach(card => {
      const item = items.find(x => String(x.id) === card.dataset.item);
      if (!item) return;
      const v = card.querySelector('.sol-veh'), c = card.querySelector('.sol-cond');
      if (v && item.vehiculo_id) v.value = String(item.vehiculo_id);
      if (c && item.conductor_id) c.value = String(item.conductor_id);
    });
    $('#drawerFoot').innerHTML = `<button class="btn ghost" id="solReject">${ic('x')}Rechazar</button><div class="spacer"></div><button class="btn primary" id="solApprove">${ic('check')}Aprobar y asignar</button>`;
    $('#solApprove').onclick = () => approveSolicitud(s, items);
    $('#solReject').onclick = () => rejectSolicitud(s);
  } else {
    $('#drawerFoot').innerHTML = `<div class="spacer"></div><button class="btn ghost" id="solClose">Cerrar</button>`;
    $('#solClose').onclick = () => closeDrawer();
  }
}
async function approveSolicitud(s, items) {
  const pedidos = $$('#drawerBody .sol-item').map(card => {
    const v = card.querySelector('.sol-veh');
    const c = card.querySelector('.sol-cond');
    return { itemId: +card.dataset.item, vehiculoId: v && v.value ? +v.value : null, conductorId: c && c.value ? +c.value : null };
  }).filter(x => x.vehiculoId);
  const vistos = new Set();
  for (const x of pedidos) {
    if (vistos.has(x.vehiculoId)) { toast('Un mismo vehículo no puede asignarse a dos pedidos.', true); return; }
    vistos.add(x.vehiculoId);
  }
  const unidadNombre = ($('#solUnidad')?.value || '').trim();
  const observacion = ($('#solObs')?.value || '').trim();
  if (!pedidos.length) {
    if (!(await askConfirm('Aprobar sin vehículos', 'No seleccionó vehículos. La empresa quedará registrada y los pedidos sin asignar. ¿Desea continuar?', 'Sí, aprobar'))) return;
  }
  const btn = $('#solApprove');
  btn.disabled = true;
  btn.textContent = 'Aprobando…';
  try {
    const r = await api(`/api/solicitudes/${s.id}/aprobar`, {
      method: 'POST',
      body: { observacion, unidadNombre, items: pedidos },
      timeout: 60000
    });
    closeDrawer(true);
    toast(`Solicitud ${r.codigo || s.codigo} aprobada. ${r.asignados || 0} vehículo(s) asignado(s).`);
    await refreshMetaPendientes();
    loadSolicitudes();
  } catch (e) {
    toast(e.message, true);
  } finally {
    btn.disabled = false;
    btn.innerHTML = `${ic('check')}Aprobar y asignar`;
  }
}
async function rejectSolicitud(s) {
  const motivo = ($('#solObs')?.value || '').trim();
  if (motivo.length < 5) { toast('Escriba el motivo del rechazo en Observaciones.', true); return; }
  if (!(await askConfirm('Rechazar solicitud', `Se rechazará la solicitud de «${s.razon_social}» y se guardará el motivo para la empresa.`, 'Sí, rechazar'))) return;
  const btn = $('#solReject');
  btn.disabled = true;
  try {
    await api(`/api/solicitudes/${s.id}/rechazar`, { method: 'POST', body: { observacion: motivo } });
    closeDrawer(true);
    toast('Solicitud rechazada.');
    await refreshMetaPendientes();
    loadSolicitudes();
  } catch (e) {
    toast(e.message, true);
    btn.disabled = false;
  }
}

/* ---------- Arranque ---------- */
$('#empresa').onchange = () => { $('#loginError').textContent = ''; fillRoles(); };
$('#reloadCtx').onclick = async e => {
  e.preventDefault();
  const link = $('#reloadCtx');
  link.textContent = 'Actualizando…';
  try { await loadContext(true); toast('Empresas y roles actualizados.'); }
  catch (x) { $('#loginError').textContent = x.message; }
  finally { link.textContent = 'Actualizar empresas y roles'; }
};
$('#loginForm').onsubmit = async e => {
  e.preventDefault();
  const btn = $('#loginBtn'), err = $('#loginError');
  err.textContent = '';
  if (!$('#empresa').value) { err.textContent = 'Seleccione la empresa.'; return; }
  if (!$('#rol').value) { err.textContent = 'Seleccione el rol con el que ingresa.'; return; }
  btn.disabled = true;
  btn.innerHTML = '<span class="skel" style="width:16px;height:16px;border-radius:50%"></span>Ingresando…';
  try {
    await login(+$('#empresa').value, +$('#rol').value, $('#password').value, $('#operador').value.trim());
    state.meta = await apiRetry('/api/meta');
    renderShell();
    navigate(state.meta.dashboard ? 'dashboard' : Object.keys(state.meta.resources)[0] || '');
    $('#password').value = '';
  } catch (x) {
    err.textContent = x.message;
  } finally {
    btn.disabled = false;
    btn.textContent = 'Ingresar';
  }
};
$('#togglePw').onclick = () => {
  const p = $('#password');
  const show = p.type === 'password';
  p.type = show ? 'text' : 'password';
  $('#togglePw').innerHTML = ic(show ? 'eyeoff' : 'eye');
};
$('#confirmDlg').addEventListener('close', () => { $('#confirmOk').onclick = null; $('#confirmCancel').onclick = null; });
$('#openRegistro').onclick = openRegistro;
$('#closeRegistro').innerHTML = ic('x');
$('#closeRegistro').onclick = closeRegistro;
$('#closeRegistro2').onclick = closeRegistro;
$('#regCancel').onclick = closeRegistro;
$('#regAddRow').onclick = addRegRow;
$('#regForm').onsubmit = submitRegistro;
$('#regAgain').onclick = () => {
  $('#regSuccess').classList.add('hidden');
  $('#regForm').classList.remove('hidden');
  if (!regState.rows) addRegRow();
  $('#regRuc').focus();
};
boot();
