/* IRIS Data Copilot - web UI (plain JS + Chart.js). UI strings live in i18n.js (EN-US / PT-BR). */
'use strict';

const $ = (sel, el = document) => el.querySelector(sel);
const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];
const h = (tag, attrs = {}, ...children) => {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else if (k === 'html') el.innerHTML = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat()) {
    if (c == null || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
};

const state = {
  status: null,
  schemas: [],
  selected: new Set(JSON.parse(localStorage.getItem('copilot.schemas') || '[]')),
  mode: 'sql',
  view: 'ask',
  history: [],
  agentSession: '',
  dashboards: [],
  dashboard: null,
  timer: null,
  charts: new Map(),
  catalog: null,
};

const PALETTE = ['#4f46e5', '#0ea5a4', '#f59e0b', '#ef4444', '#8b5cf6', '#10b981', '#ec4899', '#3b82f6', '#84cc16', '#f97316', '#14b8a6', '#a855f7'];
const CHART_KEYS = ['bar', 'hbar', 'line', 'area', 'pie', 'doughnut', 'scatter', 'kpi', 'table'];
const chartTypes = () => CHART_KEYS.map((k) => [k, t('chart.' + k)]);
const widthOptions = () => [[1, '1/4'], [2, '1/2'], [3, '3/4'], [4, t('width.full')]];

// ------------------------------------------------------------------ API
async function api(action, payload = {}) {
  const res = await fetch('/api/call/' + action, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Copilot-Lang': LANG },
    body: JSON.stringify(Object.assign({ lang: LANG }, payload)),
  });
  if (res.status === 401) { showLogin(); throw new Error(t('err.session')); }
  let data = {};
  try { data = await res.json(); } catch { /* empty body */ }
  if (!res.ok) throw new Error(data.detail || t('err.http', { n: res.status }));
  return data;
}

function toast(msg, err = false) {
  const el = $('#toast');
  el.textContent = msg;
  el.className = 'toast show' + (err ? ' err' : '');
  clearTimeout(toast._t);
  toast._t = setTimeout(() => (el.className = 'toast'), err ? 5000 : 2600);
}

const schemasParam = () => [...state.selected];

// ------------------------------------------------------------------ formatting (per language)
let nf, nfCompact;
function setFormatters() {
  nf = new Intl.NumberFormat(t('locale'), { maximumFractionDigits: 2 });
  nfCompact = new Intl.NumberFormat(t('locale'), { notation: 'compact', maximumFractionDigits: 1 });
}
setFormatters();

function fmtDate(iso) {
  const [y, m, d] = iso.split('-');
  return LANG === 'en' ? `${m}/${d}/${y}` : `${d}/${m}/${y}`;
}
function fmt(v, type) {
  if (v == null || v === '') return '';
  if (typeof v === 'number') return nf.format(v);
  if (type === 'date' && /^\d{4}-\d{2}-\d{2}$/.test(v)) return fmtDate(v);
  if (type === 'timestamp' && /^\d{4}-\d{2}-\d{2} /.test(v)) { const [d, tm] = v.split(' '); return fmtDate(d) + ' ' + tm.slice(0, 8); }
  return String(v);
}
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[c]));

function highlightSQL(sql) {
  const kws = 'SELECT|FROM|WHERE|AND|OR|NOT|IN|IS|NULL|AS|ON|JOIN|LEFT|RIGHT|INNER|OUTER|FULL|CROSS|GROUP|BY|ORDER|HAVING|TOP|DISTINCT|CASE|WHEN|THEN|ELSE|END|UNION|ALL|WITH|ASC|DESC|BETWEEN|LIKE|EXISTS|COUNT|SUM|AVG|MIN|MAX|ROUND|CAST|YEAR|MONTH|DAY|DATEADD|DATEDIFF|DATEPART|TO_CHAR|CURRENT_DATE|NOW|NULLIF|COALESCE|UPPER|LOWER';
  return esc(sql)
    .replace(/(&apos;.*?&apos;)/g, '<span class="str">$1</span>')
    .replace(new RegExp('\\b(' + kws + ')\\b', 'gi'), '<span class="kw">$1</span>')
    .replace(/(^|[^\w&#;])(\d+(?:\.\d+)?)\b/g, '$1<span class="num">$2</span>');
}

function prettySQL(sql) {
  if (!sql || sql.includes('\n')) return sql || '';
  return sql.replace(/\s+(FROM|WHERE|GROUP BY|ORDER BY|HAVING|LEFT JOIN|RIGHT JOIN|INNER JOIN|JOIN|UNION)\s+/gi, '\n$1 ').replace(/\s+(AND|OR)\s+/g, '\n  $1 ');
}

function md(text) {
  const html = window.marked ? marked.parse(text || '') : esc(text);
  return window.DOMPurify ? DOMPurify.sanitize(html) : html;
}

// ------------------------------------------------------------------ charts
function columnIndex(cols, name) {
  if (!name) return -1;
  const n = String(name).toLowerCase();
  return cols.findIndex((c) => c.name.toLowerCase() === n);
}

function normalizeSpec(result, spec) {
  const cols = result.columns || [], rows = result.rows || [];
  spec = Object.assign({}, spec || {});
  const isNum = (i) => cols[i].type === 'number' || (rows.length && rows.every((r) => r[i] == null || typeof r[i] === 'number'));
  const numeric = cols.map((c, i) => (isNum(i) ? c.name : null)).filter(Boolean);
  let x = cols[columnIndex(cols, spec.x)]?.name;
  const series = cols[columnIndex(cols, spec.series)]?.name;
  let y = (Array.isArray(spec.y) ? spec.y : spec.y ? [spec.y] : []).map((n) => cols[columnIndex(cols, n)]?.name).filter(Boolean);
  if (!x) x = cols.find((c) => !numeric.includes(c.name))?.name || cols[0]?.name;
  let type = spec.type;
  if (!y.length) y = numeric.filter((n) => n !== x && n !== series);
  if (type === 'kpi' && !(Array.isArray(spec.y) && spec.y.length)) y = numeric;
  if (!type || !CHART_KEYS.includes(type)) {
    if (rows.length === 1 && numeric.length && cols.length <= 3) type = 'kpi';
    else if (/^(data|dia|mes|mês|ano|semana|periodo|date|day|month|year|week|period)/i.test(x || '')) type = 'line';
    else type = rows.length > 12 ? 'hbar' : 'bar';
  }
  if (!y.length && type !== 'table') type = 'table';
  if (type === 'kpi' && !numeric.length) type = 'table';
  return { type, x, y, series };
}

function destroyChart(box) {
  const c = state.charts.get(box);
  if (c) { c.destroy(); state.charts.delete(box); }
}

/** Renders a result (chart, KPI or table) inside `box`. */
function renderViz(box, result, spec, opts = {}) {
  destroyChart(box);
  box.innerHTML = '';
  const s = normalizeSpec(result, spec);
  const cols = result.columns || [], rows = result.rows || [];
  if (!rows.length) { box.append(h('div', { class: 'muted', style: 'padding:18px' }, t('res.noRows'))); return s; }
  if (s.type === 'table') { box.append(renderTable(result)); return s; }
  if (s.type === 'kpi') {
    const r = rows[0], wrap = h('div', { class: 'kpis' });
    s.y.forEach((name) => {
      const i = columnIndex(cols, name);
      const prev = opts.previous?.[name];
      const v = h('div', { class: 'v' + (prev !== undefined && prev !== r[i] ? ' flash' : '') }, fmt(r[i]));
      wrap.append(h('div', { class: 'kpi' }, v, h('div', { class: 'l' }, labelize(name))));
    });
    box.append(wrap);
    return s;
  }
  const xi = columnIndex(cols, s.x);
  // time series always in chronological order
  let rowsSorted = rows;
  if (['line', 'area', 'bar'].includes(s.type) && rows.every((r) => /^\d{4}(-\d{2})?(-\d{2})?/.test(String(r[xi] ?? '')))) {
    rowsSorted = [...rows].sort((a, b) => String(a[xi]).localeCompare(String(b[xi])));
  }
  const canvasBox = h('div', { class: 'chart-box' });
  const canvas = h('canvas');
  canvasBox.append(canvas);
  box.append(canvasBox);
  let labels, datasets;
  const kind = s.type === 'hbar' ? 'bar' : s.type === 'area' ? 'line' : s.type;
  if (s.type === 'scatter') {
    const yi = columnIndex(cols, s.y[0]);
    datasets = [{ label: labelize(s.y[0]), data: rowsSorted.map((r) => ({ x: r[xi], y: r[yi] })), backgroundColor: PALETTE[0] }];
  } else if (s.series && s.type !== 'pie' && s.type !== 'doughnut') {
    const si = columnIndex(cols, s.series), yi = columnIndex(cols, s.y[0]);
    labels = [...new Set(rowsSorted.map((r) => fmt(r[xi], cols[xi].type)))];
    const groups = [...new Set(rowsSorted.map((r) => r[si]))];
    datasets = groups.map((g, k) => {
      const data = labels.map(() => null);
      rowsSorted.forEach((r) => { if (r[si] === g) { const j = labels.indexOf(fmt(r[xi], cols[xi].type)); data[j] = (data[j] || 0) + (r[yi] || 0); } });
      return dataset(String(g ?? t('res.empty')), data, k, s.type);
    });
  } else {
    labels = rowsSorted.map((r) => fmt(r[xi], cols[xi].type));
    const ys = s.type === 'pie' || s.type === 'doughnut' ? s.y.slice(0, 1) : s.y;
    datasets = ys.map((name, k) => dataset(labelize(name), rowsSorted.map((r) => r[columnIndex(cols, name)]), k, s.type, rowsSorted.length));
  }
  const dark = matchMedia('(prefers-color-scheme: dark)').matches;
  const grid = dark ? 'rgba(255,255,255,.08)' : 'rgba(0,0,0,.06)';
  const tick = dark ? '#98a0b8' : '#687089';
  const round = s.type === 'pie' || s.type === 'doughnut';
  const chart = new Chart(canvas, {
    type: kind,
    data: { labels, datasets },
    options: {
      responsive: true, maintainAspectRatio: false, animation: opts.animate === false ? false : { duration: 500 },
      locale: t('locale'),
      indexAxis: s.type === 'hbar' ? 'y' : 'x',
      interaction: { mode: round || s.type === 'scatter' ? 'nearest' : 'index', intersect: false },
      plugins: {
        legend: { display: round || datasets.length > 1, position: round ? 'right' : 'top', labels: { color: tick, boxWidth: 12 } },
        tooltip: { callbacks: { label: (c) => ` ${c.dataset.label || c.label}: ${nf.format(c.raw?.y ?? c.raw ?? 0)}` } },
      },
      scales: round ? {} : {
        x: { grid: { color: grid }, ticks: Object.assign({ color: tick, maxRotation: 45, autoSkip: true }, s.type === 'hbar' ? { callback: (v) => nfCompact.format(v) } : {}) },
        y: { grid: { color: grid }, ticks: { color: tick, callback: s.type === 'hbar' ? function (v) { return String(this.getLabelForValue(v)).slice(0, 28); } : (v) => nfCompact.format(v) }, beginAtZero: true },
      },
    },
  });
  state.charts.set(box, chart);
  return s;
}

function dataset(label, data, k, type, n) {
  const color = PALETTE[k % PALETTE.length];
  if (type === 'pie' || type === 'doughnut') return { label, data, backgroundColor: data.map((_, i) => PALETTE[i % PALETTE.length]), borderWidth: 1 };
  if (type === 'line' || type === 'area') return { label, data, borderColor: color, backgroundColor: color + '33', fill: type === 'area', tension: 0.3, pointRadius: (n || data.length) > 40 ? 0 : 3, spanGaps: true };
  return { label, data, backgroundColor: color + 'dd', borderRadius: 4, maxBarThickness: 48 };
}

const labelize = (name) => String(name || '').replace(/_/g, ' ').replace(/([a-z])([A-Z])/g, '$1 $2');

function renderTable(result, limit = 500) {
  const cols = result.columns || [], rows = result.rows || [];
  const table = h('table', { class: 'data' },
    h('thead', {}, h('tr', {}, cols.map((c) => h('th', {}, c.name)))),
    h('tbody', {}, rows.slice(0, limit).map((r) => h('tr', {}, r.map((v, i) => h('td', { class: typeof v === 'number' ? 'n' : '' }, fmt(v, cols[i].type)))))));
  const box = h('div', { class: 'table-box' }, table);
  if (rows.length > limit) box.append(h('div', { class: 'tiny muted', style: 'padding:6px 10px' }, t('res.showing', { a: limit, b: rows.length })));
  return box;
}

/** CSV in the language convention: EN uses , and a decimal point; PT-BR uses ; and a decimal comma (Excel BR). */
function toCSV(result) {
  const sep = LANG === 'en' ? ',' : ';';
  const q = (v) => { const s = v == null ? '' : String(v); return (s.includes(sep) || /["\n]/.test(s)) ? '"' + s.replace(/"/g, '""') + '"' : s; };
  const num = (v) => (LANG === 'en' ? String(v) : String(v).replace('.', ','));
  const lines = [result.columns.map((c) => q(c.name)).join(sep)];
  result.rows.forEach((r) => lines.push(r.map((v) => (typeof v === 'number' ? num(v) : q(v))).join(sep)));
  return '﻿' + lines.join('\n');
}

function download(name, text, type = 'text/csv;charset=utf-8') {
  const a = h('a', { href: URL.createObjectURL(new Blob([text], { type })), download: name });
  document.body.append(a); a.click(); a.remove();
}

// ------------------------------------------------------------------ result card
/** item: {question, title, sql, explanation, chart, result, error, suggestions, viewName, attempts, elapsedMs} */
function resultCard(item) {
  const card = h('div', { class: 'card' });
  const draw = () => {
    card.innerHTML = '';
    card.append(h('h3', {}, item.title || t('res.default')));
    const meta = h('div', { class: 'meta' });
    if (item.result) meta.append(h('span', { class: 'pill good' }, t('res.rows', { n: nf.format(item.result.rowCount) }) + (item.result.truncated ? t('res.limited') : '')), h('span', { class: 'pill' }, `SQL ${item.result.elapsedMs} ms`));
    if (item.elapsedMs) meta.append(h('span', { class: 'pill' }, t('res.ai', { s: nf.format(+(item.elapsedMs / 1000).toFixed(1)) })));
    if (item.attempts > 1) meta.append(h('span', { class: 'pill warn', title: t('res.autofixedTip') }, t('res.autofixed', { n: item.attempts })));
    if (item.autoSources) meta.append(h('span', { class: 'pill', title: t('res.autoTip') }, t('res.auto', { s: item.autoSources.split(',').map((x) => x.split('_').slice(-2).join('_')).join(', ') })));
    if (item.interop?.sessionId) meta.append(h('span', { class: 'pill link', title: t('res.interopTip'), onclick: () => openTrace(item.interop.sessionId) }, t('res.interop', { n: item.interop.sessionId })));
    card.append(meta);
    if (item.explanation) card.append(h('div', { class: 'explain md', html: md(item.explanation) }));
    if (item.sql) card.append(sqlBlock(item.sql));
    if (item.error) {
      card.append(h('div', { class: 'err-box' }, item.error));
      card.append(h('div', { class: 'actions' }, h('button', { class: 'btn primary small', onclick: (e) => fixWithAI(item, e.target, draw) }, t('res.fix')), h('button', { class: 'btn ghost small', onclick: () => openInEditor(item.sql) }, t('res.openEditor'))));
    }
    if (item.result) {
      const vizBox = h('div');
      let view = item.view || (normalizeSpec(item.result, item.chart).type === 'table' ? 'table' : 'chart');
      const typeSel = h('select', { title: t('res.chartType') }, chartTypes().filter(([k]) => k !== 'table').map(([k, l]) => h('option', { value: k }, l)));
      const tabs = h('div', { class: 'res-tabs' },
        h('button', { class: 'tab', 'data-v': 'chart' }, t('res.chart')), h('button', { class: 'tab', 'data-v': 'table' }, t('res.table')), typeSel);
      const show = () => {
        $$('.tab', tabs).forEach((b) => b.classList.toggle('active', b.dataset.v === view));
        typeSel.style.display = view === 'chart' ? '' : 'none';
        if (view === 'table') { destroyChart(vizBox); vizBox.innerHTML = ''; vizBox.append(renderTable(item.result)); }
        else { const s = renderViz(vizBox, item.result, item.chart); typeSel.value = s.type === 'table' ? 'bar' : s.type; item.chart = Object.assign({}, item.chart, s); }
      };
      tabs.addEventListener('click', (e) => { if (e.target.dataset.v) { view = item.view = e.target.dataset.v; show(); } });
      typeSel.addEventListener('change', () => { item.chart = Object.assign({}, item.chart, { type: typeSel.value }); show(); });
      card.append(tabs, vizBox);
      requestAnimationFrame(show);
      const insightBox = h('div');
      card.append(h('div', { class: 'actions' },
        h('button', { class: 'btn primary small', onclick: () => addToDashboard(item) }, t('res.addDash')),
        h('button', { class: 'btn ghost small', onclick: () => createView(item) }, t('res.createView')),
        h('button', { class: 'btn ghost small', onclick: () => scheduleReport(item) }, t('res.schedule')),
        h('button', { class: 'btn ghost small', onclick: (e) => insight(item, insightBox, e.target) }, t('res.insight')),
        h('button', { class: 'btn ghost small', onclick: () => tuneWithAI(item, draw) }, t('res.tune')),
        h('button', { class: 'btn ghost small', onclick: () => download((item.viewName || t('res.csvName')) + '.csv', toCSV(item.result)) }, '⬇ CSV'),
        h('button', { class: 'btn ghost small', onclick: () => openInEditor(item.sql) }, t('res.editor'))), insightBox);
    }
    if (item.suggestions?.length) {
      card.append(h('div', { class: 'chips', style: 'justify-content:flex-start;margin:12px 0 0' }, item.suggestions.map((q) => h('button', { class: 'chip', onclick: () => ask(q) }, '↳ ' + q))));
    }
  };
  draw();
  return card;
}

function sqlBlock(sql) {
  return h('details', { class: 'sql' },
    h('summary', {}, t('res.sql'), h('span', { class: 'spacer' }),
      h('button', { class: 'icon-btn', title: t('res.copy'), onclick: (e) => { e.preventDefault(); navigator.clipboard.writeText(sql); toast(t('res.copied')); } }, '⧉')),
    h('pre', { class: 'code', html: highlightSQL(prettySQL(sql)) }));
}

async function fixWithAI(item, btn, redraw) {
  btn.disabled = true; btn.textContent = t('res.fixing');
  try {
    const r = await api('fix', { sql: item.sql, error: item.error, schemas: schemasParam() });
    Object.assign(item, { sql: r.sql, explanation: r.explanation, result: r.result, error: r.error });
    redraw();
  } catch (e) { toast(e.message, true); btn.disabled = false; btn.textContent = t('res.fix'); }
}

async function tuneWithAI(item, redraw) {
  const v = await dialog(t('tune.title'), [{ name: 'instruction', label: t('tune.label'), type: 'textarea', placeholder: t('tune.ph') }], t('tune.ok'));
  if (!v?.instruction) return;
  toast(t('tune.working'));
  try {
    const r = await api('fix', { sql: item.sql, instruction: v.instruction, schemas: schemasParam() });
    Object.assign(item, { sql: r.sql, explanation: r.explanation, result: r.result, error: r.error, view: null });
    item.chart = {};
    redraw();
  } catch (e) { toast(e.message, true); }
}

async function insight(item, box, btn) {
  btn.disabled = true;
  box.innerHTML = '';
  box.append(thinking(t('res.analyzing')));
  try {
    const r = await api('insight', { question: item.question || item.title, sql: item.sql, data: item.result });
    box.innerHTML = '';
    box.append(h('div', { class: 'insight md', html: md(r.text) }));
    if (r.privacy) box.append(h('div', { class: 'tiny muted privacy-note' }, t('privacy.insight')));
  } catch (e) { box.innerHTML = ''; toast(e.message, true); }
  btn.disabled = false;
}

function thinking(text) {
  const label = h('span', {}, Array.isArray(text) ? text[0] : text);
  const el = h('div', { class: 'thinking' }, h('span', { class: 'dots' }, h('span'), h('span'), h('span')), label);
  if (Array.isArray(text)) {
    let i = 0;
    const timer = setInterval(() => { if (!el.isConnected) return clearInterval(timer); i = Math.min(i + 1, text.length - 1); label.textContent = text[i]; }, 2200);
  }
  return el;
}

// ------------------------------------------------------------------ chat
function scrollChat() { const c = $('#chat'); c.scrollTop = c.scrollHeight; }

function pushMsg(node, who = 'bot') {
  $('#welcome')?.classList.add('hidden');
  const m = h('div', { class: 'msg ' + who }, node);
  $('#chat').append(m);
  scrollChat();
  return m;
}

async function ask(question) {
  question = (question || '').trim();
  if (!question) return;
  $('#question').value = '';
  autoGrow();
  pushMsg(h('div', { class: 'bubble' }, question), 'user');
  const wait = pushMsg(h('div', { class: 'card' }, thinking(t(state.mode === 'agent' ? 'ask.stepsAgent' : 'ask.stepsSql'))));
  $('#sendBtn').disabled = true;
  try {
    if (state.mode === 'agent') {
      const r = await api('agent', { message: question, sessionId: state.agentSession, schemas: schemasParam() });
      state.agentSession = r.sessionId || state.agentSession;
      wait.remove();
      const card = h('div', { class: 'card' }, r.autoSources ? h('div', { class: 'meta' }, h('span', { class: 'pill', title: t('res.autoTip') }, t('res.auto', { s: r.autoSources.split(',').map((x) => x.split('_').slice(-2).join('_')).join(', ') }))) : null, h('div', { class: 'md', html: md(r.text) }));
      // the agent may write its final query in a ```sql block without running it through the tool
      if (!r.sqls?.length) {
        const blocks = [...String(r.text || '').matchAll(/```sql\s*([\s\S]*?)```/gi)].map((m) => m[1].trim()).filter(Boolean);
        if (blocks.length) r.sqls = [blocks[blocks.length - 1]];
      }
      if (r.sqls?.length) {
        const box = h('div');
        card.append(h('div', { class: 'actions' }, h('span', { class: 'tiny muted' }, t('ask.agentQueries', { n: r.sqls.length })),
          r.sqls.slice(-4).map((sql, i) => h('button', { class: 'btn ghost small', title: sql, onclick: () => showAgentQuery(sql, question, box) }, t('ask.viewResult', { n: i + 1 })))), box);
        if (r.privacy) {
          card.append(h('div', { class: 'tiny muted privacy-note' }, t('privacy.agent')));
          showAgentQuery(r.sqls[r.sqls.length - 1], question, box);
        }
      }
      pushMsg(card);
    } else {
      const r = await api('ask', { question, schemas: schemasParam(), history: state.history.slice(-8) });
      wait.remove();
      if (r.type === 'message') {
        pushMsg(h('div', { class: 'card' }, h('div', { class: 'md', html: md(r.message) }),
          r.suggestions?.length ? h('div', { class: 'chips', style: 'justify-content:flex-start' }, r.suggestions.map((q) => h('button', { class: 'chip', onclick: () => ask(q) }, q))) : null));
        state.history.push({ role: 'user', content: question }, { role: 'assistant', content: JSON.stringify({ message: r.message }) });
      } else {
        r.question = question;
        pushMsg(resultCard(r));
        state.history.push({ role: 'user', content: question }, { role: 'assistant', content: JSON.stringify({ title: r.title, sql: r.sql }) });
      }
    }
  } catch (e) {
    wait.remove();
    pushMsg(h('div', { class: 'card' }, h('div', { class: 'err-box' }, e.message)));
  }
  $('#sendBtn').disabled = false;
  refreshStatus();
}

async function showAgentQuery(sql, question, box) {
  box.innerHTML = '';
  try {
    const r = await api('run', { sql });
    if (r.error) throw new Error(r.error);
    box.append(resultCard({ title: t('ask.agentQuery'), sql, result: r, question, chart: {} }));
  } catch (e) { toast(e.message, true); }
}

function autoGrow() { const q = $('#question'); q.style.height = 'auto'; q.style.height = Math.min(q.scrollHeight, 180) + 'px'; }

function renderSuggestions(list) {
  const box = $('#suggestions');
  box.innerHTML = '';
  list.forEach((q) => box.append(h('button', { class: 'chip', onclick: () => ask(q) }, q)));
}

function setModePlaceholder() {
  $('#question').placeholder = t(state.mode === 'agent' ? 'ask.phAgent' : 'ask.phSql');
}

// ------------------------------------------------------------------ dialogs
function dialog(title, fields, okText) {
  return new Promise((resolve) => {
    const dlg = $('#dlg');
    $('#dlgTitle').textContent = title;
    $('#dlgOk').textContent = okText || t('dlg.save');
    const body = $('#dlgBody');
    body.innerHTML = '';
    const inputs = {};
    const group = (list) => list.map((f) => {
      if (Array.isArray(f)) return h('div', { class: 'row2' }, group(f));
      let input;
      if (f.type === 'select') input = h('select', { name: f.name }, f.options.map(([v, l]) => h('option', { value: v, selected: String(v) === String(f.value ?? '') }, l)));
      else if (f.type === 'textarea') input = h('textarea', { name: f.name, placeholder: f.placeholder || '' });
      else input = h('input', { name: f.name, placeholder: f.placeholder || '', required: f.required });
      if (f.type !== 'select') input.value = f.value ?? '';
      inputs[f.name] = input;
      return h('label', {}, f.label, input, f.hint ? h('span', { class: 'tiny muted' }, f.hint) : null);
    });
    body.append(...group(fields));
    const onClose = () => {
      dlg.removeEventListener('close', onClose);
      if (dlg.returnValue !== 'ok') return resolve(null);
      const out = {};
      for (const [k, el] of Object.entries(inputs)) out[k] = el.value;
      resolve(out);
    };
    dlg.addEventListener('close', onClose);
    dlg.returnValue = '';
    dlg.showModal();
    setTimeout(() => Object.values(inputs)[0]?.focus(), 30);
  });
}

async function addToDashboard(item) {
  const list = (await api('dashboards.list')).dashboards;
  const opts = list.map((d) => [d.id, d.name]).concat([['__new', t('add.new')]]);
  const s = normalizeSpec(item.result, item.chart);
  const v = await dialog(t('add.title'), [
    { name: 'dashboard', label: t('add.dashboard'), type: 'select', options: opts, value: state.dashboard?.id || opts[0][0] },
    { name: 'newName', label: t('add.newName'), placeholder: t('add.newNamePh'), hint: t('add.newNameHint') },
    { name: 'title', label: t('add.widgetTitle'), value: item.title || '' },
    [{ name: 'type', label: t('add.viz'), type: 'select', options: chartTypes(), value: s.type },
      { name: 'width', label: t('add.width'), type: 'select', options: widthOptions(), value: s.type === 'kpi' ? 1 : s.type === 'table' ? 4 : 2 }],
  ], t('add.ok'));
  if (!v) return;
  try {
    let id = v.dashboard;
    if (id === '__new') id = (await api('dashboards.save', { name: v.newName || item.title || t('add.defaultName'), refreshSeconds: 15 })).id;
    await api('widgets.save', { dashboardId: id, title: v.title, sql: item.sql, chart: Object.assign({}, s, { type: v.type }), width: +v.width });
    toast(t('add.done'));
    state.pendingDashboard = id;
  } catch (e) { toast(e.message, true); }
}

async function createView(item) {
  const v = await dialog(t('view.title'), [
    { name: 'name', label: t('view.name', { s: state.status?.viewSchema || 'Analytics' }), value: item.viewName || t('view.default'), required: true, hint: t('view.hint') },
    { name: 'description', label: t('view.desc'), value: item.title || '' },
  ], t('view.ok'));
  if (!v) return;
  try {
    const r = await api('views.create', { name: v.name, sql: item.sql, description: v.description });
    toast(t('view.done', { n: r.fullName }));
    state.catalog = null;
  } catch (e) { toast(e.message, true); }
}

// ------------------------------------------------------------------ editor SQL
function openInEditor(sql) {
  $('#sqlEditor').value = prettySQL(sql || '');
  go('editor');
}

async function runEditor() {
  const sql = $('#sqlEditor').value.trim();
  if (!sql) return;
  const out = $('#editorOut');
  out.innerHTML = '';
  out.append(h('div', { class: 'card' }, thinking(t('ed.running'))));
  try {
    const r = await api('run', { sql });
    out.innerHTML = '';
    out.append(resultCard(r.error ? { title: t('ed.error'), sql, error: r.error } : { title: t('res.default'), sql, result: r, chart: {}, view: 'table' }));
  } catch (e) { out.innerHTML = ''; toast(e.message, true); }
}

async function explainEditor() {
  const sql = $('#sqlEditor').value.trim();
  if (!sql) return;
  const box = h('div', { class: 'card' }, thinking(t('ed.reading')));
  $('#editorOut').prepend(box);
  try {
    const r = await api('explain', { sql, schemas: schemasParam() });
    box.innerHTML = '';
    box.append(h('h3', {}, t('ed.explanation')), h('div', { class: 'md', html: md(r.text) }));
  } catch (e) { box.remove(); toast(e.message, true); }
}

async function tuneEditor() {
  const sql = $('#sqlEditor').value.trim();
  const v = await dialog(t('ed.tuneTitle'), [{ name: 'instruction', label: t(sql ? 'ed.tuneChange' : 'ed.tuneDescribe'), type: 'textarea' }], t('ed.generate'));
  if (!v?.instruction) return;
  const out = $('#editorOut');
  out.innerHTML = '';
  out.append(h('div', { class: 'card' }, thinking(t('ed.generating'))));
  try {
    const r = await api('fix', { sql: sql || 'SELECT 1', instruction: v.instruction, schemas: schemasParam() });
    $('#sqlEditor').value = prettySQL(r.sql);
    out.innerHTML = '';
    out.append(resultCard({ title: t('ed.tuned'), sql: r.sql, explanation: r.explanation, result: r.result, error: r.error, chart: {} }));
  } catch (e) { out.innerHTML = ''; toast(e.message, true); }
}

// ------------------------------------------------------------------ dashboards
async function loadDashboards(selectId) {
  const list = (await api('dashboards.list')).dashboards;
  state.dashboards = list;
  const sel = $('#dashSelect');
  sel.innerHTML = '';
  list.forEach((d) => sel.append(h('option', { value: d.id }, `${d.name} (${d.widgetCount})`)));
  const id = selectId || state.pendingDashboard || state.dashboard?.id || list[0]?.id;
  state.pendingDashboard = null;
  if (id) { sel.value = id; await openDashboard(id); }
  else { state.dashboard = null; $('#dashGrid').innerHTML = ''; $('#dashEmpty').classList.remove('hidden'); $('#dashDesc').textContent = ''; stopTimer(); }
}

async function openDashboard(id) {
  stopTimer();
  const d = await api('dashboards.get', { id });
  state.dashboard = d;
  $('#dashDesc').textContent = d.description || '';
  $('#dashRefresh').value = String(d.refreshSeconds || 0);
  const grid = $('#dashGrid');
  grid.querySelectorAll('.widget-body').forEach(destroyChart);
  grid.innerHTML = '';
  $('#dashEmpty').classList.toggle('hidden', d.widgets.length > 0);
  d.widgets.forEach((w) => grid.append(widgetEl(w)));
  await refreshWidgets(true);
  startTimer();
}

function widgetEl(w) {
  const body = h('div', { class: 'widget-body' }, thinking(t('dash.loading')));
  const foot = h('div', { class: 'widget-foot' }, h('span', { class: 'upd' }, ''), h('span', { class: 'rows' }, ''));
  const el = h('div', { class: 'widget w' + (w.width || 2), 'data-id': w.id },
    h('div', { class: 'widget-head' }, h('h4', { title: w.title }, w.title || 'Widget'),
      h('button', { class: 'icon-btn', title: t('dash.sqlTip'), onclick: () => openInEditor(w.sql) }, '⌨'),
      h('button', { class: 'icon-btn', title: t('dash.editTip'), onclick: () => editWidget(w) }, '✎'),
      h('button', { class: 'icon-btn', title: t('dash.removeTip'), onclick: () => removeWidget(w) }, '✕')),
    body, foot);
  el._w = w;
  return el;
}

async function refreshWidgets(first = false) {
  const queue = $$('#dashGrid .widget');
  const worker = async () => {
    while (queue.length) {
      const el = queue.shift();
      const w = el._w, body = $('.widget-body', el);
      try {
        const r = await api('run', { sql: w.sql, silent: true, maxRows: 500 });
        if (r.error) throw new Error(r.error);
        // previous values, to highlight KPIs that changed
        const prev = {};
        if (el._last?.rows?.[0]) el._last.columns.forEach((c, i) => (prev[c.name] = el._last.rows[0][i]));
        renderViz(body, r, w.chart, { animate: first, previous: first ? undefined : prev });
        el._last = r;
        $('.upd', el).textContent = t('dash.updated', { t: new Date().toLocaleTimeString(t('locale')) });
        $('.rows', el).textContent = t('dash.rowsMs', { n: r.rowCount, ms: r.elapsedMs });
      } catch (e) {
        destroyChart(body);
        body.innerHTML = '';
        body.append(h('div', { class: 'err-box' }, e.message));
      }
    }
  };
  await Promise.all([worker(), worker(), worker()]);
}

function startTimer() {
  stopTimer();
  const secs = +(state.dashboard?.refreshSeconds || 0);
  $('#liveBadge').classList.toggle('hidden', !secs);
  if (secs > 0) state.timer = setInterval(() => { if (!document.hidden && $('#view-dashboards').classList.contains('active')) refreshWidgets(); }, secs * 1000);
}
function stopTimer() { if (state.timer) clearInterval(state.timer); state.timer = null; $('#liveBadge')?.classList.add('hidden'); }

async function editWidget(w) {
  const s = w.chart || {};
  const v = await dialog(t('dash.editTitle'), [
    { name: 'title', label: t('dash.wTitle'), value: w.title },
    { name: 'sql', label: 'SQL', type: 'textarea', value: w.sql },
    [{ name: 'type', label: t('add.viz'), type: 'select', options: chartTypes(), value: s.type || 'bar' },
      { name: 'width', label: t('add.width'), type: 'select', options: widthOptions(), value: w.width }],
    [{ name: 'x', label: t('dash.x'), value: s.x || '' }, { name: 'y', label: t('dash.y'), value: (s.y || []).join(', ') }],
    { name: 'series', label: t('dash.series'), value: s.series || '' },
  ]);
  if (!v) return;
  try {
    await api('widgets.save', { id: w.id, title: v.title, sql: v.sql, width: +v.width, chart: { type: v.type, x: v.x.trim(), y: v.y.split(',').map((x) => x.trim()).filter(Boolean), series: v.series.trim() } });
    await openDashboard(state.dashboard.id);
  } catch (e) { toast(e.message, true); }
}

async function removeWidget(w) {
  if (!confirm(t('dash.confirmRemove', { n: w.title }))) return;
  await api('widgets.delete', { id: w.id });
  await loadDashboards(state.dashboard.id);
}

async function generateDashboard() {
  const v = await dialog(t('dash.genTitle'), [{ name: 'prompt', label: t('dash.genLabel'), type: 'textarea', placeholder: t('dash.genPh') }], t('ed.generate'));
  if (!v?.prompt) return;
  const grid = $('#dashGrid');
  stopTimer();
  grid.querySelectorAll('.widget-body').forEach(destroyChart);
  grid.innerHTML = '';
  $('#dashEmpty').classList.add('hidden');
  grid.append(h('div', { class: 'card', style: 'grid-column: span 4' }, thinking(t('dash.genSteps'))));
  try {
    const d = await api('dashboards.generate', { prompt: v.prompt, schemas: schemasParam() });
    if (d.skipped?.length) toast(t('dash.skipped', { n: d.skipped.length }), true);
    else toast(t('dash.created'));
    await loadDashboards(d.id);
  } catch (e) { toast(e.message, true); await loadDashboards(); }
}

// ------------------------------------------------------------------ views / catalog / history
function renderViewsIntro() {
  $('#viewsIntro').innerHTML = t('views.intro', { s: esc(state.status?.viewSchema || 'Analytics') });
}

async function loadViews() {
  const box = $('#viewsList');
  box.innerHTML = '';
  box.append(thinking(t('dash.loading')));
  const r = await api('views.list');
  renderViewsIntro();
  box.innerHTML = '';
  if (!r.views.length) { box.append(h('div', { class: 'empty' }, h('h3', {}, t('views.none')), h('p', { class: 'muted' }, t('views.noneHint')))); return; }
  r.views.forEach((v) => box.append(h('div', { class: 'card' },
    h('h3', {}, v.fullName),
    h('div', { class: 'meta' }, v.description ? h('span', { class: 'pill' }, v.description) : null, v.createdBy ? h('span', { class: 'pill' }, t('views.by', { u: v.createdBy, d: fmt(v.createdAt, 'timestamp') })) : null),
    h('pre', { class: 'code', style: 'border-radius:10px', html: highlightSQL(prettySQL(v.definition)) }),
    h('div', { class: 'actions' },
      h('button', { class: 'btn primary small', onclick: () => { openInEditor(`SELECT TOP 100 * FROM ${v.fullName}`); runEditor(); } }, t('views.query')),
      h('button', { class: 'btn ghost small', onclick: () => { go('ask'); $('#question').value = t('views.askPrefix', { n: v.fullName }); $('#question').focus(); } }, t('views.ask')),
      h('button', { class: 'btn ghost small danger', onclick: async () => { if (confirm(t('views.confirmDelete', { n: v.fullName }))) { try { await api('views.drop', { name: v.name }); loadViews(); } catch (e) { toast(e.message, true); } } } }, t('views.delete'))))));
}

async function loadGlossary() {
  const box = $('#glossaryList');
  const r = await api('glossary.list');
  box.innerHTML = '';
  if (!r.terms.length) { box.append(h('p', { class: 'muted' }, t('gl.none'))); return; }
  r.terms.forEach((g) => box.append(h('div', { class: 'gl-item' + (g.active ? '' : ' off') },
    h('b', {}, g.term),
    h('div', {}, g.definition, h('div', { class: 'tiny muted' }, `${t(g.active ? 'gl.active' : 'gl.inactive')} · ${g.updatedBy || ''} ${fmt(g.updatedAt, 'timestamp')}`)),
    h('div', { class: 'actions', style: 'margin:0' },
      h('button', { class: 'btn ghost small', onclick: () => editGlossary(g) }, t('gl.edit')),
      h('button', { class: 'btn ghost small danger', onclick: async () => { if (confirm(t('gl.confirmDelete', { n: g.term }))) { await api('glossary.delete', { id: g.id }); loadGlossary(); } } }, t('gl.delete'))))));
}

async function editGlossary(g = {}) {
  const v = await dialog(t(g.id ? 'gl.editTitle' : 'gl.newTitle'), [
    { name: 'term', label: t('gl.term'), value: g.term || '', placeholder: t('gl.termPh'), required: true },
    { name: 'definition', label: t('gl.def'), type: 'textarea', value: g.definition || '', placeholder: t('gl.defPh') },
    { name: 'active', label: t('gl.status'), type: 'select', options: [[1, t('gl.statusOn')], [0, t('gl.statusOff')]], value: g.id ? g.active : 1 },
  ]);
  if (!v || !v.term.trim() || !v.definition.trim()) return;
  try {
    await api('glossary.save', { id: g.id || '', term: v.term, definition: v.definition, active: +v.active });
    toast(t('gl.saved'));
    loadGlossary();
  } catch (e) { toast(e.message, true); }
}

async function loadCatalog(force = false) {
  loadGlossary().catch((e) => toast(e.message, true));
  return loadCatalogList(force);
}

async function loadCatalogList(force = false) {
  const box = $('#catalogList');
  if (force) { await api('catalog.refresh'); state.catalog = null; }
  if (!state.catalog) {
    box.innerHTML = '';
    box.append(thinking(t('cat.reading')));
    state.catalog = (await api('catalog', { schemas: [] })).tables;
  }
  const f = $('#catalogFilter').value.trim().toLowerCase();
  box.innerHTML = '';
  const bySchema = {};
  state.catalog.forEach((tb) => {
    if (f && !(tb.fullName.toLowerCase().includes(f) || tb.description?.toLowerCase().includes(f) || tb.columns.some((c) => c.name.toLowerCase().includes(f)))) return;
    (bySchema[tb.schema] ||= []).push(tb);
  });
  for (const [schema, tables] of Object.entries(bySchema)) {
    box.append(h('div', {}, h('h3', {}, `${schema} `, h('span', { class: 'pill' }, `${tables.length}`)),
      h('div', { class: 'tbl-grid' }, tables.map((tb) => h('div', { class: 'tbl' },
        h('div', { class: 'tbl-head' }, h('b', {}, (tb.type === 'view' ? '🧩 ' : '▦ ') + tb.name),
          h('button', { class: 'icon-btn', title: t('cat.preview'), onclick: () => { openInEditor(`SELECT TOP 100 * FROM ${tb.fullName}`); runEditor(); } }, '▶'),
          h('button', { class: 'icon-btn', title: t('cat.ask'), onclick: () => { go('ask'); $('#question').value = t('cat.askPrefix', { n: tb.fullName }); $('#question').focus(); } }, '💬')),
        tb.description ? h('div', { class: 'desc' }, tb.description) : null,
        h('ul', {}, tb.columns.map((c) => h('li', { title: c.description || '' }, c.pk ? h('span', { class: 'pk' }, 'PK') : null, c.name,
          c.ref ? h('span', { class: 'ref' }, '→ ' + c.ref) : null, h('span', { class: 't' }, c.type)))))))));
  }
  if (!Object.keys(bySchema).length) box.append(h('p', { class: 'muted' }, t('cat.nothing')));
}

async function loadHistory() {
  const box = $('#historyList');
  box.innerHTML = '';
  box.append(thinking(t('dash.loading')));
  const r = await api('history', { limit: 150 });
  box.innerHTML = '';
  if (!r.history.length) { box.append(h('p', { class: 'muted' }, t('hist.empty'))); return; }
  r.history.forEach((it) => box.append(h('div', { class: 'hist' },
    h('div', { class: 'tiny muted' }, fmt(it.createdAt, 'timestamp'), h('br'), it.user),
    h('div', {}, h('span', { class: 'pill ' + (it.status === 'ok' ? 'good' : it.status === 'error' ? 'warn' : '') }, t('hist.kind.' + it.kind))),
    h('div', { style: 'min-width:0' }, h('div', {}, it.question), it.sql ? h('code', { title: it.sql }, it.sql) : null, it.error ? h('div', { class: 'tiny', style: 'color:var(--danger)' }, it.error) : null,
      h('div', { class: 'tiny muted' }, t('hist.meta', { n: it.rowCount, ms: it.elapsedMs }) + (it.attempts > 1 ? t('hist.attempts', { n: it.attempts }) : ''))),
    h('div', { class: 'actions', style: 'margin:0' },
      it.sql ? h('button', { class: 'btn ghost small', onclick: () => { openInEditor(it.sql); runEditor(); } }, t('hist.reopen')) : null,
      it.kind === 'ask' ? h('button', { class: 'btn ghost small', onclick: () => { go('ask'); ask(it.question); } }, t('hist.askAgain')) : null))));
}

// ------------------------------------------------------------------ workflows (interoperability)
const FLOWS = {
  ask: ['Copilot Ask Service', 'Copilot Ask Process', 'AI SQL Agent', 'IRIS SQL Executor', 'Audit Log'],
  report: ['Copilot Report Scheduler', 'Copilot Report Trigger', 'Copilot Report Process', 'IRIS SQL Executor', 'AI Report Agent', 'Report Publisher', 'Webhook Notifier', 'Audit Log'],
};
const AI_NODES = new Set(['AI SQL Agent', 'AI Report Agent']);

function minutesLabel(m) {
  m = +m;
  if (m % 10080 === 0) return `${m / 10080} ${LANG === 'en' ? 'week(s)' : 'semana(s)'}`;
  if (m % 1440 === 0) return `${m / 1440} ${LANG === 'en' ? 'day(s)' : 'dia(s)'}`;
  if (m % 60 === 0) return `${m / 60} h`;
  return `${m} min`;
}

async function loadWorkflows() {
  const st = await api('interop.status');
  $('#wfState').textContent = st.running ? t('wf.running') : t('wf.stopped');
  $('#wfState').className = 'pill ' + (st.running ? 'good' : 'warn');
  $('#wfStart').classList.toggle('hidden', !!st.running);
  const byName = Object.fromEntries((st.items || []).map((i) => [i.name, i]));
  const box = $('#wfFlows');
  box.innerHTML = '';
  for (const [key, names] of Object.entries(FLOWS)) {
    const flow = h('div', { class: 'flow' });
    names.forEach((n, i) => {
      const it = byName[n];
      if (!it) return;
      if (i > 0) flow.append(h('span', { class: 'arrow' }, key === 'report' && i === 1 ? '/' : '→'));
      flow.append(h('div', { class: `node ${it.kind} ${AI_NODES.has(n) ? 'ai' : ''} ${it.errorsLastHour ? 'err' : ''}`, title: `${it.className}\n${it.comment || ''}` },
        h('span', { class: 'k' }, (AI_NODES.has(n) ? '🤖 ' : '') + t('wf.kind.' + it.kind)), h('b', {}, n),
        h('span', { class: 'c' }, t('wf.msgs', { n: it.messagesLastHour }) + (it.errorsLastHour ? ' · ' + t('wf.errs', { n: it.errorsLastHour }) : '') + (it.queue ? ' · ' + t('wf.queue', { n: it.queue }) : ''))));
    });
    box.append(h('div', { class: 'flow-title' }, t(key === 'ask' ? 'wf.askFlow' : 'wf.reportFlow')), flow);
  }
  await Promise.all([loadSubscriptions(), loadReports(), loadSessions()]);
}

async function loadSubscriptions() {
  const r = await api('subscriptions.list');
  const box = $('#wfSubs');
  box.innerHTML = '';
  if (!r.subscriptions.length) { box.append(h('p', { class: 'muted' }, t('wf.noSubs'))); return; }
  box.append(h('table', { class: 'list' }, h('tbody', {}, r.subscriptions.map((s) => h('tr', {},
    h('td', {}, h('b', {}, s.name), s.active ? null : h('span', { class: 'pill warn', style: 'margin-left:6px' }, t('wf.paused')),
      h('div', { class: 'tiny muted' }, t('wf.every', { n: minutesLabel(s.intervalMinutes) }),
        s.alertMin || s.alertMax ? ' · ' + t('wf.alert', { r: [s.alertMin ? '< ' + s.alertMin : '', s.alertMax ? '> ' + s.alertMax : ''].filter(Boolean).join(' / ') }) : '',
        s.webhook ? ' · webhook' : ''),
      h('div', { class: 'tiny muted' }, s.lastRunAt ? t('wf.last', { d: fmt(s.lastRunAt, 'timestamp') }) : '', s.nextRunAt && s.active ? ' · ' + t('wf.next', { d: fmt(s.nextRunAt, 'timestamp') }) : '')),
    h('td', { style: 'text-align:right;white-space:nowrap' },
      h('button', { class: 'btn primary small', onclick: () => runSubscription(s) }, t('wf.runNow')), ' ',
      h('button', { class: 'btn ghost small', onclick: async () => { await api('subscriptions.save', { id: s.id, active: s.active ? 0 : 1 }); loadSubscriptions(); } }, t(s.active ? 'wf.pause' : 'wf.resume')), ' ',
      h('button', { class: 'btn ghost small danger', onclick: async () => { if (confirm(t('wf.confirmDelete', { n: s.name }))) { await api('subscriptions.delete', { id: s.id }); loadSubscriptions(); } } }, '✕')))))));
}

async function runSubscription(s) {
  try {
    const r = await api('subscriptions.run', { id: s.id });
    toast(t('wf.started', { n: r.sessionId }));
    setTimeout(() => { if (state.view === 'workflows') { loadReports(); loadSessions(r.sessionId); loadSubscriptions(); } }, 15000);
    loadSessions(r.sessionId);
  } catch (e) { toast(e.message, true); }
}

async function loadReports() {
  const r = await api('reports.list');
  const box = $('#wfReports');
  box.innerHTML = '';
  if (!r.reports.length) { box.append(h('p', { class: 'muted' }, t('wf.noReports'))); return; }
  box.append(h('table', { class: 'list' }, h('tbody', {}, r.reports.slice(0, 15).map((rep) => h('tr', {},
    h('td', {}, rep.isAlert ? h('span', { class: 'pill warn', style: 'margin-right:6px' }, t('wf.alertBadge')) : null,
      h('a', { href: '#', onclick: (e) => { e.preventDefault(); openReport(rep.id); } }, rep.title || '#' + rep.id),
      h('div', { class: 'tiny muted' }, fmt(rep.createdAt, 'timestamp'), ' · ', rep.filePath)),
    h('td', { style: 'text-align:right' }, h('span', { class: 'pill link', onclick: () => openTrace(rep.sessionId) }, t('wf.session', { n: rep.sessionId }))))))));
}

async function openReport(id) {
  const rep = await api('reports.get', { id });
  const dlg = $('#dlg');
  $('#dlgTitle').textContent = rep.title;
  $('#dlgOk').textContent = 'OK';
  const body = $('#dlgBody');
  body.innerHTML = '';
  body.append(h('div', { class: 'md', style: 'max-height:60vh;overflow:auto', html: md(rep.markdown) }));
  dlg.returnValue = '';
  dlg.showModal();
}

async function loadSessions(selectId) {
  const r = await api('interop.sessions', { limit: 40 });
  const box = $('#wfSessions');
  box.innerHTML = '';
  if (!r.sessions.length) { box.append(h('p', { class: 'muted' }, t('wf.noSessions'))); return; }
  r.sessions.forEach((s) => box.append(h('button', { 'data-sid': s.sessionId, class: String(s.sessionId) === String(selectId) ? 'active' : '', onclick: () => showTrace(s.sessionId) },
    h('b', {}, `#${s.sessionId} `), s.kind === 'ask' ? '💬 ' : s.kind === 'report' ? '📄 ' : '', s.source,
    h('div', { class: 'tiny muted' }, fmt(s.started, 'timestamp'), ' · ', t('wf.msgCount', { n: s.messages }), s.errors ? ' · ⚠ ' + s.errors : ''))));
  if (selectId) showTrace(selectId);
}

async function showTrace(sessionId) {
  $$('#wfSessions button').forEach((b) => b.classList.toggle('active', b.dataset.sid === String(sessionId)));
  const box = $('#wfTrace');
  box.innerHTML = '';
  box.append(thinking(t('dash.loading')));
  const tr = await api('interop.trace', { sessionId });
  box.innerHTML = '';
  if (!tr.messages.length) { box.append(h('p', { class: 'muted' }, t('wf.pick'))); return; }
  tr.messages.forEach((m) => {
    const isResp = String(m.type).toLowerCase().startsWith('resp');
    const body = Object.entries(m.body || {}).map(([k, v]) => `${k}: ${v}`).join('\n');
    box.append(h('div', { class: 'tmsg' + (isResp ? ' resp' : '') + (m.isError ? ' err' : '') },
      h('div', { class: 'hd' }, h('b', {}, m.source), ' → ', h('b', {}, m.target), ' ', h('span', { class: 'pill' }, m.bodyClass.split('.').pop()), ' ',
        h('span', { class: 'tiny muted' }, `${String(m.created).slice(11, 23)} · ${m.status}`)),
      m.isError ? h('div', { class: 'err-box' }, m.error) : null,
      body ? h('details', {}, h('summary', {}, t('wf.body')), h('pre', {}, body)) : null));
  });
}

function openTrace(sessionId) {
  go('workflows');
  setTimeout(() => loadSessions(sessionId), 300);
}

async function scheduleReport(item) {
  const v = await dialog(t('sch.title'), [
    { name: 'name', label: t('sch.name'), value: item.title || '', required: true },
    { name: 'interval', label: t('sch.interval'), type: 'select', options: [[15, t('sch.15')], [60, t('sch.60')], [1440, t('sch.1440')], [10080, t('sch.10080')]], value: 1440 },
    [{ name: 'alertMin', label: t('sch.alertMin'), placeholder: t('sch.optional') }, { name: 'alertMax', label: t('sch.alertMax'), placeholder: t('sch.optional') }],
    { name: 'webhook', label: t('sch.webhook'), placeholder: 'https://...' },
  ], t('sch.ok'));
  if (!v?.name) return;
  try {
    await api('subscriptions.save', { name: v.name, question: item.question || item.title || '', sql: item.sql, intervalMinutes: +v.interval,
      alertMin: v.alertMin.trim(), alertMax: v.alertMax.trim(), webhook: v.webhook.trim(), lang: LANG });
    toast(t('sch.done'));
  } catch (e) { toast(e.message, true); }
}

// ------------------------------------------------------------------ sources (schemas)
function renderSources() {
  const pop = $('#sourcesPop');
  pop.innerHTML = '';
  pop.append(h('div', { class: 'pop-head' }, t('sources.head'), h('button', { class: 'link', onclick: () => { state.selected.clear(); saveSources(); } }, t('sources.all'))));
  state.schemas.forEach((s) => {
    const cb = h('input', { type: 'checkbox', checked: state.selected.has(s.schema) });
    cb.addEventListener('change', () => { cb.checked ? state.selected.add(s.schema) : state.selected.delete(s.schema); saveSources(); });
    pop.append(h('label', {}, cb, h('span', {}, s.schema), h('span', { class: 'tiny muted', style: 'margin-left:auto' }, `${s.tables} ${t('sources.tables')} · ${s.views} ${t('sources.views')}`)));
  });
  pop.append(h('p', { class: 'tiny muted' }, t('sources.hint')));
  $('#sourcesLabel').textContent = state.selected.size ? [...state.selected].join(', ') : t('top.all');
}
function saveSources() {
  for (const s of [...state.selected]) if (!state.schemas.some((x) => x.schema === s)) state.selected.delete(s);
  // the AI Analyst receives the catalog when a conversation starts: new sources = new conversation
  const key = [...state.selected].sort().join(',');
  if (state.sourcesKey !== undefined && state.sourcesKey !== key) { state.agentSession = ''; state.history = []; }
  state.sourcesKey = key;
  localStorage.setItem('copilot.schemas', JSON.stringify([...state.selected]));
  renderSources();
}

// ------------------------------------------------------------------ navigation / status
function go(view) {
  state.view = view;
  $$('.sidebar nav button').forEach((b) => b.classList.toggle('active', b.dataset.view === view));
  $$('.view').forEach((v) => v.classList.toggle('active', v.id === 'view-' + view));
  $('#viewTitle').textContent = t('title.' + view);
  $('.sidebar').classList.remove('open');
  if (view !== 'dashboards') stopTimer();
  const load = { dashboards: () => loadDashboards(), workflows: () => loadWorkflows(), views: loadViews, catalog: () => loadCatalog(), history: loadHistory }[view];
  if (load) load().catch((e) => toast(e.message, true));
}

async function refreshStatus() {
  try { applyStatus(await api('status')); } catch { /* ignore */ }
}

function applyStatus(s) {
  state.status = s;
  const llm = $('#llmStatus');
  llm.className = 'llm-status' + (s.llm.configured ? '' : ' off');
  llm.innerHTML = s.llm.configured
    ? `<span class="dot"></span>${t('llm.on')} · <b>${esc(s.llm.provider)}</b> / ${esc(s.llm.model)}<br><span class="tiny">${esc(t('llm.calls', { n: s.llm.callsToday, t: nf.format(s.llm.tokensToday) }))}</span>`
    : `<span class="dot"></span>${esc(t('llm.off'))}<br><span class="tiny">${esc(t('llm.offHint'))}</span>`;
  if (s.privacyMode) llm.innerHTML += `<div class="privacy" title="${esc(t('privacy.tip'))}">${esc(t('privacy.badge'))}</div>`;
  $('#irisStatus').textContent = `${s.namespace} · ${(s.iris || '').split(' (')[0]}`;
  $('#irisStatus').title = s.iris;
  $('#userBadge').textContent = s.user;
  $('#editorLimit').textContent = t('ed.limit', { n: nf.format(s.maxRows) });
  renderViewsIntro();
}

// ------------------------------------------------------------------ language
function setLanguage(lang) {
  if (lang !== 'pt' && lang !== 'en') return;
  LANG = lang;
  try { localStorage.setItem('copilot.lang', lang); } catch { /* ignore */ }
  setFormatters();
  applyStaticI18n();
  setModePlaceholder();
  renderSuggestions(t('ask.defaults'));
  if (state.status) {
    applyStatus(state.status);
    renderSources();
    $('#viewTitle').textContent = t('title.' + state.view);
    // reload the current page to translate dynamic content
    if (state.view !== 'ask' && state.view !== 'editor') go(state.view);
  }
}

// ------------------------------------------------------------------ login
function showLogin() {
  $('#app').classList.add('hidden');
  $('#login').classList.remove('hidden');
  stopTimer();
}

async function start(status) {
  applyStatus(status);
  $('#login').classList.add('hidden');
  $('#app').classList.remove('hidden');
  $('#viewTitle').textContent = t('title.' + state.view);
  state.schemas = (await api('schemas')).schemas;
  saveSources();
  renderSuggestions(t('ask.defaults'));
}

async function boot() {
  setLanguage(LANG);
  try { await start(await api('status')); } catch { showLogin(); }
}

// ------------------------------------------------------------------ events
$('#loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('#loginError').textContent = '';
  try {
    const res = await fetch('/api/login', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Copilot-Lang': LANG }, body: JSON.stringify({ username: $('#loginUser').value, password: $('#loginPass').value }) });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || t('login.failed'));
    await start(data);
  } catch (err) { $('#loginError').textContent = err.message; }
});
$$('.lang-switch button').forEach((b) => b.addEventListener('click', () => setLanguage(b.dataset.lang)));
$('#logoutBtn').addEventListener('click', async () => { await fetch('/api/logout', { method: 'POST' }); location.reload(); });
$$('.sidebar nav button').forEach((b) => b.addEventListener('click', () => go(b.dataset.view)));
$('#menuBtn').addEventListener('click', () => $('.sidebar').classList.toggle('open'));
$('#sourcesBtn').addEventListener('click', (e) => { e.stopPropagation(); $('#sourcesPop').classList.toggle('hidden'); });
document.addEventListener('click', (e) => { if (!$('.sources').contains(e.target)) $('#sourcesPop').classList.add('hidden'); });

$('#sendBtn').addEventListener('click', () => ask($('#question').value));
$('#question').addEventListener('keydown', (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); ask($('#question').value); } });
$('#question').addEventListener('input', autoGrow);
$$('.mode-switch button').forEach((b) => b.addEventListener('click', () => {
  state.mode = b.dataset.mode;
  $$('.mode-switch button').forEach((x) => x.classList.toggle('active', x === b));
  setModePlaceholder();
}));
$('#newChatBtn').addEventListener('click', () => {
  state.history = []; state.agentSession = '';
  $$('#chat .msg').forEach((m) => { $$('.chart-box', m).forEach((b) => destroyChart(b.parentElement)); m.remove(); });
  $('#welcome').classList.remove('hidden');
});
$('#suggestBtn').addEventListener('click', async (e) => {
  const btn = e.currentTarget;
  btn.disabled = true; btn.textContent = t('ask.suggesting');
  try { const r = await api('suggest', { schemas: schemasParam() }); if (r.questions?.length) renderSuggestions(r.questions); }
  catch (err) { toast(err.message, true); }
  btn.disabled = false; btn.textContent = t('ask.suggestBtn');
});

$('#runSql').addEventListener('click', runEditor);
$('#explainSql').addEventListener('click', explainEditor);
$('#tuneSql').addEventListener('click', tuneEditor);
$('#sqlEditor').addEventListener('keydown', (e) => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); runEditor(); } });

$('#dashSelect').addEventListener('change', (e) => openDashboard(e.target.value).catch((err) => toast(err.message, true)));
$('#dashNew').addEventListener('click', async () => {
  const v = await dialog(t('dash.newTitle'), [{ name: 'name', label: t('dash.name'), required: true }, { name: 'description', label: t('dash.desc') }], t('dash.create'));
  if (!v?.name) return;
  const d = await api('dashboards.save', { name: v.name, description: v.description, refreshSeconds: 15 });
  loadDashboards(d.id);
});
$('#dashGen').addEventListener('click', generateDashboard);
$('#dashReload').addEventListener('click', () => refreshWidgets());
$('#dashRefresh').addEventListener('change', async (e) => {
  if (!state.dashboard) return;
  state.dashboard.refreshSeconds = +e.target.value;
  await api('dashboards.save', { id: state.dashboard.id, refreshSeconds: +e.target.value });
  startTimer();
});
$('#dashEdit').addEventListener('click', async () => {
  const d = state.dashboard; if (!d) return;
  const v = await dialog(t('dash.renameTitle'), [{ name: 'name', label: t('dash.name'), value: d.name }, { name: 'description', label: t('dash.desc'), value: d.description || '' }]);
  if (!v) return;
  await api('dashboards.save', { id: d.id, name: v.name, description: v.description });
  loadDashboards(d.id);
});
$('#dashDelete').addEventListener('click', async () => {
  const d = state.dashboard; if (!d || !confirm(t('dash.confirmDelete', { n: d.name }))) return;
  await api('dashboards.delete', { id: d.id });
  state.dashboard = null;
  loadDashboards();
});
$('#catalogFilter').addEventListener('input', () => loadCatalogList());
$('#catalogRefresh').addEventListener('click', () => loadCatalog(true));
$('#glossaryAdd').addEventListener('click', () => editGlossary());
$('#wfReload').addEventListener('click', () => loadWorkflows().catch((e) => toast(e.message, true)));
$('#wfStart').addEventListener('click', async () => { try { await api('interop.start'); loadWorkflows(); } catch (e) { toast(e.message, true); } });

boot();
