# El — Codex Technical Context

Last updated: 2026-05-08 (build v20)

This file is a concise reference for Codex (and any AI assistant working on this repo). Read it before making any changes to `index.html`, `sw.js`, or the import/Strava subsystems.

---

## App Architecture

El is a **single HTML file** (~8,458 lines as of v20). All app logic, styles, and markup live in `index.html`. There is no build step, no bundler, no separate JS/CSS files.

**State storage:** All app data is stored in `localStorage` under the key `el_data` (parsed into the variable `d` at runtime). Strava tokens use a separate key `el_strava`.

**Namespace structure:**

| Namespace | Responsibility |
|---|---|
| `El.finance` | Transactions, budgets, debts, savings, net worth, What If cards |
| `El.fitness` | Workout templates, logs, exercise detail, PR tracking |
| `El.macros` | Daily macro goals, food log, calorie bonus from activities |
| `El.dashboard` | Home screen cards, spending velocity, weekly delta |
| `El.settings` | Import, spreadsheet mapper, app preferences |
| `El.strava` | OAuth flow, token exchange, activity sync, macro adjustment |

**Build string:** A `BUILD` constant in `index.html` and the cache name in `sw.js` must always match. Bump both when shipping a release — mismatches leave stale service-worker caches on devices.

---

## Critical Write Rules

These rules exist because of real data-loss incidents in prior sessions:

1. **Never use `replace_all: true` on `index.html`.** The Edit tool's replace-all mode has caused full-file truncation. Always use targeted, unique `old_string` → `new_string` edits.

2. **Never write directly to the NTFS mount without `os.fsync()`.** Buffered writes to Windows-mounted paths can appear to succeed but leave the file partially written. Always build in `/tmp`, verify the result, then fsync-write to the destination.

3. **Verification checklist before any commit of `index.html`:**
   - Line count ≥ 8,400 (`wc -l index.html`)
   - BUILD string in `index.html` matches the cache name in `sw.js`
   - `El.strava` namespace intact — grep count should be ~23 occurrences
   - `_findSheet` helper present
   - No JS syntax errors (`node --check index.html` or equivalent)
   - File ends with `</html>` (`tail -1 index.html`)

4. **Safe write pattern:**
   ```bash
   # Build in /tmp
   cp index.html /tmp/index_new.html
   # ... make edits to /tmp/index_new.html ...
   wc -l /tmp/index_new.html          # must be ≥ 8400
   tail -1 /tmp/index_new.html        # must be </html>
   # fsync-write to destination
   python3 -c "
   import shutil, os
   shutil.copy('/tmp/index_new.html', 'index.html')
   with open('index.html', 'a') as f: os.fsync(f.fileno())
   "
   ```

---

## Strava Integration (`El.strava`)

OAuth 2.0 flow with PKCE-free server-side token exchange.

**Token exchange endpoint:** `POST https://www.strava.com/oauth/token`

**Redirect URI:** `https://eddietorresi.github.io/El/`

**Token storage key:** `localStorage.el_strava`

Fields stored in `el_strava`:
- `clientId`, `clientSecret` — entered by user in Settings
- `accessToken`, `refreshToken`, `expiresAt` — from OAuth exchange
- `athlete` — athlete object from Strava response
- `adjustMacrosEnabled` — boolean, defaults `true`

**Activity sync:** `GET https://www.strava.com/api/v3/athlete/activities?per_page=10&after={unixTimestamp}`
Where `{unixTimestamp}` = 7 days ago.

**Macro bonus:** `d.macros.calBonus[YYYY-MM-DD]` (number, extra kcal to add to that day's goal). Set by `adjustMacros()` when an activity exceeds ~300 cal (kJ ÷ 4.184). Only fires when `el_strava.adjustMacrosEnabled === true`.

**Page-load auto-exchange:** `El.strava.init()` runs on every page load. If `?code=` is present in `window.location.search`, it calls `exchangeCode(code)` and then `history.replaceState` to clean the URL.

---

## Spreadsheet Import (`El.settings._mapTrackerToElData`)

Uses **SheetJS (XLSX)** loaded from CDN.

### `_findSheet(wb, ...keys)`

Fuzzy sheet-name matcher. For each candidate key, strips all non-alpha characters and compares case-insensitively against stripped versions of `wb.SheetNames`. Returns the first matching sheet object, or `null` if none found. Always use this instead of `wb.Sheets[exactName]`.

```js
// Example
const ws = _findSheet(wb, 'El Import - Workouts', 'Import Workouts');
```

### "El Import - Workouts" sheet format

| Col | Field | Notes |
|---|---|---|
| A | Workout name | Blank = continuation row; use `lastWorkoutName` |
| B | Exercise name | |
| C | Sets | |
| D | Reps | |
| E | Weight (lbs) | `BW` or `0` = bodyweight |

**`lastWorkoutName` pattern:** Declare `let lastWorkoutName = ''` before the row loop. On each row: if col A is non-empty, update `lastWorkoutName = colA`. Use `lastWorkoutName` as the workout name for every row regardless of whether col A is blank.

### "El Import - Macros" sheet format

| Col | Field |
|---|---|
| A | Metric name (Calories, Protein, Carbs, Fat) |
| B | Value |

### Other sheets parsed from Financial Tracker

- **Dashboard** — income
- **Debts** — debt accounts
- **Expenses** — recurring expenses + budget categories
- **Net Worth** — savings accounts, vehicle assets
- **Notes & Goals** — financial plan text

---

## ElNative (React Native companion)

**Location:** `C:\Users\Lap top\Downloads\ElNative`

**Stack:** Expo SDK 51, React Native, tab navigator.

**Tabs:** Finance, Fitness, Nutrition, Dashboard, Settings.

**Web tab:** Loads the live GitHub Pages PWA (`https://eddietorresi.github.io/El/`) in a `WebView` component — this is the primary mobile interface for now.

**`react-native-health`:** Listed in dependencies but dormant. Native HealthKit integration is not yet wired up; it requires a proper native binary build (not Expo Go).

**Colors:** Defined in `constants/Colors.ts`.

---

## CI / GitHub Actions

**Script:** `scripts/check-integrity.sh`

**Checks run:**
- `MIN_LINES=5500` — file must have at least this many lines
- `</html>` present at end of file
- Brace balance within ±10 (threshold raised from ±2 to handle Windows `grep -o` multi-byte character variance; real truncations are always off by 50+)

**`.gitattributes`:** Repo root contains `* text=auto eol=lf` and `*.sh text eol=lf`. This prevents CRLF conversion from corrupting shell script shebangs on Ubuntu CI runners. Added in v20 (commit `8a670c2`) after a CI failure caused by exactly this.

---

## Git Gotchas

**`.git/index.lock` stuck lock:** Sandbox sessions (Cowork, CI, etc.) can leave a lock file behind. If `git add` or `git commit` errors with "index.lock already exists":

```powershell
# In PowerShell on Windows
del .git\index.lock
```

Then retry the git command.

---

## Key Commit Reference

| Commit | Description | Lines |
|---|---|---|
| `8a670c2` | feat: activity macros toggle, Strava OAuth (v19+v20) | 8,458 |
