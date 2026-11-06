'use strict';
/* SIGFV · app móvil (Capacitor). La URL del backend va grabada en config.js. */
const API = String(window.SIGFV_API_BASE || 'https://sigfv.onrender.com').replace(/\/+$/, '');
const APP_VERSION = window.SIGFV_APP_VERSION || '2.1.0';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = t => String(t ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sleep = ms => new Promise(r => setTimeout(r, ms));

const ICONS = {
  home: '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
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
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5M21 12H9"/>',
  search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  back: '<path d="m15 18-6-6 6-6"/>',
  x: '<path d="M18 6 6 18M6 6l12 12"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  refresh: '<path d="M21 12a9 9 0 1 1-2.6-6.4"/><path d="M21 3v6h-6"/>',
  check: '<path d="m20 6-11 11-5-5"/>',
  trash: '<path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/>',
  eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
  eyeoff: '<path d="m3 3 18 18M10.6 10.6a3 3 0 0 0 4.2 4.2"/><path d="M9.9 5.2A10.6 10.6 0 0 1 12 5c6.5 0 10 7 10 7a18 18 0 0 1-3 4M6.6 6.6A18 18 0 0 0 2 12s3.5 7 10 7a10.7 10.7 0 0 0 4.1-.8"/>',
  package: '<path d="m21 8-9-5-9 5v8l9 5 9-5Z"/><path d="m3 8 9 5 9-5M12 13v8"/>',
  building: '<rect x="4" y="2" width="16" height="20" rx="2"/><path d="M9 22v-4h6v4M8 6h.01M12 6h.01M16 6h.01M8 10h.01M12 10h.01M16 10h.01M8 14h.01M12 14h.01M16 14h.01"/>',
  gauge: '<path d="M12 14 8 8"/><path d="M3.3 18a9 9 0 1 1 17.4 0"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  map: '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>'
};
const ICON_ALIAS = {
  'calendar-range': 'calendar', 'file-text': 'file', 'clipboard-check': 'clipboard',
  'triangle-alert': 'alert', 'circle-alert': 'alert', 'badge-check': 'shield'
};
function ic(name, cls = '') {
  const key = ICON_ALIAS[name] || name;
  return `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[key] || ICONS.package}</svg>`;
}

/* ---------- Agrupación de módulos ---------- */
const GROUP_DEFS = [
  { id: 'operaciones', title: 'Gestión de Operaciones', icon: 'truck', desc: 'Flota, conductores y asignaciones' },
  { id: 'mantenimiento', title: 'Gestión de Mantenimiento', icon: 'wrench', desc: 'Servicios e inspecciones' },
  { id: 'logistica', title: 'Gestión Logística', icon: 'fuel', desc: 'Combustible y documentación' },
  { id: 'seguridad', title: 'Gestión de Seguridad', icon: 'shield', desc: 'Incidentes y acciones' },
  { id: 'administracion', title: 'Administración', icon: 'settings', desc: 'Usuarios y catálogos' }
];
const GROUP_MAP = {
  vehiculos: 'operaciones', conductores: 'operaciones', asignaciones: 'operaciones',
  mantenimientos: 'mantenimiento', inspecciones: 'mantenimiento',
  abastecimientos: 'logistica', documentos: 'logistica',
  incidentes: 'seguridad',
  usuarios: 'administracion', empresas: 'administracion', unidades_mineras: 'administracion',
  marcas: 'administracion', modelos: 'administracion', propietarios: 'administracion',
  proveedores_combustible: 'administracion', talleres: 'administracion'
};
const TABS = [
  { id: 'home', label: 'Inicio', icon: 'home' },
  { id: 'modules', label: 'Módulos', icon: 'grid' },
  { id: 'alerts', label: 'Alertas', icon: 'bell' },
  { id: 'profile', label: 'Perfil', icon: 'user' }
];
const BADGE_COLORS = {
  conforme: '#26865B', activo: '#26865B', vigente: '#26865B', completado: '#26865B', cerrado: '#26865B', finalizada: '#26865B',
  no_conforme: '#C64747', vencido: '#C64747', inhabilitado: '#C64747', inactivo: '#C64747', cancelada: '#C64747', cancelado: '#C64747',
  'por vencer': '#A98624', programado: '#447BA8', programada: '#447BA8', activa: '#447BA8', en_proceso: '#A98624',
  en_investigacion: '#A98624', pendiente: '#C64747', en_curso: '#447BA8', cumplida: '#26865B',
  operativo: '#26865B', 'en mantenimiento': '#A98624', 'fuera de servicio': '#C64747', alquilado: '#447BA8', 'de baja': '#42464B'
};
const badge = v => {
  const k = String(v ?? '').toLowerCase();
  return `<span class="badge" style="background:${BADGE_COLORS[k] || '#42464B'}"><span class="d"></span>${esc(String(v ?? '').replace(/_/g, ' '))}</span>`;
};
const state = {
  token: sessionStorage.getItem('sigfv_token') || '',
  meta: null, tab: 'home', stack: [], cats: {}, alerts: [], notifFilter: 'todas',
  notifCount: 0, online: false, dash: null
};

/* ---------- API ---------- */
async function api(path, opts = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), opts.timeout || 25000);
  const headers = { 'Content-Type': 'application/json' };
  if (state.token) headers.Authorization = 'Bearer ' + state.token;
  try {
    const res = await fetch(API + '/api' + path, {
      method: opts.method || 'GET', headers,
      body: opts.body != null ? JSON.stringify(opts.body) : undefined,
      signal: ctrl.signal, cache: 'no-store'
    });
    let data = {};
    try { data = await res.json(); } catch { }
    if (res.status === 401 && path !== '/auth/login') { logout(true); throw new Error('La sesión venció. Ingrese de nuevo.'); }
    if (!res.ok) throw new Error(data.error || 'Error ' + res.status);
    state.online = true;
    return data;
  } catch (e) {
    if (e.name === 'AbortError') throw new Error('El servidor tardó demasiado. Intente otra vez.');
    if (e instanceof TypeError) { state.online = false; throw new Error('Sin conexión con el servidor. Reintentando…'); }
    throw e;
  } finally { clearTimeout(timer); }
}
async function apiRetry(path, opts = {}, tries = 2) {
  let last;
  for (let i = 0; i < tries; i++) {
    try { return await api(path, opts); } catch (e) { last = e; if (i < tries - 1) await sleep(800); }
  }
  throw last;
}
function toast(msg, isError = false) {
  const t = $('#toast');
  t.innerHTML = ic(isError ? 'alert' : 'check') + '<span>' + esc(msg) + '</span>';
  t.className = 'on' + (isError ? ' err' : '');
  clearTimeout(t._t);
  t._t = setTimeout(() => { t.className = ''; }, 3300);
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
    if (!isNaN(d)) return d.toLocaleDateString('es-PE', { day: '2-digit', month: 'short' }) + ' · ' + d.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' });
  }
  return s;
}
const isNumeric = v => v != null && v !== '' && !isNaN(Number(v)) && !/^\d{4}-\d{2}-\d{2}/.test(String(v));
function num(v) { const n = Number(v); return Number.isFinite(n) ? n.toLocaleString('es-PE', { maximumFractionDigits: 2 }) : '—'; }
function initials(n) { return String(n || '?').trim().split(/\s+/).slice(0, 2).map(x => x[0]).join('').toUpperCase(); }
function groupName(key) { const g = GROUP_DEFS.find(x => x.id === GROUP_MAP[key]); return g ? g.title : 'Módulos'; }
function groups() {
  const out = GROUP_DEFS.map(g => ({ ...g, items: [] }));
  const by = Object.fromEntries(out.map(g => [g.id, g]));
  for (const [key, r] of Object.entries(state.meta.resources)) {
    const gid = GROUP_MAP[key] || (r.mod === 'configuracion' ? 'administracion' : 'operaciones');
    (by[gid] || by.operaciones).items.push({ key, ...r });
  }
  return out.filter(g => g.items.length);
}

/* ---------- Arranque ---------- */
function bootMsg(msg) { $('#bootMsg').textContent = msg; }
function showBootError(msg) {
  $('#bootSpin').classList.add('hidden');
  $('#bootActions').classList.remove('hidden');
  $('#bootMsg').textContent = msg;
}
async function ping() {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 7000);
  try {
    const r = await fetch(API + '/api/health', { signal: ctrl.signal, cache: 'no-store' });
    return r.ok;
  } catch { return false; } finally { clearTimeout(timer); }
}
async function wake() {
  for (let i = 1; i <= 8; i++) {
    bootMsg(i === 1 ? 'Conectando con SIGFV…' : `Despertando el servidor… (${i}/8)`);
    if (await ping()) { state.online = true; return true; }
    if (i < 8) await sleep(2400);
  }
  return false;
}
async function start() {
  $('#boot').classList.remove('hidden');
  $('#login').classList.add('hidden');
  $('#app').classList.add('hidden');
  $('#bootSpin').classList.remove('hidden');
  $('#bootActions').classList.add('hidden');
  const ok = await wake();
  if (!ok) { showBootError('No se pudo conectar. Revise su conexión a internet.'); return; }
  if (!state.token) { showLogin(); return; }
  try {
    state.meta = await apiRetry('/meta');
    showApp();
    renderTab('home');
  } catch (e) {
    if (e.message.includes('sesión')) return;
    showLogin();
    $('#loginError').textContent = e.message;
  }
}
function showLogin() {
  $('#boot').classList.add('hidden');
  $('#app').classList.add('hidden');
  $('#login').classList.remove('hidden');
  setTimeout(() => $('#usuario').focus(), 120);
}
function showApp() {
  $('#boot').classList.add('hidden');
  $('#login').classList.add('hidden');
  $('#app').classList.remove('hidden');
  renderTabs();
  renderBell();
}
function logout(silent = false) {
  sessionStorage.removeItem('sigfv_token');
  state.token = ''; state.meta = null; state.stack = []; state.dash = null;
  closeSub(true);
  showLogin();
  if (!silent) toast('Sesión cerrada.');
}

/* ---------- Armazón ---------- */
function renderTabs() {
  $('#tabs').innerHTML = TABS.map(t => `<button class="tab ${state.tab === t.id ? 'active' : ''}" data-tab="${t.id}" aria-label="${t.label}">${ic(t.icon)}<span>${t.label}</span>${t.id === 'alerts' && state.notifCount ? '<span class="dot"></span>' : ''}</button>`).join('');
  $$('#tabs .tab').forEach(b => b.onclick = () => { if (state.stack.length) closeSub(true); renderTab(b.dataset.tab); });
}
function renderAppbar() {
  const name = state.meta.user || 'Usuario';
  $('#appbar').innerHTML = `
    <span class="mark">SF</span>
    <div class="brandtxt"><strong>SIGFV</strong><small>Gestión de flota</small></div>
    <span class="grow"></span>
    <span class="dot" title="Servidor en línea"></span>
    <button id="bellBtn" aria-label="Alertas" style="position:relative">${ic('bell')}${state.notifCount ? '<span style="position:absolute;top:5px;right:5px;width:8px;height:8px;border-radius:50%;background:#C64747;border:1.5px solid #171717"></span>' : ''}</button>
    <button id="avatarBtn" aria-label="Perfil"><span class="avatar">${esc(initials(name))}</span></button>`;
  $('#bellBtn').onclick = () => renderTab('alerts');
  $('#avatarBtn').onclick = () => renderTab('profile');
}
function renderBell() { renderAppbar(); }
function renderTab(tab) {
  state.tab = tab;
  closeSub(true);
  renderTabs();
  renderAppbar();
  const v = $('#view');
  v.className = 'page view-enter';
  if (tab === 'home') renderHome();
  else if (tab === 'modules') renderModules();
  else if (tab === 'alerts') renderAlerts();
  else renderProfile();
  window.scrollTo({ top: 0 });
}

/* ---------- Inicio ---------- */
const KPI_DEFS = [
  ['total', 'Vehículos', 'truck', 'gold'],
  ['conductores', 'Conductores activos', 'id-card', 'ok'],
  ['insp_nc', 'Inspecciones no conformes', 'clipboard', 'bad'],
  ['docs', 'Docs por vencer', 'file', 'warn'],
  ['mant', 'Mantenimientos', 'wrench', 'info'],
  ['litros', 'Combustible (L)', 'fuel', ''],
  ['incidentes', 'Incidentes abiertos', 'alert', 'bad']
];
const QUICK_ACTIONS = [
  ['vehiculos', 'Vehículo', 'truck'],
  ['inspecciones', 'Inspección', 'clipboard'],
  ['abastecimientos', 'Combustible', 'fuel'],
  ['mantenimientos', 'Mantenimiento', 'wrench'],
  ['incidentes', 'Incidente', 'alert'],
  ['conductores', 'Conductor', 'id-card']
];
async function renderHome() {
  const v = $('#view');
  const name = String(state.meta.user || 'Usuario').split(' ')[0];
  const date = new Date().toLocaleDateString('es-PE', { weekday: 'long', day: 'numeric', month: 'long' });
  v.innerHTML = `
    <div class="hero">
      <div class="hello">Panel de control</div>
      <h1>Hola, ${esc(name)}</h1>
      <p>${esc(date)} · ${esc((state.meta.roles || []).join(', ') || 'Usuario SIGFV')}</p>
      <div class="hero-foot"><span class="chip-dark">${ic('shield', 'sm')} Conexión segura</span><button class="refresh" id="homeRefresh">${ic('refresh', 'sm')} Actualizar</button></div>
    </div>
    <div class="kpis" id="homeKpis">${KPI_DEFS.map(k => `<div class="kpi ${k[3]}"><div class="k-ico">${ic(k[2])}</div><div class="skel" style="width:64%;height:24px"></div><div class="skel" style="width:82%;height:10px;margin-top:7px"></div></div>`).join('')}</div>
    <div class="section"><div class="section-head"><h2>Acciones rápidas</h2></div><div class="quick" id="quickActions"></div></div>
    <div class="section" id="fleetSec"></div>
    <div class="section" id="mantSec"></div>
    <div class="section" id="docsSec"></div>`;
  $('#homeRefresh').onclick = () => { state.dash = null; renderHome(); };
  renderQuick();
  try {
    const d = state.dash || await apiRetry('/dashboard');
    state.dash = d;
    const k = d.k || {};
    $('#homeKpis').innerHTML = KPI_DEFS.map(([key, label, icon, tone]) => `
      <div class="kpi ${tone}"><div class="k-ico">${ic(icon)}</div><strong>${key === 'litros' ? num(k[key]) : Number(k[key] || 0).toLocaleString('es-PE')}</strong><span>${label}</span></div>`).join('');
    const total = Math.max(1, ...(d.estados || []).map(e => e.n));
    $('#fleetSec').innerHTML = `<div class="section-head"><h2>Estado de la flota</h2><span class="link" style="color:var(--muted);font-weight:500">${(d.estados || []).reduce((a, e) => a + e.n, 0)} unidades</span></div>
      <div class="card pad bars">${(d.estados || []).map(e => `<div class="bar-row"><span>${esc(e.nombre)}</span><div class="track"><div class="fill" style="width:${e.n / total * 100}%;background:${esc(e.color || '#42464B')}"></div></div><b>${e.n}</b></div>`).join('') || '<span class="muted">Sin datos.</span>'}</div>`;
    $('#mantSec').innerHTML = `<div class="section-head"><h2>Próximos mantenimientos</h2>${state.meta.resources.mantenimientos ? '<button class="link" data-go="mantenimientos">Ver todos</button>' : ''}</div>
      <div class="card">${(d.mant || []).length ? (d.mant || []).map(m => `<div class="row"><span class="r-ico">${ic('wrench')}</span><div class="r-main"><strong>${esc(m.vehiculo)}</strong><small>${esc(m.tipo)}</small></div><span class="r-date">${fmt(m.fecha)}</span></div>`).join('') : '<div class="empty" style="padding:26px"><strong>Sin mantenimientos programados</strong></div>'}</div>`;
    $('#docsSec').innerHTML = `<div class="section-head"><h2>Documentos por vencer</h2>${state.meta.resources.documentos ? '<button class="link" data-go="documentos">Ver todos</button>' : ''}</div>
      <div class="card">${(d.docs || []).length ? (d.docs || []).map(x => `<div class="row"><span class="r-ico" style="color:var(--warn)">${ic('file')}</span><div class="r-main"><strong>${esc(x.titular || '—')}</strong><small>${esc(x.documento)}</small></div><span class="r-date">${fmt(x.vence)}</span></div>`).join('') : '<div class="empty" style="padding:26px"><strong>Sin documentos por vencer</strong></div>'}</div>`;
    $$('[data-go]', v).forEach(b => b.onclick = () => { const key = b.dataset.go; if (state.meta.resources[key]) openList(key); });
  } catch (e) {
    $('#homeKpis').innerHTML = `<div class="empty" style="grid-column:1/-1"><span class="big">${ic('alert')}</span><strong>No se pudo cargar el panel</strong><span>${esc(e.message)}</span><button class="btn ghost sm" id="retryHome">Reintentar</button></div>`;
    const b = $('#retryHome'); if (b) b.onclick = renderHome;
  }
  loadNotifCount();
}
function renderQuick() {
  const items = QUICK_ACTIONS.filter(([key]) => state.meta.resources[key] && state.meta.resources[key].crear);
  $('#quickActions').innerHTML = items.map(([key, label, icon]) => `<button data-new="${key}"><span class="q-ico">${ic(icon)}</span>${label}</button>`).join('') || '<span class="muted" style="font-size:12px">Su rol no permite registrar datos.</span>';
  $$('#quickActions [data-new]').forEach(b => b.onclick = () => openForm(b.dataset.new));
}
async function loadNotifCount() {
  if (!state.meta.notificaciones) return;
  try {
    const n = await api('/notificaciones');
    state.alerts = n;
    state.notifCount = n.length;
    renderAppbar();
    renderTabs();
  } catch { }
}

/* ---------- Módulos ---------- */
function renderModules() {
  const v = $('#view');
  const gs = groups();
  v.innerHTML = `
    <div class="search-wrap">${ic('search')}<input id="modSearch" placeholder="Buscar módulo…" autocomplete="off"></div>
    <div id="modList">${gs.map(g => {
      const isAdmin = g.id === 'administracion';
      const users = isAdmin ? g.items.filter(r => r.mod === 'usuarios') : [];
      const cats = isAdmin ? g.items.filter(r => r.mod !== 'usuarios') : g.items;
      const row = r => `<button class="mod-item" data-key="${r.key}"><span class="mi">${ic(r.icon || 'package')}</span><span class="mt"><strong>${esc(r.label)}</strong><small>${r.crear ? 'Consultar y registrar' : 'Solo consulta'}</small></span>${ic('chevron', 'sm chev')}</button>`;
      return `<section class="mod-group" data-g="${g.id}">
        <div class="mod-head"><span class="m-icon">${ic(g.icon)}</span><div><h2>${esc(g.title)}</h2><p>${esc(g.desc)}</p></div></div>
        ${users.length ? `<div class="subhead">Usuarios</div><div class="mod-card" style="margin-bottom:9px">${users.map(row).join('')}</div>` : ''}
        ${isAdmin && cats.length ? '<div class="subhead">Catálogos maestros</div>' : ''}
        <div class="mod-card">${cats.map(row).join('')}</div>
      </section>`;
    }).join('')}</div>`;
  $('#modSearch').oninput = e => {
    const q = e.target.value.toLowerCase().trim();
    $$('#modList .mod-item').forEach(b => { b.style.display = !q || b.textContent.toLowerCase().includes(q) ? '' : 'none'; });
    $$('#modList .mod-group').forEach(s => {
      const any = $$('.mod-item', s).some(b => b.style.display !== 'none');
      s.style.display = any ? '' : 'none';
      if (q) { const sh = $('.subhead', s); if (sh) sh.style.display = any ? '' : 'none'; }
    });
  };
  $$('#modList [data-key]').forEach(b => b.onclick = () => openList(b.dataset.key));
}

/* ---------- Navegación de subpantallas ---------- */
const sub = { view: null, key: null, id: null, q: '', page: 1, limit: 20, total: 0, items: [], dirty: false, pushed: false, suppress: false, req: 0, backToList: false };

function showSub() {
  document.body.classList.add('sub');
  $('#sub').classList.add('open');
  if (!sub.pushed) { sub.pushed = true; try { history.pushState({ sigfv: 1 }, ''); } catch { } }
}
function hideSub() {
  $('#sub').classList.remove('open');
  document.body.classList.remove('sub');
  sub.view = null; sub.key = null; sub.id = null; sub.items = []; sub.dirty = false;
  sub.pushed = false; sub.backToList = false;
}
function closeSub(force = false) {
  if (!force && sub.dirty && !confirm('Hay cambios sin guardar. ¿Desea descartarlos?')) return;
  const wasPushed = sub.pushed;
  hideSub();
  if (wasPushed) { sub.suppress = true; try { history.back(); } catch { sub.suppress = false; } }
}
function subBack() {
  if (sub.view === 'form' && sub.backToList) {
    if (sub.dirty && !confirm('Hay cambios sin guardar. ¿Desea descartarlos?')) return;
    sub.dirty = false;
    sub.view = 'list';
    renderListScreen(sub.key);
    return;
  }
  closeSub();
}
window.addEventListener('popstate', () => {
  if (sub.suppress) { sub.suppress = false; return; }
  if ($('#sub').classList.contains('open')) hideSub();
});

function openList(key) {
  const r = state.meta.resources[key];
  if (!r) return;
  sub.view = 'list'; sub.key = key; sub.id = null; sub.q = ''; sub.page = 1;
  sub.items = []; sub.total = 0; sub.backToList = false; sub.dirty = false;
  showSub();
  renderListScreen(key);
}
function openForm(key, id) {
  const r = state.meta.resources[key];
  if (!r) return;
  if (!sub.view) { sub.view = 'list'; sub.key = key; sub.backToList = false; showSub(); }
  sub.backToList = sub.view === 'list' && sub.key === key;
  sub.view = 'form'; sub.id = id || null; sub.dirty = false;
  renderFormScreen(key, id);
}

/* ---------- Listado ---------- */
function subBar(title, opts = {}) {
  $('#subBar').innerHTML = `
    <button id="subBack" aria-label="Volver">${ic('back')}</button>
    <span class="subtitle">${esc(title)}</span>
    ${opts.newBtn ? `<button id="subNew" aria-label="Registrar">${ic('plus')}</button>` : '<span style="min-width:40px"></span>'}`;
  $('#subBack').onclick = subBack;
  if (opts.newBtn) $('#subNew').onclick = () => openForm(opts.key, null);
}
function recordCard(r, x) {
  const cols = r.cols || [];
  const first = cols[0];
  const second = cols[1];
  const rest = cols.slice(2);
  const titleVal = first ? (first[2] === 'badge' ? '' : fmt(x[first[0]])) : ('Registro #' + x.id);
  const badgeCol = cols.find(c2 => c2[2] === 'badge');
  const subVal = second ? (second[2] === 'badge' ? '' : fmt(x[second[0]])) : '';
  const meta = rest.filter(c2 => c2[2] !== 'badge').slice(0, 3).map(c2 => `<span><b>${esc(c2[1])}:</b> ${esc(isNumeric(x[c2[0]]) ? num(x[c2[0]]) : fmt(x[c2[0]]))}</span>`).join('');
  return `<button class="record" data-id="${x.id}">
    <span class="rec-main">
      <span class="rec-title"><strong>${esc(titleVal || '—')}</strong>${badgeCol && x[badgeCol[0]] != null ? badge(x[badgeCol[0]]) : ''}</span>
      ${subVal ? `<span class="rec-sub">${esc(subVal)}</span>` : ''}
      ${meta ? `<span class="rec-meta">${meta}</span>` : ''}
    </span>${ic('chevron', 'sm chev')}</button>`;
}
function renderListScreen(key) {
  const r = state.meta.resources[key];
  if (!r) { closeSub(true); return; }
  subBar(r.label, { newBtn: !!r.crear, key });
  const body = $('#subBody');
  $('#subFoot').innerHTML = '';
  body.innerHTML = `<div class="search-wrap">${ic('search')}<input id="recSearch" value="${esc(sub.q)}" placeholder="Buscar en ${esc(r.label.toLowerCase())}…" autocomplete="off"></div>
    <div class="list-head"><span class="count" id="recCount"></span></div>
    <div id="recList"></div>`;
  const input = $('#recSearch');
  input.oninput = e => {
    sub.q = e.target.value.trim();
    clearTimeout(renderListScreen._t);
    renderListScreen._t = setTimeout(() => loadRecords(true), 320);
  };
  loadRecords(true);
}
async function loadRecords(reset) {
  const key = sub.key, r = state.meta.resources[key];
  if (!r) return;
  if (reset) { sub.page = 1; sub.items = []; }
  const token = ++sub.req;
  const list = $('#recList');
  if (!list) return;
  if (reset) list.innerHTML = Array.from({ length: 5 }, () => '<div class="skel" style="height:74px;margin-bottom:9px"></div>').join('');
  const oldBtn = $('#loadMore'); if (oldBtn) oldBtn.remove();
  try {
    const d = await apiRetry(`/r/${key}?pagina=${sub.page}&limit=${sub.limit}&q=${encodeURIComponent(sub.q)}`);
    if (token !== sub.req || sub.view !== 'list' || sub.key !== key) return;
    sub.total = d.total;
    sub.items = reset ? d.items : sub.items.concat(d.items);
    const count = $('#recCount');
    if (count) count.textContent = `${d.total} registro${d.total === 1 ? '' : 's'}`;
    if (!sub.items.length) {
      list.innerHTML = `<div class="empty"><span class="big">${ic(sub.q ? 'search' : 'package')}</span><strong>${sub.q ? 'Ningún resultado' : 'Aún no hay registros'}</strong><span>${sub.q ? 'Pruebe con otro término de búsqueda.' : (r.crear ? 'Use el botón + para crear el primero.' : 'No hay datos disponibles.')}</span></div>`;
      return;
    }
    list.innerHTML = sub.items.map(x => recordCard(r, x)).join('');
    $$('#recList .record').forEach(b => b.onclick = () => openForm(key, +b.dataset.id));
    const body = $('#subBody');
    if (sub.items.length < sub.total) {
      const btn = document.createElement('button');
      btn.id = 'loadMore'; btn.className = 'load-more';
      btn.textContent = `Cargar más (${sub.items.length} de ${sub.total})`;
      btn.onclick = () => { sub.page++; loadRecords(false); };
      body.appendChild(btn);
    }
  } catch (e) {
    if (token !== sub.req) return;
    list.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudo cargar</strong><span>${esc(e.message)}</span><button class="btn ghost sm" id="retryList">Reintentar</button></div>`;
    const b = $('#retryList'); if (b) b.onclick = () => loadRecords(true);
  }
}

/* ---------- Formulario ---------- */
async function getCat(name) {
  if (!state.cats[name]) state.cats[name] = await api(`/cat/${name}`);
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
function fieldControl(f, value, disabled) {
  const val = value ?? '';
  const attrs = `name="${esc(f.n)}" id="f_${esc(f.n)}" ${f.req ? 'required' : ''} ${disabled ? 'disabled' : ''}`;
  if (f.t === 'select') {
    const opts = f.cat ? (state.cats[f.cat] || []).map(x => [x.id, x.nombre]) : (f.o || []);
    return `<select class="input" ${attrs}><option value="">${f.req ? 'Seleccione…' : '—'}</option>${opts.map(([a, b]) => `<option value="${esc(a)}" ${String(val) === String(a) ? 'selected' : ''}>${esc(b)}</option>`).join('')}</select>`;
  }
  if (f.t === 'textarea') return `<textarea class="input" ${attrs} rows="3" placeholder="${esc(f.l)}">${esc(val)}</textarea>`;
  let type = f.t === 'datetime' ? 'datetime-local' : (f.t === 'password' ? 'password' : f.t);
  let v = val;
  if (f.t === 'datetime' && val) v = dtLocal(val);
  return `<input class="input" ${attrs} type="${type}" ${f.t === 'number' ? 'step="any" inputmode="decimal"' : ''} ${f.t === 'password' ? 'autocomplete="new-password" minlength="8"' : ''} value="${esc(v)}">`;
}
async function renderFormScreen(key, id) {
  const r = state.meta.resources[key];
  if (!r) { closeSub(true); return; }
  const editable = id ? !!r.editar : !!r.crear;
  const token = ++sub.req;
  subBar(id ? 'Editar' : 'Registrar', {});
  $('#subBody').innerHTML = `<div class="form-card">${Array.from({ length: 6 }, () => '<div class="skel" style="height:44px;margin-bottom:12px"></div>').join('')}</div>`;
  $('#subFoot').innerHTML = '';
  try {
    const cats = {};
    if (r.fields.some(f => f.cat)) {
      const names = [...new Set(r.fields.filter(f => f.cat).map(f => f.cat))];
      const pairs = await Promise.all(names.map(async n => [n, await getCat(n).catch(() => [])]));
      pairs.forEach(([n, v]) => { cats[n] = v; });
    }
    if (token !== sub.req) return;
    const item = id ? await api(`/r/${key}/${id}`) : {};
    if (token !== sub.req) return;
    state.cats = cats;
    const fields = r.fields.map(f => {
      let val = item[f.n];
      if (val == null && f.t === 'select' && !f.req && f.o && f.o.length === 2) val = '';
      return `<div class="field"><label for="f_${esc(f.n)}">${esc(f.l)}${f.req ? ' <span class="req">*</span>' : ''}</label>${fieldControl(f, val, !editable)}${f.t === 'password' && id ? '<small class="muted" style="font-size:11px">Deje en blanco para conservar la contraseña actual.</small>' : ''}</div>`;
    }).join('');
    $('#subBody').innerHTML = `
      <form id="subForm" class="form-card" autocomplete="on">
        ${!editable ? `<div class="form-note">${ic('info')}<span>Su rol permite consultar este módulo, pero no modificarlo.</span></div>` : ''}
        ${fields}
      </form>
      ${id && r.eliminar ? `<div class="danger-zone"><h3>Eliminar registro</h3><p>El registro se dará de baja y dejará de aparecer en los listados.</p><button type="button" class="btn danger full" id="btnDelete">${ic('trash', 'sm')} Eliminar ${esc(r.label.toLowerCase())}</button></div>` : ''}`;
    if (editable) {
      $('#subFoot').innerHTML = `<div class="subfoot-in"><button type="button" class="btn ghost" id="btnCancel">Cancelar</button><button type="button" class="btn primary" id="btnSave">${ic('check', 'sm')}${id ? 'Guardar' : 'Registrar'}</button></div>`;
      $('#btnCancel').onclick = subBack;
      $('#btnSave').onclick = () => saveForm(key, id);
      $('#subForm').querySelectorAll('input,select,textarea').forEach(el => {
        el.addEventListener('input', () => { sub.dirty = true; });
        el.addEventListener('change', () => { sub.dirty = true; });
      });
      const first = $('#subForm input:not([disabled]),#subForm select,#subForm textarea');
      if (first) setTimeout(() => { try { first.focus({ preventScroll: true }); } catch { } }, 180);
    } else {
      $('#subFoot').innerHTML = `<div class="subfoot-in"><button class="btn ghost" id="btnOnlyBack">Volver</button></div>`;
      $('#btnOnlyBack').onclick = subBack;
    }
    if ($('#btnDelete')) $('#btnDelete').onclick = () => deleteRecord(key, id);
  } catch (e) {
    if (token !== sub.req) return;
    $('#subBody').innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudo abrir el formulario</strong><span>${esc(e.message)}</span><button class="btn ghost sm" id="retryForm">Reintentar</button></div>`;
    const b = $('#retryForm'); if (b) b.onclick = () => renderFormScreen(key, id);
  }
}
async function saveForm(key, id) {
  const form = $('#subForm');
  if (!form || !form.reportValidity()) return;
  const body = {};
  new FormData(form).forEach((v, k) => { body[k] = v; });
  const btn = $('#btnSave');
  if (btn) { btn.disabled = true; btn.textContent = 'Guardando…'; }
  try {
    await api(id ? `/r/${key}/${id}` : `/r/${key}`, { method: id ? 'PUT' : 'POST', body });
    state.cats = {};
    sub.dirty = false;
    toast(id ? 'Cambios guardados.' : 'Registro creado.');
    if (sub.backToList) {
      sub.view = 'list'; sub.page = 1; sub.items = []; sub.q = '';
      renderListScreen(key);
    } else closeSub(true);
  } catch (e) {
    if (btn) { btn.disabled = false; btn.innerHTML = ic('check', 'sm') + (id ? 'Guardar' : 'Registrar'); }
    toast(e.message, true);
  }
}
function deleteRecord(key, id) {
  if (!confirm('¿Confirma que desea eliminar este registro? Esta acción lo dará de baja.')) return;
  api(`/r/${key}/${id}`, { method: 'DELETE' }).then(() => {
    state.cats = {};
    sub.dirty = false;
    toast('Registro eliminado.');
    if (sub.backToList) { sub.view = 'list'; sub.page = 1; sub.items = []; renderListScreen(key); }
    else closeSub(true);
  }).catch(e => toast(e.message, true));
}

/* ---------- Alertas ---------- */
const ALERT_FILTERS = [
  ['todas', 'Todas'], ['documentos', 'Documentos'], ['licencias', 'Licencias'],
  ['inspecciones', 'Inspecciones'], ['incidentes', 'Incidentes'], ['vehiculos', 'Vehículos']
];
function alertPrefix(f) {
  return f === 'documentos' ? 'documento' : f === 'licencias' ? 'licencia' : f === 'inspecciones' ? 'inspecci' : f === 'incidentes' ? 'incidente' : f === 'vehiculos' ? 'vehículo' : '';
}
function alertIcon(tipo) {
  const t = String(tipo).toLowerCase();
  if (t.startsWith('documento')) return 'file';
  if (t.startsWith('licencia')) return 'id-card';
  if (t.startsWith('inspecci')) return 'clipboard';
  if (t.startsWith('incidente')) return 'alert';
  return 'truck';
}
function alertColor(tipo) {
  const t = String(tipo).toLowerCase();
  if (t.includes('vencid')) return '#C64747';
  if (t.includes('por vencer')) return '#A98624';
  return '#447BA8';
}
async function renderAlerts() {
  const v = $('#view');
  v.innerHTML = `<div class="section-head"><h2>Alertas del sistema</h2><button class="link" id="refreshAlerts">${ic('refresh', 'sm')}</button></div>
    <div id="alertWrap">${Array.from({ length: 5 }, () => '<div class="skel" style="height:66px;margin-bottom:9px"></div>').join('')}</div>`;
  $('#refreshAlerts').onclick = renderAlerts;
  try {
    const data = await apiRetry('/notificaciones');
    state.alerts = data; state.notifCount = data.length;
    renderAppbar(); renderTabs();
    const count = f => {
      if (f === 'todas') return data.length;
      const p = alertPrefix(f);
      return data.filter(n => String(n.tipo).toLowerCase().startsWith(p)).length;
    };
    const items = data.filter(n => state.notifFilter === 'todas' || String(n.tipo).toLowerCase().startsWith(alertPrefix(state.notifFilter)));
    const wrap = $('#alertWrap');
    if (!wrap) return;
    wrap.innerHTML = `
      <div class="chips">${ALERT_FILTERS.map(([f, label]) => `<button class="chip ${state.notifFilter === f ? 'on' : ''}" data-f="${f}">${label}<span class="n">${count(f)}</span></button>`).join('')}</div>
      <div class="card">${items.length ? items.map(n => `<div class="alert">
        <span class="a-ico" style="color:${alertColor(n.tipo)}">${ic(alertIcon(n.tipo))}</span>
        <span class="a-main"><strong>${esc(n.detalle)}</strong><small>${esc(n.tipo)}</small></span>
        <span class="a-date">${fmt(n.fecha)}</span></div>`).join('') : `<div class="empty"><span class="big">${ic('check')}</span><strong>Sin alertas en esta categoría</strong><span>Todo en orden por ahora.</span></div>`}</div>`;
    $$('#alertWrap [data-f]').forEach(b => b.onclick = () => { state.notifFilter = b.dataset.f; renderAlerts(); });
  } catch (e) {
    const wrap = $('#alertWrap');
    if (!wrap) return;
    wrap.innerHTML = `<div class="empty"><span class="big">${ic('alert')}</span><strong>No se pudieron cargar las alertas</strong><span>${esc(e.message)}</span><button class="btn ghost sm" id="retryAlerts">Reintentar</button></div>`;
    const b = $('#retryAlerts'); if (b) b.onclick = renderAlerts;
  }
}

/* ---------- Perfil ---------- */
function renderProfile() {
  const v = $('#view');
  const name = state.meta.user || 'Usuario';
  const roles = state.meta.roles || [];
  const mods = Object.keys(state.meta.resources).length;
  v.innerHTML = `
    <div class="profile-top">
      <div class="big">${esc(initials(name))}</div>
      <h1>${esc(name)}</h1>
      <p>${roles.length ? esc(roles.join(' · ')) : 'Sin rol asignado'}</p>
      <div class="rolechips">${roles.map(r2 => `<span>${esc(r2)}</span>`).join('') || '<span>Usuario SIGFV</span>'}</div>
    </div>
    <div class="section">
      <div class="section-head"><h2>Cuenta y sistema</h2></div>
      <div class="card">
        <div class="info-row">${ic('user')}<span class="lbl"><strong>Usuario</strong><small>Cuenta corporativa</small></span><span class="val">${esc(name)}</span></div>
        <div class="info-row">${ic('gauge')}<span class="lbl"><strong>Módulos disponibles</strong><small>Según sus permisos</small></span><span class="val">${mods}</span></div>
        <div class="info-row">${ic('shield')}<span class="lbl"><strong>Servidor</strong><small>Conexión cifrada</small></span><span class="val"><span class="online"><span class="p"></span>Operativo</span></span></div>
        <div class="info-row">${ic('info')}<span class="lbl"><strong>Versión</strong><small>Aplicación móvil</small></span><span class="val">${esc(APP_VERSION)}</span></div>
      </div>
    </div>
    <div class="section">
      <div class="section-head"><h2>Sesión</h2></div>
      <button class="btn danger full" id="btnLogout">${ic('logout', 'sm')} Cerrar sesión</button>
      <p class="muted" style="font-size:11.5px;text-align:center;margin-top:12px;line-height:1.4">SIGFV · Sistema Integral de Gestión de Flota Vehicular</p>
    </div>`;
  $('#btnLogout').onclick = () => { if (confirm('¿Desea cerrar la sesión?')) logout(); };
}

/* ---------- Eventos generales ---------- */
window.addEventListener('online', () => { state.online = true; if ($('#app').classList.contains('hidden') && !$('#login').classList.contains('hidden')) return; });
window.addEventListener('offline', () => { state.online = false; toast('Sin conexión a internet.', true); });
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && $('#sub').classList.contains('open')) subBack();
});

/* ---------- Acceso y arranque ---------- */
$('#loginForm').onsubmit = async e => {
  e.preventDefault();
  const btn = $('#loginBtn'), err = $('#loginError');
  err.textContent = '';
  btn.disabled = true; btn.textContent = 'Ingresando…';
  try {
    const usuario = $('#usuario').value.trim();
    const password = $('#password').value;
    const r2 = await api('/auth/login', { method: 'POST', body: { usuario, password } });
    state.token = r2.token;
    sessionStorage.setItem('sigfv_token', r2.token);
    state.meta = await apiRetry('/meta');
    showApp();
    renderTab('home');
  } catch (x) {
    err.textContent = x.message;
    if (/servidor|conexión/i.test(x.message)) { await wake(); }
  } finally {
    btn.disabled = false; btn.textContent = 'Ingresar';
  }
};
$('#togglePw').onclick = () => {
  const p = $('#password');
  const show = p.type === 'password';
  p.type = show ? 'text' : 'password';
  $('#togglePw').innerHTML = ic(show ? 'eyeoff' : 'eye');
};
$('#bootRetry').onclick = () => start();

// Mantiene el backend despierto mientras la app permanece abierta.
setInterval(() => { if (state.token && !document.hidden) ping(); }, 4 * 60 * 1000);
document.addEventListener('visibilitychange', () => {
  if (!document.hidden && state.token) ping();
});

start();
