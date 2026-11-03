'use strict';
const { app, BrowserWindow, dialog, Menu, shell } = require('electron');
const path = require('path'), fs = require('fs');
const { ensureMongo } = require('./server/mongo-launcher');
const { Store } = require('./server/store');
const { createServer, listen } = require('./server/server');
const { LicenseManager } = require('./server/license');

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) app.quit();

let license = null, lockTimer = null, win = null, mongo = null, store = null, httpSrv = null, port = 0, quitting = false, backupTimer = null;
const logFile = () => path.join(app.getPath('userData'), 'app.log');
const log = m => { try { fs.appendFileSync(logFile(), new Date().toISOString() + ' ' + m + '\n'); } catch (e) {} console.log(m); };

/* config.json in %APPDATA%\Farm Database: { "mongoUri": "...", "dbName": "...", "port": 47831 } */
function config() {
  const p = path.join(app.getPath('userData'), 'config.json');
  const def = { mongoUri: 'mongodb://127.0.0.1:27017', dbName: 'farm_database', port: 47831 };
  try { return Object.assign(def, JSON.parse(fs.readFileSync(p, 'utf8'))); } catch (e) { try { fs.mkdirSync(app.getPath('userData'), { recursive: true }); fs.writeFileSync(p, JSON.stringify(def, null, 2)); } catch (x) {} return def; }
}
function backupDir() { const d = path.join(app.getPath('documents'), 'FarmDatabase-Backups'); fs.mkdirSync(d, { recursive: true }); return d; }
async function fileBackup(reason) {
  try {
    const db = await store.exportAll(); const n = Object.keys(db).reduce((s, k) => s + (Array.isArray(db[k]) ? db[k].length : 0), 0);
    if (!n) return;
    const d = backupDir(), t = new Date(), pad = x => String(x).padStart(2, '0');
    const f = path.join(d, `farm-backup-${t.getFullYear()}-${pad(t.getMonth() + 1)}-${pad(t.getDate())}-${pad(t.getHours())}${pad(t.getMinutes())}-${reason}.json`);
    fs.writeFileSync(f, JSON.stringify(db));
    const all = fs.readdirSync(d).filter(x => /^farm-backup-.*\.json$/.test(x)).sort();
    while (all.length > 30) fs.unlinkSync(path.join(d, all.shift()));
    log('Backup written: ' + f);
    return f;
  } catch (e) { log('Backup failed: ' + e.message); }
}

async function startBackend() {
  const cfg = config();
  mongo = await require('./server/open-db').openDatabase(cfg, ensureMongo, { log, stateDir: require('./server/config').dir(), mongoDataDir: path.join(app.getPath('userData'), 'mongo-data') });
  store = new Store(mongo.client.db(cfg.dbName));
  await store.init();
  license = new LicenseManager({ dir: app.getPath('userData'), metaCol: store.c('meta'), log });
  await license.init(); log('License: ' + license.describe());
  await store.acquireLock('electron-' + process.pid, '');
  lockTimer = setInterval(() => store.heartbeat('').catch(() => {}), 10000);
  const r = await store.load(); log('MongoDB connected. Records loaded: ' + r.recs);
  const { server, token } = createServer({ store, license, uiDir: path.join(__dirname, 'ui'), getStatus: () => ({ mongo: true, db: cfg.dbName }) });
  httpSrv = server;
  try { port = await listen(server, cfg.port); } catch (e) { port = await listen(server, 0); }
  log('Local server on 127.0.0.1:' + port);
  return token;
}

async function createWindow() {
  win = new BrowserWindow({ width: 1366, height: 860, minWidth: 1000, minHeight: 650, show: false, autoHideMenuBar: true, title: 'Farm Database',
    webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true, spellcheck: false } });
  win.once('ready-to-show', () => { win.maximize(); win.show(); });
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', (e, url) => { if (!url.startsWith('http://127.0.0.1:' + port)) { e.preventDefault(); if (/^https?:/.test(url)) shell.openExternal(url); } });
  win.on('close', async e => {
    if (quitting) return; e.preventDefault(); quitting = true;
    let ok = true;
    try { ok = await Promise.race([win.webContents.executeJavaScript('window.FarmStore&&window.FarmStore.flush?window.FarmStore.flush():true'), new Promise(r => setTimeout(() => r(false), 8000))]); } catch (x) { ok = false; }
    if (!ok) {
      const c = dialog.showMessageBoxSync(win, { type: 'warning', buttons: ['Stay in the app', 'Quit anyway'], defaultId: 0, cancelId: 0, title: 'Unsaved changes', message: 'The latest changes could not be saved to MongoDB.', detail: 'Stay in the app, export a JSON backup, and check that MongoDB is running.' });
      if (c === 0) { quitting = false; return; }
    }
    await shutdown(); win.destroy(); app.quit();
  });
  await win.loadURL('http://127.0.0.1:' + port + '/');
}
async function shutdown() {
  clearInterval(backupTimer); clearInterval(lockTimer);
  try { store && await store.releaseLock(); } catch (e) {}
  try { if (store && store.loaded) await fileBackup('exit'); } catch (e) {}
  try { httpSrv && httpSrv.close(); } catch (e) {}
  try { mongo && await mongo.client.close(); } catch (e) {}
  try { mongo && mongo.child && mongo.child.kill(); } catch (e) {}
}
function menu() {
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    { label: 'File', submenu: [
      { label: 'Backup now (JSON file)', click: async () => { const f = await fileBackup('manual'); dialog.showMessageBox(win, { message: f ? 'Backup saved:\n' + f : 'Backup failed. See app.log.' }); } },
      { label: 'Open backups folder', click: () => shell.openPath(backupDir()) },
      { type: 'separator' }, { role: 'quit' }] },
    { label: 'View', submenu: [{ role: 'reload' }, { role: 'zoomIn' }, { role: 'zoomOut' }, { role: 'resetZoom' }, { role: 'togglefullscreen' }] },
    { label: 'Help', submenu: [{ label: 'Open log file', click: () => shell.openPath(logFile()) }, { label: 'Open settings folder', click: () => shell.openPath(app.getPath('userData')) }] }]));
}
async function main() {
  menu();
  for (;;) {
    try {
      const token = await startBackend(); global.__token = token;
      await createWindow();
      await fileBackup('start'); backupTimer = setInterval(() => fileBackup('auto'), 6 * 3600 * 1000);
      return;
    } catch (e) {
      log('Startup failed: ' + (e && e.stack || e));
      try { mongo && await mongo.client.close(); } catch (x) {} mongo = null;
      const c = dialog.showMessageBoxSync({ type: 'error', buttons: ['Retry', 'Quit'], defaultId: 0, cancelId: 1, title: 'Farm Database', message: 'The application could not start.', detail: String(e && e.message || e) + '\n\nNo data was changed. Details: ' + logFile() });
      if (c === 1) { app.quit(); return; }
    }
  }
}
app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });
app.whenReady().then(main);
app.on('window-all-closed', () => { if (quitting || !win) app.quit(); });
