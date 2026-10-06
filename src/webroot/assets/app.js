'use strict';

/*
 * 三段式按键 → 一键闪记  WebUI
 *
 * 由管理器(KernelSU / ReSukiSU)的 WebView 加载, 通过注入的 window.ksu 以 root 执行 shell。
 * 界面本身不做任何逻辑, 只是 cli.sh 的一层壳。
 *
 * 桌面浏览器直接打开时加 ?demo 可看静态样例(不需要桥, 便于调样式)。
 */

const MOD = '/data/adb/modules/tristate_xiaobu';
const CLI = MOD + '/bin/cli.sh';

const TRIGGER_TYPES = [
  [2, '2 · THREE_FINGERS_UP（三指上滑）'],
  [1, '1 · MAGIC_KEY（闪记键）'],
  [3, '3 · CUI'],
  [4, '4 · SCREENSHOT'],
  [6, '6 · SCREENSHOT_NORMAL（普通截屏）'],
  [7, '7 · SCREENSHOT_LONG（长截屏）'],
  [8, '8 · SCREENSHOT_AREA（区域截屏）'],
  [11, '11 · AUTO_PAYMENT'],
  [12, '12 · AUTO_COLLECT'],
  [14, '14 · AUTO_PAYMENT_NOTIFICATION'],
  [15, '15 · AI_KEY_DOUBLE_CLICK'],
  [17, '17 · BREENO_TOUCH'],
];

const RINGER_TEXT = { 0: '静音', 1: '振动', 2: '响铃' };

const DEMO = /[?&]demo\b/.test(location.search);
const DEMO_STATE = [
  'POS=2',
  'POS_DESC=中档(振动)',
  'RINGER=1',
  'DAEMON_PID=29826',
  'CONF_TRIGGER_POSITION=1',
  'CONF_TRIGGER_MODE=position',
  'CONF_COOLDOWN=3',
  'CONF_SCREEN_ON_ONLY=1',
  'CONF_ACTION=flashnote',
  'CONF_FLASHNOTE_TRIGGER_TYPE=2',
].join('\n');

const $ = (id) => document.getElementById(id);

/* ---------------- ksu 桥 ---------------- */

function hasBridge() {
  return typeof window !== 'undefined' && window.ksu && typeof window.ksu.exec === 'function';
}

async function sh(cmd) {
  if (!hasBridge()) {
    if (DEMO) return cmd.indexOf(' state') >= 0 ? DEMO_STATE : '[demo] ' + cmd + '\n(桌面预览模式, 未真正执行)';
    throw new Error('未检测到 ksu 桥');
  }
  let r = window.ksu.exec(cmd);
  if (r && typeof r.then === 'function') r = await r;
  if (typeof r === 'string') {
    try { r = JSON.parse(r); } catch (e) { return r; }
  }
  if (r && typeof r === 'object') {
    if ('stdout' in r || 'stderr' in r) return (r.stdout || '') + (r.stderr || '');
    return JSON.stringify(r);
  }
  return String(r);
}

const cli = (args) => sh('sh ' + CLI + ' ' + args);

/* ---------------- 小工具 ---------------- */

function kv(text) {
  const out = {};
  String(text).split('\n').forEach((line) => {
    const i = line.indexOf('=');
    if (i > 0) out[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  });
  return out;
}

function segValue(groupId) {
  const on = $(groupId).querySelector('button[aria-pressed="true"]');
  return on ? on.dataset.v : '';
}

function segSelect(groupId, value) {
  $(groupId).querySelectorAll('button').forEach((b) => {
    b.setAttribute('aria-pressed', String(b.dataset.v === String(value)));
  });
}

function warn(msg) {
  const el = $('warn');
  el.textContent = msg;
  el.hidden = !msg;
}

function show(text) {
  const el = $('out');
  el.textContent = text;
  el.hidden = false;
}

async function busy(btn, fn) {
  const old = btn.textContent;
  btn.disabled = true;
  btn.textContent = '处理中…';
  try { await fn(); } finally {
    btn.disabled = false;
    btn.textContent = old;
  }
}

/* ---------------- 渲染 ---------------- */

async function refresh() {
  try {
    const s = kv(await cli('state'));
    $('s-pos').textContent = s.POS_DESC || '—';
    $('s-ringer').textContent = RINGER_TEXT[s.RINGER] !== undefined ? RINGER_TEXT[s.RINGER] : '—';
    $('s-daemon').textContent = s.DAEMON_PID ? '运行中 · pid ' + s.DAEMON_PID : '未运行';
    segSelect('f-pos', s.CONF_TRIGGER_POSITION);
    segSelect('f-mode', s.CONF_TRIGGER_MODE);
    $('f-action').value = s.CONF_ACTION || 'flashnote';
    $('f-tt').value = s.CONF_FLASHNOTE_TRIGGER_TYPE || '2';
    $('f-screen').checked = s.CONF_SCREEN_ON_ONLY === '1';
    warn('');
  } catch (e) {
    warn('读取状态失败：' + e.message);
  }
}

/* ---------------- 动作 ---------------- */

async function save() {
  const steps = [
    ['触发档位', 'set TRIGGER_POSITION ' + segValue('f-pos')],
    ['触发方式', 'set TRIGGER_MODE ' + segValue('f-mode')],
    ['动作', 'set ACTION ' + $('f-action').value],
    ['闪记来源', 'set FLASHNOTE_TRIGGER_TYPE ' + $('f-tt').value],
    ['亮屏限制', 'set SCREEN_ON_ONLY ' + ($('f-screen').checked ? '1' : '0')],
  ];
  const lines = [];
  for (const [name, args] of steps) {
    if (/ (|)$/.test(args)) continue;
    lines.push('$ cli.sh ' + args);
    lines.push((await cli(args)).trim());
  }
  lines.push('$ cli.sh restart');
  lines.push((await cli('restart')).trim());
  show(lines.join('\n'));
  await refresh();
}

/* ---------------- 初始化 ---------------- */

function init() {
  $('f-tt').innerHTML = TRIGGER_TYPES
    .map(([v, t]) => '<option value="' + v + '">' + t + '</option>')
    .join('');

  ['f-pos', 'f-mode'].forEach((g) => {
    $(g).addEventListener('click', (e) => {
      const b = e.target.closest('button');
      if (b) segSelect(g, b.dataset.v);
    });
  });

  $('refresh').addEventListener('click', (e) => busy(e.target, refresh));

  $('save').addEventListener('click', (e) => busy(e.target, save));

  $('test').addEventListener('click', (e) => busy(e.target, async () => {
    show((await cli('test')).trim());
    await refresh();
  }));

  $('log').addEventListener('click', (e) => busy(e.target, async () => {
    show((await cli('log 40')).trim());
  }));

  $('detect').addEventListener('click', (e) => busy(e.target, async () => {
    show((await cli('detect')).trim());
  }));

  if (!hasBridge() && !DEMO) {
    warn('未检测到 ksu 桥。请从管理器(KernelSU / ReSukiSU)打开本模块的 WebUI；' +
         '桌面浏览器预览请加 ?demo');
    document.querySelectorAll('button').forEach((b) => { b.disabled = true; });
  }

  refresh();
}

document.addEventListener('DOMContentLoaded', init);
