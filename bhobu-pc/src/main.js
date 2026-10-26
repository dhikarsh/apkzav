// BHOBU RELOAD untuk PC: jendela berbingkai modern yang membuka web member OtoReport milik BHOBU.
// Halaman transaksi tetap dari bhobureload.otoreport.com; aplikasi ini hanya menambah bingkai,
// navigasi, dan tema tampilan (CSS) yang bisa dimatikan dari tombol "Tema".
const { app, BaseWindow, WebContentsView, ipcMain, shell, session } = require('electron');
const fs = require('fs');
const path = require('path');

const HOME_URL = 'https://bhobureload.otoreport.com/';
const ALLOWED_HOSTS = ['otoreport.com', 'bhobureload.id'];
const CS_WHATSAPP = 'https://wa.me/6281222837157';
const TOOLBAR_HEIGHT = 64;

const settingsFile = () => path.join(app.getPath('userData'), 'settings.json');
const themeCss = fs.readFileSync(path.join(__dirname, 'theme.css'), 'utf8');

function loadSettings() {
  try {
    return { theme: true, zoom: 1, ...JSON.parse(fs.readFileSync(settingsFile(), 'utf8')) };
  } catch {
    return { theme: true, zoom: 1 };
  }
}

function saveSettings(s) {
  try {
    fs.writeFileSync(settingsFile(), JSON.stringify(s));
  } catch {
    // Pengaturan gagal disimpan tidak boleh menghentikan aplikasi.
  }
}

function isAllowed(url) {
  try {
    const u = new URL(url);
    if (u.protocol === 'file:') return true;
    return u.protocol === 'https:' && ALLOWED_HOSTS.some((h) => u.hostname === h || u.hostname.endsWith('.' + h));
  } catch {
    return false;
  }
}

function openExternal(url) {
  if (/^(https?|mailto|tel):/i.test(url) || /^whatsapp:/i.test(url)) shell.openExternal(url);
}

let win;
let toolbar;
let site;
let splash;
let themeKey = null;
const settings = { theme: true, zoom: 1 };

function layout() {
  const { width, height } = win.getContentBounds();
  toolbar.setBounds({ x: 0, y: 0, width, height: TOOLBAR_HEIGHT });
  const body = { x: 0, y: TOOLBAR_HEIGHT, width, height: Math.max(0, height - TOOLBAR_HEIGHT) };
  site.setBounds(body);
  if (splash) splash.setBounds(body);
}

function sendState() {
  if (!toolbar || toolbar.webContents.isDestroyed()) return;
  const wc = site.webContents;
  toolbar.webContents.send('state', {
    canBack: wc.navigationHistory.canGoBack(),
    canForward: wc.navigationHistory.canGoForward(),
    loading: wc.isLoading(),
    zoom: Math.round(settings.zoom * 100),
    theme: settings.theme,
    title: wc.getTitle(),
  });
}

async function applyTheme() {
  const wc = site.webContents;
  if (themeKey) {
    await wc.removeInsertedCSS(themeKey).catch(() => {});
    themeKey = null;
  }
  if (settings.theme && !wc.getURL().startsWith('file:')) {
    themeKey = await wc.insertCSS(themeCss).catch(() => null);
  }
}

function hideSplash() {
  if (!splash) return;
  win.contentView.removeChildView(splash);
  splash.webContents.close();
  splash = null;
}

function createWindow() {
  Object.assign(settings, loadSettings());

  win = new BaseWindow({
    width: 1280,
    height: 820,
    minWidth: 960,
    minHeight: 620,
    title: 'BHOBU RELOAD',
    icon: path.join(__dirname, '..', 'assets', 'icon.png'),
    backgroundColor: '#0a2a6e',
    titleBarStyle: 'hidden',
    titleBarOverlay: { color: '#0a2a6e', symbolColor: '#ffffff', height: TOOLBAR_HEIGHT },
    show: false,
  });

  toolbar = new WebContentsView({
    webPreferences: { preload: path.join(__dirname, 'toolbar-preload.js'), contextIsolation: true, sandbox: true },
  });
  toolbar.setBackgroundColor('#0a2a6e');

  site = new WebContentsView({
    webPreferences: {
      partition: 'persist:bhobu', // login tetap tersimpan setelah aplikasi ditutup
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
      spellcheck: false,
    },
  });
  site.setBackgroundColor('#eef3fb');

  splash = new WebContentsView({ webPreferences: { contextIsolation: true, sandbox: true } });
  splash.setBackgroundColor('#0a2a6e');

  win.contentView.addChildView(site);
  win.contentView.addChildView(splash);
  win.contentView.addChildView(toolbar);
  layout();
  win.on('resize', layout);

  toolbar.webContents.loadFile(path.join(__dirname, 'toolbar.html'));
  splash.webContents.loadFile(path.join(__dirname, 'splash.html'));
  toolbar.webContents.once('did-finish-load', () => {
    win.show();
    sendState();
  });
  setTimeout(hideSplash, 15000);

  const wc = site.webContents;
  wc.setZoomFactor(settings.zoom);
  wc.setWindowOpenHandler(({ url }) => {
    if (isAllowed(url)) {
      wc.loadURL(url);
    } else {
      openExternal(url);
    }
    return { action: 'deny' };
  });
  wc.on('will-navigate', (event, url) => {
    if (!isAllowed(url)) {
      event.preventDefault();
      openExternal(url);
    }
  });
  wc.on('dom-ready', applyTheme);
  wc.on('did-finish-load', () => {
    wc.setZoomFactor(settings.zoom);
    hideSplash();
    sendState();
  });
  wc.on('did-fail-load', (_e, code, desc, url, isMainFrame) => {
    // -3 = dibatalkan (mis. pindah halaman cepat), bukan error yang perlu ditampilkan.
    if (!isMainFrame || code === -3) return;
    hideSplash();
    wc.loadFile(path.join(__dirname, 'error.html'), { query: { url: url || HOME_URL, desc: String(desc) } });
  });
  for (const ev of ['did-start-loading', 'did-stop-loading', 'did-navigate', 'did-navigate-in-page', 'page-title-updated']) {
    wc.on(ev, sendState);
  }
  wc.on('before-input-event', (event, input) => {
    if (input.type !== 'keyDown') return;
    const ctrl = input.control || input.meta;
    const key = input.key.toLowerCase();
    let cmd = null;
    if (key === 'f5' || (ctrl && key === 'r')) cmd = 'reload';
    else if (input.alt && key === 'arrowleft') cmd = 'back';
    else if (input.alt && key === 'arrowright') cmd = 'forward';
    else if (ctrl && (key === '=' || key === '+')) cmd = 'zoomIn';
    else if (ctrl && key === '-') cmd = 'zoomOut';
    else if (ctrl && key === '0') cmd = 'zoomReset';
    else if (key === 'f12') cmd = 'devtools';
    if (cmd) {
      event.preventDefault();
      runCommand(cmd);
    }
  });

  wc.loadURL(HOME_URL);
}

function setZoom(z) {
  settings.zoom = Math.min(2, Math.max(0.6, Math.round(z * 10) / 10));
  site.webContents.setZoomFactor(settings.zoom);
  saveSettings(settings);
}

function runCommand(cmd) {
  const wc = site.webContents;
  switch (cmd) {
    case 'back':
      if (wc.navigationHistory.canGoBack()) wc.navigationHistory.goBack();
      break;
    case 'forward':
      if (wc.navigationHistory.canGoForward()) wc.navigationHistory.goForward();
      break;
    case 'reload':
      wc.getURL().startsWith('file:') ? wc.loadURL(HOME_URL) : wc.reload();
      break;
    case 'home':
      wc.loadURL(HOME_URL);
      break;
    case 'zoomIn':
      setZoom(settings.zoom + 0.1);
      break;
    case 'zoomOut':
      setZoom(settings.zoom - 0.1);
      break;
    case 'zoomReset':
      setZoom(1);
      break;
    case 'theme':
      settings.theme = !settings.theme;
      saveSettings(settings);
      applyTheme();
      break;
    case 'devtools':
      wc.openDevTools({ mode: 'detach' });
      break;
    case 'cs':
      shell.openExternal(CS_WHATSAPP);
      break;
    default:
      return;
  }
  sendState();
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
  });

  app.whenReady().then(() => {
    // Tolak izin yang tidak dibutuhkan halaman transaksi (kamera, mikrofon, lokasi, dll).
    session.fromPartition('persist:bhobu').setPermissionRequestHandler((_wc, permission, cb) => {
      cb(['clipboard-sanitized-write', 'notifications', 'fullscreen'].includes(permission));
    });
    ipcMain.on('cmd', (_e, cmd) => runCommand(cmd));
    createWindow();
  });

  app.on('window-all-closed', () => app.quit());
}
