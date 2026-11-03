'use strict';

// ---------- storage ----------
const KEY = 'dbrain.v1';
const empty = () => ({ notes: [], tasks: [], work: [], shift: null, settings: { target: 168, rate: 0 } });

function load() {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? Object.assign(empty(), JSON.parse(raw)) : empty();
  } catch (e) {
    return empty();
  }
}
let db = load();
function save() {
  try { localStorage.setItem(KEY, JSON.stringify(db)); }
  catch (e) { toast('Nie udało się zapisać danych'); }
}
// ask iOS not to evict our data
if (navigator.storage && navigator.storage.persist) navigator.storage.persist();

// ---------- helpers ----------
const $ = (s) => document.querySelector(s);
const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pad = (n) => String(n).padStart(2, '0');
const ymd = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const hm = (d) => `${pad(d.getHours())}:${pad(d.getMinutes())}`;
const fmtH = (h) => (Math.round(h * 100) / 100).toLocaleString('pl-PL', { maximumFractionDigits: 2 });
const fmtDur = (h) => { const m = Math.round(h * 60); return `${Math.floor(m / 60)}h ${pad(m % 60)}m`; };
const fmtDate = (iso) => new Date(iso).toLocaleDateString('pl-PL', { day: 'numeric', month: 'short' });
const fmtDT = (iso) => new Date(iso).toLocaleString('pl-PL', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const money = (v) => v.toLocaleString('pl-PL', { style: 'currency', currency: 'PLN' });

let toastTimer;
function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 2200);
}

function download(name, content, type) {
  const blob = new Blob([content], { type });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}

// ---------- tabs ----------
function showTab(name) {
  document.querySelectorAll('.tab').forEach((s) => s.classList.toggle('active', s.id === 'tab-' + name));
  document.querySelectorAll('.tabbar button').forEach((b) => b.classList.toggle('active', b.dataset.tab === name));
  try { localStorage.setItem('dbrain.tab', name); } catch (e) {}
  window.scrollTo(0, 0);
}
document.querySelectorAll('.tabbar button').forEach((b) => b.addEventListener('click', () => showTab(b.dataset.tab)));

function greeting() {
  const h = new Date().getHours();
  const hi = h < 5 ? 'Dobranoc' : h < 12 ? 'Dzień dobry' : h < 18 ? 'Cześć' : 'Dobry wieczór';
  const today = new Date().toLocaleDateString('pl-PL', { weekday: 'long', day: 'numeric', month: 'long' });
  $('#greeting').textContent = `${hi}, Dobrich · ${today}`;
}

// ---------- notes ----------
let noteFilter = { q: '', tag: null };
const tagsOf = (text) => [...new Set((text.match(/#[\p{L}\p{N}_-]+/gu) || []).map((t) => t.toLowerCase()))];

$('#note-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const text = $('#note-text').value.trim();
  if (!text) return;
  const now = new Date().toISOString();
  db.notes.unshift({ id: uid(), text, pinned: false, created: now, updated: now });
  save();
  $('#note-text').value = '';
  renderNotes();
  toast('Zapamiętane');
});
$('#note-search').addEventListener('input', (e) => { noteFilter.q = e.target.value.trim().toLowerCase(); renderNotes(); });

function renderNotes() {
  const allTags = [...new Set(db.notes.flatMap((n) => tagsOf(n.text)))].sort();
  $('#tag-bar').innerHTML = allTags.map((t) => `<button class="chip ${noteFilter.tag === t ? 'on' : ''}" data-tag="${esc(t)}">${esc(t)}</button>`).join('');

  const words = noteFilter.q.split(/\s+/).filter(Boolean);
  const list = db.notes
    .filter((n) => !noteFilter.tag || tagsOf(n.text).includes(noteFilter.tag))
    .filter((n) => words.every((w) => n.text.toLowerCase().includes(w)))
    .sort((a, b) => (b.pinned - a.pinned) || b.updated.localeCompare(a.updated));

  $('#note-list').innerHTML = list.length ? list.map((n) => `
    <div class="item ${n.pinned ? 'pinned' : ''}" data-id="${n.id}">
      <div class="text">${esc(n.text).replace(/#[\p{L}\p{N}_-]+/gu, (t) => `<span class="tag">${t}</span>`)}</div>
      <div class="meta">${n.pinned ? '📌 ' : ''}${fmtDate(n.updated)}
        <span class="actions">
          <button data-act="pin">${n.pinned ? 'Odepnij' : 'Przypnij'}</button>
          <button data-act="edit">Edytuj</button>
          <button data-act="del" class="del">Usuń</button>
        </span>
      </div>
    </div>`).join('')
    : `<div class="empty">${db.notes.length ? 'Nic nie znaleziono' : 'Tu będzie Twoja pamięć. Zapisz pierwszą myśl.'}</div>`;
}
$('#tag-bar').addEventListener('click', (e) => {
  const t = e.target.closest('.chip');
  if (!t) return;
  noteFilter.tag = noteFilter.tag === t.dataset.tag ? null : t.dataset.tag;
  renderNotes();
});
$('#note-list').addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-act]');
  if (!btn) return;
  const n = db.notes.find((x) => x.id === btn.closest('.item').dataset.id);
  if (!n) return;
  if (btn.dataset.act === 'pin') n.pinned = !n.pinned;
  if (btn.dataset.act === 'edit') {
    const t = prompt('Edytuj notatkę', n.text);
    if (t === null || !t.trim()) return;
    n.text = t.trim();
    n.updated = new Date().toISOString();
  }
  if (btn.dataset.act === 'del') {
    if (!confirm('Usunąć notatkę?')) return;
    db.notes = db.notes.filter((x) => x !== n);
  }
  save();
  renderNotes();
});

// ---------- tasks ----------
$('#task-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const title = $('#task-title').value.trim();
  if (!title) return;
  const due = $('#task-due').value ? new Date($('#task-due').value).toISOString() : null;
  db.tasks.push({ id: uid(), title, due, done: false, created: new Date().toISOString() });
  save();
  $('#task-title').value = '';
  $('#task-due').value = '';
  renderTasks();
  toast(due ? 'Dodane – możesz dodać przypomnienie 🔔' : 'Dodane');
});

function renderTasks() {
  const now = new Date();
  const endToday = new Date(now); endToday.setHours(23, 59, 59, 999);
  const open = db.tasks.filter((t) => !t.done).sort((a, b) => (a.due || '9').localeCompare(b.due || '9'));
  const groups = [
    ['Zaległe', open.filter((t) => t.due && new Date(t.due) < now), 'overdue'],
    ['Dziś', open.filter((t) => t.due && new Date(t.due) >= now && new Date(t.due) <= endToday), ''],
    ['Później', open.filter((t) => t.due && new Date(t.due) > endToday), ''],
    ['Bez terminu', open.filter((t) => !t.due), ''],
    ['Zrobione', db.tasks.filter((t) => t.done).sort((a, b) => (b.doneAt || '').localeCompare(a.doneAt || '')).slice(0, 30), ''],
  ];
  const html = groups.filter(([, l]) => l.length).map(([name, l, cls]) => `
    <div class="group-title ${cls}">${name} · ${l.length}</div>
    ${l.map((t) => `
      <div class="item task ${t.done ? 'done' : ''}" data-id="${t.id}">
        <button class="check" data-act="toggle" aria-label="Zrobione">${t.done ? '✓' : ''}</button>
        <div class="body">
          <div class="title">${esc(t.title)}</div>
          <div class="meta">
            ${t.due ? `<span class="due ${!t.done && new Date(t.due) < now ? 'late' : ''}">${fmtDT(t.due)}</span>` : ''}
            <span class="actions">
              ${t.due && !t.done ? '<button data-act="remind">🔔 Przypomnienie</button>' : ''}
              <button data-act="del" class="del">Usuń</button>
            </span>
          </div>
        </div>
      </div>`).join('')}`).join('');
  $('#task-list').innerHTML = html || '<div class="empty">Brak zadań. Czysta głowa 🧠</div>';

  const late = groups[0][1].length + groups[1][1].length;
  const badge = $('#task-badge');
  badge.hidden = !late;
  badge.textContent = late;
}

// iOS web apps can't schedule local notifications – a calendar event with an alarm does the job
function icsFor(t) {
  const d = new Date(t.due);
  const stamp = (x) => x.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const end = new Date(d.getTime() + 15 * 60000);
  const text = (s) => s.replace(/[\\,;]/g, (c) => '\\' + c).replace(/\n/g, '\\n');
  return [
    'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Dobrichs Brain//PL', 'BEGIN:VEVENT',
    `UID:${t.id}@dobrichs-brain`, `DTSTAMP:${stamp(new Date())}`, `DTSTART:${stamp(d)}`, `DTEND:${stamp(end)}`,
    `SUMMARY:${text(t.title)}`, 'BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${text(t.title)}`, 'TRIGGER:PT0M', 'END:VALARM',
    'END:VEVENT', 'END:VCALENDAR',
  ].join('\r\n');
}

$('#task-list').addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-act]');
  if (!btn) return;
  const t = db.tasks.find((x) => x.id === btn.closest('.item').dataset.id);
  if (!t) return;
  if (btn.dataset.act === 'toggle') { t.done = !t.done; t.doneAt = t.done ? new Date().toISOString() : null; }
  if (btn.dataset.act === 'remind') { download('przypomnienie.ics', icsFor(t), 'text/calendar'); return; }
  if (btn.dataset.act === 'del') {
    if (!confirm('Usunąć zadanie?')) return;
    db.tasks = db.tasks.filter((x) => x !== t);
  }
  save();
  renderTasks();
});

// ---------- work hours ----------
let month = new Date(); month.setDate(1);

const entryHours = (w) => {
  if (w.hours != null) return w.hours;
  const [sh, sm] = w.start.split(':').map(Number);
  const [eh, em] = w.end.split(':').map(Number);
  let mins = (eh * 60 + em) - (sh * 60 + sm);
  if (mins < 0) mins += 24 * 60; // night shift past midnight
  return Math.max(0, mins - (w.breakMin || 0)) / 60;
};

function renderShift() {
  const card = $('#shift-card');
  if (db.shift) {
    const h = (Date.now() - new Date(db.shift.start)) / 3600000;
    card.innerHTML = `<div class="muted">Jesteś w pracy od ${hm(new Date(db.shift.start))}</div>
      <div class="clock">${fmtDur(h)}</div>
      <button class="btn primary big" id="shift-stop">Zakończ zmianę</button>`;
  } else {
    card.innerHTML = `<div class="muted">Zacznij liczyć czas jednym kliknięciem</div>
      <button class="btn primary big" id="shift-start">▶ Zaczynam pracę</button>`;
  }
}
$('#shift-card').addEventListener('click', (e) => {
  if (e.target.id === 'shift-start') {
    db.shift = { start: new Date().toISOString() };
    toast('Powodzenia w pracy 💪');
  } else if (e.target.id === 'shift-stop') {
    const s = new Date(db.shift.start), en = new Date();
    const brk = Number(prompt('Ile minut przerwy?', '0')) || 0;
    db.work.push({ id: uid(), date: ymd(s), start: hm(s), end: hm(en), breakMin: brk, note: '' });
    db.shift = null;
    toast('Zmiana zapisana');
  } else return;
  save();
  renderWork();
});

function monthEntries() {
  const prefix = `${month.getFullYear()}-${pad(month.getMonth() + 1)}`;
  return db.work.filter((w) => w.date.startsWith(prefix)).sort((a, b) => b.date.localeCompare(a.date) || (b.start || '').localeCompare(a.start || ''));
}

function renderWork() {
  renderShift();
  $('#m-label').textContent = month.toLocaleDateString('pl-PL', { month: 'long', year: 'numeric' });
  const list = monthEntries();
  const total = list.reduce((s, w) => s + entryHours(w), 0);
  const days = new Set(list.map((w) => w.date)).size;
  const target = Number(db.settings.target) || 0;
  const rate = Number(db.settings.rate) || 0;
  const pct = target ? Math.min(100, (total / target) * 100) : 0;

  $('#work-stats').innerHTML = `
    <div class="stat wide"><div class="l">Przepracowane w miesiącu</div><div class="v">${fmtH(total)} h</div>
      ${target ? `<div class="l">${fmtH(pct)}% z celu ${target} h · zostało ${fmtH(Math.max(0, target - total))} h</div><div class="bar"><i style="width:${pct}%"></i></div>` : ''}
    </div>
    <div class="stat"><div class="l">Dni w pracy</div><div class="v">${days}</div></div>
    <div class="stat"><div class="l">Średnio dziennie</div><div class="v">${days ? fmtH(total / days) : 0} h</div></div>
    ${rate ? `<div class="stat wide"><div class="l">Zarobek (brutto, ${money(rate)}/h)</div><div class="v">${money(total * rate)}</div></div>` : ''}`;

  $('#work-list').innerHTML = list.length ? list.map((w) => `
    <div class="item" data-id="${w.id}">
      <div class="work-row">
        <div>${new Date(w.date + 'T12:00').toLocaleDateString('pl-PL', { weekday: 'short', day: 'numeric', month: 'short' })}
          <span class="muted">${w.hours != null ? '' : `${w.start}–${w.end}${w.breakMin ? `, przerwa ${w.breakMin} min` : ''}`}</span></div>
        <div class="h">${fmtH(entryHours(w))} h</div>
      </div>
      <div class="meta">${esc(w.note || '')}<span class="actions"><button data-act="del" class="del">Usuń</button></span></div>
    </div>`).join('')
    : '<div class="empty">Brak wpisów w tym miesiącu</div>';
}

$('#m-prev').addEventListener('click', () => { month.setMonth(month.getMonth() - 1); renderWork(); });
$('#m-next').addEventListener('click', () => { month.setMonth(month.getMonth() + 1); renderWork(); });

$('#work-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const date = $('#w-date').value;
  const start = $('#w-start').value, end = $('#w-end').value;
  const hoursRaw = $('#w-hours').value;
  const entry = { id: uid(), date, note: $('#w-note').value.trim() };
  if (hoursRaw !== '') entry.hours = Number(hoursRaw);
  else if (start && end) Object.assign(entry, { start, end, breakMin: Number($('#w-break').value) || 0 });
  else { toast('Podaj godziny od–do albo liczbę godzin'); return; }
  db.work.push(entry);
  save();
  ['#w-start', '#w-end', '#w-hours', '#w-note'].forEach((s) => ($(s).value = ''));
  $('#w-break').value = 0;
  const d = new Date(date + 'T12:00');
  month = new Date(d.getFullYear(), d.getMonth(), 1);
  renderWork();
  toast('Wpis dodany');
});

$('#work-list').addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-act="del"]');
  if (!btn || !confirm('Usunąć wpis?')) return;
  db.work = db.work.filter((w) => w.id !== btn.closest('.item').dataset.id);
  save();
  renderWork();
});

$('#w-csv').addEventListener('click', () => {
  const rows = [['Data', 'Od', 'Do', 'Przerwa (min)', 'Godziny', 'Notatka']];
  monthEntries().reverse().forEach((w) => rows.push([w.date, w.start || '', w.end || '', w.breakMin || '', fmtH(entryHours(w)), w.note || '']));
  const csv = rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(';')).join('\r\n');
  download(`praca-${month.getFullYear()}-${pad(month.getMonth() + 1)}.csv`, '﻿' + csv, 'text/csv');
});

// ---------- settings ----------
$('#s-target').value = db.settings.target || '';
$('#s-rate').value = db.settings.rate || '';
$('#s-target').addEventListener('change', (e) => { db.settings.target = Number(e.target.value) || 0; save(); renderWork(); });
$('#s-rate').addEventListener('change', (e) => { db.settings.rate = Number(e.target.value) || 0; save(); renderWork(); });

$('#b-export').addEventListener('click', () => {
  download(`dobrichs-brain-${ymd(new Date())}.json`, JSON.stringify(db, null, 2), 'application/json');
});
$('#b-import').addEventListener('change', async (e) => {
  const file = e.target.files[0];
  if (!file) return;
  try {
    const data = JSON.parse(await file.text());
    if (!Array.isArray(data.notes) || !Array.isArray(data.tasks) || !Array.isArray(data.work)) throw new Error('format');
    if (!confirm('Zastąpić obecne dane kopią z pliku?')) return;
    db = Object.assign(empty(), data);
    save();
    renderAll();
    toast('Przywrócono kopię');
  } catch (err) {
    toast('To nie jest plik kopii Dobrich’s Brain');
  }
  e.target.value = '';
});

// ---------- boot ----------
function renderAll() {
  greeting();
  renderNotes();
  renderTasks();
  renderWork();
}
$('#w-date').value = ymd(new Date());
renderAll();
try { const t = localStorage.getItem('dbrain.tab'); if (t) showTab(t); } catch (e) {}

setInterval(() => { if (db.shift) renderShift(); renderTasks(); }, 30000);
document.addEventListener('visibilitychange', () => { if (!document.hidden) renderAll(); });

if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
