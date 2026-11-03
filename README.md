# Farm Database – Windows desktop app (Electron + Node.js + MongoDB)


> **Online (internet) mode:** see `ONLINE-GUIDE-FA.md` – GitHub + Render.com + MongoDB Atlas (`npm run cloud`, `render.yaml`).

Your original app is untouched in `app/farm-database-ps.html` (it already includes the new Finance Center).
The desktop build is generated from it: only the browser-storage part (IndexedDB) is swapped for a MongoDB-backed
storage layer, and Google Fonts / the Excel CDN are made local so the app works with no internet.

## Quick start (browser mode, no Electron needed)
1. Double-click **install.bat** once. It checks Node.js (18+) and MongoDB, installs the packages (internet needed only here),
   builds the offline UI and prepares the database. Existing data is never touched.
2. Double-click **start.bat** whenever you want to work. It starts the backend, connects to MongoDB and opens the app in your default browser.
   Keep the black window open while you work; close it to stop (a JSON backup is written to `Documents\FarmDatabase-Backups`).
* Starting twice never creates a second server: the existing one is reused and the browser opens again.
* If port 47831 is busy, the next free port (up to 47840) is used automatically.
* Any error keeps the window open with instructions. Settings: `%APPDATA%\Farm Database\config.json`.
* The browser mode and the Electron app share the same MongoDB database and a lock stops them from running at the same time.

The sections below describe the Electron desktop app / installer (optional).

## How it works
```
Electron window  ──http (127.0.0.1 only, secret token)──▶  Node.js backend (server/)  ──▶  your local MongoDB
 (your existing UI)                                         store.js: one MongoDB document per record
```
* Each record (calf, feed, sale, debt, salary …) is its own document in collections `rec_calves`, `rec_feeds` …, database `farm_database`.
* Also stored in MongoDB: app settings/theme/language (`kv`), calf photos (`photos`), compressed snapshots (`snapshots`).
* Safety: nothing is written before a successful load; a save that would remove more than half of a table asks for confirmation;
  automatic JSON backups go to `Documents\FarmDatabase-Backups` (at start, exit and every 6 h, last 30 kept);
  the window will not close silently if the last changes could not be saved.
* Startup: connects to MongoDB at `mongodb://127.0.0.1:27017`; if it is not running it starts the "MongoDB" Windows service,
  and if that fails it starts `mongod.exe` itself. If MongoDB still cannot be reached you get a Retry/Quit dialog – the app never opens on an empty fallback database.
* **No MongoDB needed (automatic fallback):** if MongoDB cannot be reached or started, the application stores its data in its own files in `%APPDATA%\Farm Database\data` and works the same. Settings in `config.json`: `"storage": "auto"` (default) | `"mongo"` (MongoDB only) | `"file"` (always built-in). Once the built-in storage is in use it stays in use, and a MongoDB that was used once is never silently replaced by an empty store. Backups still go to `Documents\FarmDatabase-Backups`.
* Connection problems: double-click `check-mongodb.bat` – it tests every way of reaching MongoDB (127.0.0.1 / localhost / the port in MongoDB's own config), reports service state, password/port/version problems and saves the report to `%APPDATA%\Farm Database\mongo-diagnose.txt`.
* Settings file: `%APPDATA%\Farm Database\config.json` (`mongoUri`, `dbName`, `port`). For a MongoDB with a password use
  `"mongoUri": "mongodb://user:pass@127.0.0.1:27017/?authSource=admin"`. Log: `%APPDATA%\Farm Database\app.log`.

## Step 1 – install dependencies (needs internet once)
```
cd farm-desktop
npm install
```
## Step 2 – test it on your machine
```
npm run selftest:fake      # 14 checks, no MongoDB needed
npm run selftest           # same checks against YOUR MongoDB (temporary db "farm_selftest", deleted afterwards)
```
Both must end with `0 failed`.
## Step 3 – move your existing data
In your current app (same browser as before): Settings → export JSON backup (photos are included). Then either
* start the desktop app and use the app's normal **import backup**, or
* run `npm run import-backup -- "C:\path\farm-backup-….json"` (saves the current MongoDB content to a safety file first).

Note: the app password is stored by the app outside the backup file, so set your password again once in the desktop app (it is then kept in MongoDB).
## Step 4 – run
```
npm start
```
## Step 5 – build the installer
```
npm run dist
```
Result: `dist\Farm Database Setup 1.0.0.exe` (NSIS installer, desktop + Start-menu shortcut, choose install folder).
The first build downloads Electron/NSIS (internet needed only for building). Optional icon: put `icon.ico` (256×256) in `build\`.
MongoDB is **not** bundled: the PC running the app needs MongoDB Community installed (as on yours). Uninstalling keeps your data.

## Offline notes
Everything core works offline. The optional online assistant in the app (api.anthropic.com) is blocked by design.
Persian fonts fall back to Windows fonts (Tahoma/Segoe UI); to use Vazirmatn offline, copy the font files into `ui/` and add an `@font-face`.

---

# Licensing (offline annual license)

The application needs a license key. Each key is worth **365 days**. Activation and renewal work completely **offline**:
the customer pastes a key, nothing is sent anywhere.

| Situation | What happens when a key is entered |
|---|---|
| First activation | valid for 365 days from today |
| Renewal **before** expiry | 365 days are **added to the current expiry date** (renew early without losing days) |
| Renewal **after** expiry | a **new** 365-day period starts today |
| Same key entered twice | refused (every key works once) |

**After expiry** the application becomes **read-only**: all data can still be viewed and exported (Excel, JSON backup), but
nothing can be added, edited or deleted. **No data is ever deleted** and entering a renewal key restores full access at once.

## Customer: first start (Windows)
1. Run **install.bat** once (as before), then **start.bat**.
2. The license screen appears (English / دری / پښتو). It shows the **Computer ID**.
3. Send the Computer ID to the vendor only if the vendor asked for a computer-bound key (otherwise not needed).
4. Paste the key you received (or press *Load key from file* and choose the `.lic` file) -> **Activate license**.
5. The application opens. A small badge at the bottom corner shows the days left; click it any time to see the status or renew.
   30 days before expiry the badge turns amber.

**Renewal:** click the badge (or the red bar when expired) -> paste the new key -> *Renew license*.

**Status without opening the app:** double-click **license-status.bat** (shows Computer ID, state and expiry).

## Messages you may see
| Message | Meaning / action |
|---|---|
| Not activated | enter a key |
| Expired - read-only | data is safe; enter a renewal key |
| Date / time problem | the PC clock is earlier than the last time the app was used. Correct Windows date/time (turn on "Set time automatically"). If the date had been set wrongly into the future by mistake, ask the vendor for a **clock-reset key** |
| Different computer | the key/state belongs to another PC; send the Computer ID to the vendor |
| "key not genuine / modified" | the key was copied incompletely or altered; copy it again in full |
| "already used" | that key was already entered; ask for a new one |

## How it is protected (and honest limits)
* Keys are **signed with Ed25519**. The application contains only the **public key** and can verify but never create keys.
  The private key lives only in the owner tool (`farm-license-tool`), which is **not part of this application**.
* The license state is stored twice (file `%APPDATA%\Farm Database\license.json` and MongoDB `meta` collection), sealed with a
  checksum; a deleted or edited copy is repaired from the other one.
* **Clock tampering:** the app remembers the latest time it ever saw (and the time of the last data save in MongoDB). If the
  clock is set back by more than 10 minutes, the app goes read-only until the clock is correct. A key also cannot be entered
  while the PC date is earlier than the key's issue date.
* Enforcement is in the **Node.js backend** (data writes are refused with HTTP 402), not only in the screen.
* No offline licensing is unbreakable: someone who can modify the program files or delete *both* license copies on the PC
  can bypass it. This system stops normal users from sharing keys, re-using keys, editing dates or rolling back the clock.
  Optional **computer-bound keys** make a key usable on one PC only.

## Developer notes
* `server/license/` - verification + state (`crypto.js`, `index.js`), `public-key.js` holds the public key (empty until you run the owner tool's `keygen`).
* `ui/license-ui.js` - activation screen; `ui/farmstore-mongo.js` waits for it before loading data.
* `npm run test:license` (41 checks) and `npm run selftest:fake` (all suites). `createServer` now requires a `license` object.
* The Electron build includes everything automatically (`server/**`, `ui/**`).


## Several users on the network (browser access)

`start.bat` now runs in **network mode** (`"lan": true` in `%APPDATA%\Farm Database\config.json`; set `false` for single-user, local-only use).

1. Run `start.bat` on the main computer (the server). It prints the addresses, e.g. `http://192.168.1.20:47831/`.
2. **First start:** in the browser that opens on the server, create the **manager** account. This is only possible on the server computer itself.
3. Other computers/phones on the same network open the printed address in a browser and log in. If they cannot connect, run `allow-network.bat` once as administrator on the server.
4. The manager opens **Users** (bottom corner of the screen) to add users, reset passwords, disable or delete accounts, and set the role.

**Roles**

| | Manager | User |
|---|---|---|
| See all data | yes | yes |
| Add / edit daily data (calves, feed, weights, treatments, sales ...) | yes | yes |
| Delete records | yes | no |
| Employees and salaries | yes | no (tab hidden) |
| Settings, backup/restore, wipe, shared theme | yes | no |
| User accounts, license activation/renewal | yes | no |

Data added by one person appears on everybody's screen within a few seconds, without reloading. Changes are saved record by record, so two people working at the same time never overwrite each other (if two people edit the *same* record at the same moment, the last save wins). The rules are enforced by the server; to move a permission between manager and user edit the lists at the top of `server/auth.js`.

Notes: the server computer must stay on with `start.bat` open; restarting it logs everybody out. Do not expose the port to the internet (use it inside your own network only).
