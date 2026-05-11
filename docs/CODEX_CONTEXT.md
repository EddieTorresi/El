# El — Codex Technical Context

Last updated: 2026-05-11 (rounds 1-8 + Round-9 deployment + Round-10 app-owned connection cleanup + Apple Health wording cleanup + **Round-13 Apple Health full integration** + **Round-14/15/16 native polish + Apple Health data view** + **Round-17 sandbox git-cache warning** + **Round-18 Apple Health visibility + Budget dark-mode chip fix** + **Round-19 TestFlight/EAS current state** + **Round-20 Apple Health connection state sync** + **Round-21 git safety verification + abort marker clarification**)

This file is a concise reference for Codex (and any AI assistant working on this repo). Read it before making any changes to `index.html`, `sw.js`, or the import/Strava subsystems.

---

## 🔒 2026-05-09 — Pre-launch security hardening (READ THIS)

A full security pass landed across both `El/El` (web/PWA) and the
`ElNative` Expo project. The changes below are intentional — do NOT
"clean up" any of them without understanding why they exist. Each fix
includes a `SECURITY:` comment in the source.

### EL Web (`El/El`)

1. **CSP / Referrer-Policy / Permissions-Policy meta tags** added to
   `index.html` `<head>` (just below `apple-touch-icon`). CSP allows
   inline scripts/styles (the app is single-file inline) but locks
   `connect-src` to the actual API endpoints we call:
   `api.anthropic.com`, `api.openai.com`, `www.strava.com`,
   `www.googleapis.com`, `oauth2.googleapis.com`, `accounts.google.com`.
   When adding a new API, update CSP `connect-src`.

2. **Service-worker offline navigation fallback** added to `sw.js`
   `fetch` handler. Uncached navigations fall back to `./index.html`
   so users see the app shell instead of a network error.

3. **Manifest icons** — added 180×180 entry; bumped 512px to
   `purpose: "any maskable"` for cleaner Android adaptive rendering.

4. **`exportData()` strips secrets.** The list of stripped keys lives
   in `SECRET_KEYS` inside `El.settings.exportData`. **When you add a
   new credential field to `d.settings`, also add it to `SECRET_KEYS`.**
   Strava credentials (in `localStorage.el_strava`) are not exported
   at all. Exports now include `_exportSecretsStripped: true`.

5. **XLSX import — prototype pollution defense.** `_showXLSXPreview`
   defines a local `_safeMerge(...)` helper that replaces every
   `Object.assign({}, A, parsed)` site that touched untrusted XLSX
   data. `_safeMerge` drops `__proto__`, `constructor`, `prototype`
   keys. Any future merge of parsed XLSX content MUST use `_safeMerge`,
   not `Object.assign`.

6. **SheetJS load — pinned URL + CORS + opt-in SRI.** The CDN script
   is loaded with `crossOrigin="anonymous"` and `referrerPolicy=
   "no-referrer"`. The SRI hash is read from a single constant
   `EL_XLSX_SRI` inside `handleSpreadsheetFile`. It defaults to empty
   (no integrity enforcement). To enable SRI before a public launch,
   compute the hash on a trusted machine:
   ```
   curl -sSL https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js \
     | openssl dgst -sha384 -binary | openssl base64 -A
   ```
   …and paste the result as `"sha384-…"` into `EL_XLSX_SRI`. **Do not
   ship a fabricated hash — it silently breaks XLSX import.**

7. **Google Calendar OAuth — auth-code flow with PKCE + state.**
   Replaces the old implicit (`response_type=token`) flow.
   - `El.settings._genCodeVerifier()`, `_genCodeChallenge()`,
     `_genState()` produce the PKCE pair + CSRF state.
   - `startGcalOAuth()` is now `async`, persists `el_gcal_verifier`
     and `el_gcal_state` in `sessionStorage` before redirecting.
   - The boot handler in the `DOMContentLoaded` listener replaces the
     hash-fragment parsing with a `?code=` + state-validation +
     `oauth2.googleapis.com/token` exchange. Refresh token is stored
     in `d.settings.gcalRefreshToken` if Google returns one.
   - **Mutual exclusion with Strava boot handler:** Strava's branch
     fires only when `?code=…&scope=…` is present (Strava puts scope
     in the query). Google's code-flow redirect omits `scope=`, so
     the GCal branch additionally requires `scope=` to be absent. Do
     not change either condition without re-checking both flows.

8. **AI prompt-injection defense (`buildDynamicContext`).** A local
   `_safe(s, max)` helper is applied to every user-supplied string
   that gets concatenated into the system prompt: profile name /
   currency / risk, debt names, savings names, transaction
   descriptions, category names, event titles, plan item text. The
   sanitizer neutralizes any `[[EL_ACTION:` literal so a malicious
   transaction memo or calendar title cannot induce the AI to emit a
   fake action back to us, and caps each field's length so a single
   string can't blow out the context window. **When adding a new
   user-controlled field to `buildDynamicContext`, wrap it in `_safe`.**

### EL Native (`ElNative`)

1. **Duplicate `useElData.tsx` deleted.** `hooks/useElData.ts` is the
   single canonical data layer. Module resolution is no longer
   ambiguous. Do not re-create the `.tsx` variant.

2. **OAuth `state` validation in `useOAuthProvider`.**
   `utils/pkce.ts` now exports `generateState()` (16 random bytes,
   base64url). `useOAuthProvider.connect()` generates a state, sends
   it, and validates the redirect with `safeCompare()` (constant-time)
   before exchanging the code. The redirect URL is also checked to
   start with `provider.redirectUri` so an attacker can't redirect to
   a non-app URL with a stolen state.

3. **`OAuthTokens.extra` whitelist.** `FitnessProviderConfig` now has
   an `extraFields?: readonly string[]`. Only those fields are copied
   from the token response into `extra` before persisting to
   SecureStore. For Strava, `extraFields: ['athlete']`. **Any new
   provider that needs to persist provider-specific data must declare
   the allow-list explicitly.** Token response shape is also validated
   (`access_token` required, `refresh_token` typed if present).

4. **`app.json` store-readiness fields.**
   - `ios.bundleIdentifier`: `com.eddietorresi.elnative`
   - `android.package`: `com.eddietorresi.elnative`
   - `ios.infoPlist`: `NSCameraUsageDescription`,
     `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`,
     `NSAppTransportSecurity { NSAllowsArbitraryLoads: false }`,
     `ITSAppUsesNonExemptEncryption: false`.
   - `android.allowBackup: false` — prevents Google One backup of
     EncryptedSharedPreferences (the SecureStore backing on Android).
   - `android.permissions`: INTERNET, CAMERA, RECORD_AUDIO,
     READ_MEDIA_IMAGES.
   - `android.blockedPermissions`: location (we don't use it; opt out
     so Expo doesn't auto-request).

5. **XLSX import hardening (`app/(tabs)/settings.tsx`).** The
   `SpreadsheetImportModal` defines `MAX_FILE_SIZE` (5 MB),
   `MAX_CELL_LEN` (1000 chars), `MAX_ROWS` (5000), `FORMULA_PREFIX`
   regex, and a `sanitizeCell(raw)` helper. Every cell from CSV or
   XLSX is run through `sanitizeCell` before display or import.
   Formula-injection prefix (`= + - @`) is neutralized by prefixing
   with `'`. Control characters are stripped. File size + row count
   guards reject hostile/oversized inputs.

6. **AI response schema validation (`services/elAI.ts`).** Validators
   `validateAIPlan`, `validateInsights`, `validateElAction` are
   applied to every `JSON.parse` of an LLM response. Validators check
   types, allowed enum values, and numeric ranges (e.g. macro calories
   500–10000, transaction amount 0–1M). Malformed responses return
   `null` instead of being trusted.

7. **AI prompt sanitization (`services/elAI.ts`).** The exported
   `sanitizeForPrompt(s, max)` helper strips `EL_ACTION:` literals
   (rewrites to `EL_ACT_:`) and ASCII control chars, then truncates.
   It is applied to every user-controlled string injected into a
   prompt: transaction descriptions, activity types, quick-capture
   text, category-suggestion description.

### Cross-cutting reminders

- **Don't disable the security comments.** Each `SECURITY:` block in
  source is load-bearing and references this doc.
- **Don't move secrets back into AsyncStorage.** All credentials live
  in `expo-secure-store` (`useOAuthProvider`, `useAI`, `useGoogleCalendar`).
  AsyncStorage holds non-sensitive UI/data state only.
- **Anthropic + OpenAI API calls send user data.** This is documented
  for the upcoming privacy policy. Don't add new fields to the
  `buildDynamicContext` / `services/elAI.ts` prompts without thinking
  about whether the data should leave the device.

### Why CSP keeps `'unsafe-inline'` for script-src

The CSP meta tag in `index.html` allows `'unsafe-inline'` for both
`script-src` and `style-src`. This is intentional and tied to El's
single-file architecture: every script and style block lives inside
`index.html`. Removing `'unsafe-inline'` would require either
(a) adding a CSP nonce to every inline `<script>` (the file has many
of them), or (b) extracting the inline JS to external files — which
breaks the "no build step, no bundler" property the rest of the
project depends on. The CSP still meaningfully reduces risk by:
locking `connect-src` to just the four upstream APIs we actually
call, blocking cross-origin scripts, blocking `<object>`/`<embed>`,
and forbidding the page from being framed. Don't remove
`'unsafe-inline'` casually; it would break boot. If you ever do
extract a build step, drop `'unsafe-inline'` and switch to nonces.

---

## 🔒 2026-05-09 — Round-2 fixes (post-verification sweep)

After the initial security pass, a second sweep was run to verify the
fixes held and to find anything missed. All 13 round-1 fixes verified
clean. Three new findings landed:

1. **EL Native deep-link guard (`app/_layout.tsx`).** A `Linking.add
   EventListener('url', ...)` listener is now mounted at the root
   layout. `ALLOWED_DEEP_LINK_HOSTS` is a `Set` of the six OAuth
   provider hostnames (`strava`, `fitbit`, `googlefit`, `whoop`,
   `polar`, `garmin`). Any incoming deep link whose host is not on
   that list is silently dropped (and logged in `__DEV__`). OAuth
   callbacks normally never reach this listener — they're consumed
   by `WebBrowser.openAuthSessionAsync` first — so the listener is
   effectively a deny-by-default catch for unexpected deep links.
   When you add a new OAuth provider, add its host to the Set.

2. **EL Native AsyncStorage type sanitizer (`hooks/useElData.ts`).**
   Added a `sanitizeStored(raw)` helper that runs BEFORE
   `mergeWithDefaults` on every load from AsyncStorage. It enforces:
   - root must be a plain object (not array, not null, not primitive),
   - dangerous keys (`__proto__`, `constructor`, `prototype`) are
     stripped at every nested level it inspects,
   - arrays-where-arrays-expected are arrays (else `undefined`),
   - objects-where-objects-expected are objects (else `undefined`).
   Any structural mismatch upstream resolves to `DEFAULT_DATA`. This
   protects against a corrupted or hostile-app-modified `el_data`
   payload causing crashes or prototype pollution. It does NOT deeply
   validate every leaf field — call sites already tolerate undefined.
   When you add a new top-level `ElData` field, add it to
   `sanitizeStored` too (else it'll be silently dropped on load).

3. **CSP rationale documented above.** No code change — see the
   "Why CSP keeps `'unsafe-inline'`" subsection.

---

## 🔒 2026-05-09 — Round-3 fixes (Codex audit response)

Codex flagged 8 findings during a third pass. All addressed below.

### EL Web (`El/El`)

1. **AI replies are now escaped before HTML render.** New helper
   `El.ai.safeMd(raw)` escapes all HTML, then re-introduces only
   `**bold**` → `<b>` and `\n` → `<br>`. Wired into the three places
   AI replies become `innerHTML`: chat respond (~line 6498), spending-
   narrate (~line 5779), debt-vs-invest narrate (~line 5808). **Any
   future AI-text-to-HTML path MUST use `safeMd` — never raw
   `.replace(/\*\*.../, '<b>$1</b>')`.**

2. **`addMsg('user', text)` now escapes through `safeMd`.** User-typed
   chat input (and replayed history) used to render as raw innerHTML
   — fixed. The `'ai'` branch keeps the raw-HTML path because every
   caller either pre-runs through `safeMd` (real AI replies) or
   builds trusted button HTML with explicit `esc()` on user fields
   (confirm cards). Don't change the role check without auditing
   every `addMsg('ai', …)` call site.

3. **User-data fields wrapped in `El.escHtml(...)` at every render
   site that builds `innerHTML`.** Sites covered this round:
   - `${d.profile.name}` (home greeting)
   - `${debt.name}` and `${debt.type}` (debts list)
   - `${a.name}`, `${a.type}`, `${a.institution}` (accounts list)
   - `${s.name}` (savings goals)
   - `${s.name}` (income sources)
   - `${e.title}`, `${e.notes}`, `${e.gcal_url}`, `${e.time}` (events,
     both today's-events card and upcoming list)
   - `${ex.name}` (active workout exercise blocks)
   - `${e.name}` (food log items)
   - `${wkt.name}` (workout templates)
   - `${s.name}` (recent workout sessions)
   - `${w.name}` (AI plan workout schedule)
   - `${plan.rationale}` (AI plan rationale block)
   - `${c.name}`, `${c.icon}` (budget category list)
   Already-escaped sites (kept verified): `${El.escHtml(t.description)}`
   in transaction list, `${El.escHtml(r.description)}` in recurring,
   `${El.ai.escapeHtml(item.text)}` in financial plan items.
   **New rule:** any user-controlled string in a template literal
   that becomes `innerHTML` MUST be wrapped in `El.escHtml(...)`.
   The canonical helper lives at line ~1573 in `index.html`.

### EL Native (`ElNative`)

4. **`useGoogleCalendar.ts` now matches `useOAuthProvider`.**
   - `state` parameter generated via `generateState()`, included in
     auth URL, validated on redirect with `safeCompare()`.
   - Redirect URL must `startsWith(GCAL_REDIRECT_URI)` before any
     code is extracted.
   - `loadTokens` validates persisted JSON shape with `isValidTokens`
     before returning.
   - Token-exchange JSON shape is validated before persisting.
   - Local helpers (`getUrlParam`, `safeCompare`, `isValidTokens`)
     mirror the ones in `useOAuthProvider.ts`. If you ever centralize
     them, do it for both at the same time.

5. **`useOAuthProvider.loadTokens` now shape-validates persisted JSON
   via `isValidPersistedTokens()`.** SecureStore returning corrupted
   data (or a different version's schema) no longer crashes the hook;
   the load resolves to `null` and the user is asked to reconnect.

6. **`services/elAI.ts` prompt sanitization completed.**
   `generateFitnessPlan` now runs `params.goal` and activity types
   through `sanitizeForPrompt`. `getWeeklyInsights` now sanitizes
   spending category names and Strava activity types. Combined with
   the round-1 wrapping, every user/provider-controlled string that
   reaches an LLM prompt is now sanitized.

7. **Native JSON-import path runs `sanitizeStored` before saving.**
   `app/(tabs)/settings.tsx` `handleImport` imports `sanitizeStored`
   from `useElData` and uses it instead of trusting raw `JSON.parse`.
   This was the only path that bypassed the AsyncStorage-load
   sanitizer. **Rule:** any new code that loads `ElData`-shaped JSON
   from outside the AsyncStorage path must run it through
   `sanitizeStored` before passing to `saveData`.

8. **Deep-link allow list now includes `googlecalendar`.**
   `ALLOWED_DEEP_LINK_HOSTS` in `app/_layout.tsx` covers all seven
   OAuth provider hostnames (strava, fitbit, googlefit,
   googlecalendar, whoop, polar, garmin). The comment block now
   also documents Expo Router behavior: file-based routing means
   no in-app route can be reached via deep link unless a matching
   file exists under `app/`. The `Linking.addEventListener` is
   defense-in-depth for logging.

---

## 🔒 2026-05-09 — Round-4 fixes (Codex re-verification follow-up)

Codex's second pass after Round-3 found native clean and three
remaining web-side gaps. All addressed here.

1. **More user-data fields wrapped in `El.escHtml(...)`.** Sites
   added in Round-4: `${bill.name}` (Upcoming Bills card),
   `${sub.name}` (subscription tracker), `${plan.goal}` (active
   fitness goal), `${d.profile.name}` in Settings header card,
   plus the input attribute values `value="${d.profile.name}"`
   (Settings → Your Name) and `value="${d.settings?.aiApiKey||''}"`
   (Settings → AI key). The attribute-injection cases matter
   because `escHtml` escapes `"` so a user value containing a
   quote can't break out of the value attribute.

2. **Built-in fallback AI replies routed through `safeMd`.**
   `respond()` now does
   `this.addMsg('ai', this.safeMd(this.generateReply(text.toLowerCase())));`.
   Without `safeMd`, the markdown-style string from `generateReply`
   was rendered as raw HTML even though it interpolates user data
   (debt names, savings, event titles, category names). The real-
   AI reply path was already going through `safeMd`; this matches it.

3. **`fmtBold` in `_renderOkToBuyOption` now delegates to `safeMd`.**
   Was an inline copy of the same "escape → re-introduce `<b>`"
   pattern. Convention check: grep `<b>\$1</b>` in `index.html`
   should match exactly one line — the body of `safeMd`. Any new
   markdown-render path uses `El.ai.safeMd`.

### Pre-launch items still requiring user action

- Compute and paste the SheetJS SRI hash into `EL_XLSX_SRI`. The
  `curl … openssl` one-liner is in the comment above the constant.
- (Optional) Run `npm audit` on `ElNative` and address any
  HIGH/CRITICAL CVEs surfaced for `xlsx@^0.18.5`. Input limits +
  `_safeMerge` already mitigate the parser-level prototype-pollution
  class, but a CVE response is still cleaner.

---

## 🛠 2026-05-10 — Round-5 native UX polish

Pre-test polish pass on the Expo project. None of these are security
fixes — they're correctness/UX cleanups so the app is presentable for
friends-and-family Expo Go testing.

1. **Snapshot of net worth now has a chart.** New `NetWorthHistoryChart`
   component in `app/(tabs)/finance.tsx` renders `data.netWorthHistory`
   as a polyline sparkline (no `react-native-svg` dep — uses rotated
   `View` segments with `transformOrigin: '0% 50%'`). Single-snapshot
   state shows a hint instead of an empty chart. The 📸 button is no
   longer write-only.

2. **Income source UX hardening.** `useElData` now exports
   `updateIncomeSource(src)`. Settings income list extracted into an
   `IncomeSourceRow` component that owns its swipe ref. The
   `IncomeModal` accepts an optional `initial: IncomeSource` for edit
   mode, and shows a live annualization preview
   (`MacroSanityCheck`-style) under the frequency chips so the next
   user can't enter a monthly take-home and silently get an annualized
   number 12× too big.

3. **Macro sanity check.** New `MacroSanityCheck` component lives in
   the Settings Nutrition Goals card. As the user types calories /
   protein / carbs / fat, it shows `${P}P + ${C}C + ${F}F = X kcal vs
   goal Y` colored green (within 10%), orange (10–25%), or red (>25%).
   `handleSaveAll` now hard-rejects calorie targets outside 800–8000,
   protein > 600 g, carbs > 1200 g, fat > 500 g. Drift > 25% prompts
   "Macros don't match calories — save anyway?" override.

4. **Profile + budget validation.** `handleSaveAll` rejects age
   outside 1–120 and monthly budget outside 0–10,000,000. Previously
   you could save age = 3000 with no complaint.

5. **Full-swipe-to-delete consistency.** Five Finance Swipeable rows
   (Transaction, Recurring, Debt, Savings goal, Plan item) and the
   Income source row + Schedule Upcoming row + Today food row all
   share the same pattern:
   - `rightThreshold` set to `DELETE_SWIPE_THRESHOLD` (76 px) — or
     equivalently named per-file constants — so a far-enough swipe
     auto-commits.
   - `onSwipeableOpen={(direction) => { if (direction === 'right') {
     swipeRef.current?.close(); onDelete(); } }}` — single trigger
     path. The row closes immediately so it doesn't sit half-open
     behind the confirm Alert.
   - The `renderRightActions` returns a non-interactive `<View>`
     (NOT a `<Pressable>`). Two trigger paths cause double-fired
     Alerts. Visual-only.
   - **Convention:** every parent's `onDelete` prop must be a confirm
     Alert (not a bare delete call). Five existing call sites already
     wrap; the Transaction and Recurring sites at the parent in
     `BudgetTab` / `RecurringTab` were silently deleting and were
     wrapped in this round. The DebtCard call site was the same — also
     wrapped in this round.
   - `debtCard` style had `marginBottom: 12` baked in, which caused
     the red Delete reveal to bleed into the gap between cards. Moved
     the margin onto a new `debtCardWrap` outer `<View>`. SavingsGoal
     uses the same style and gets the same wrapper.

6. **Schedule layout + double-tap to add.**
   - `CalendarGrid` extracted into its own component with a
     `DOUBLE_TAP_MS = 300` window. Single tap selects the date;
     two taps within 300 ms call `onAdd(dateStr)` to open the Add
     Event sheet pre-filled with that date.
   - Calendar cells now have a 1px transparent base border so the
     today cell's blue border doesn't shift adjacent cells.
   - Upcoming events extracted into `UpcomingRow` matching the
     Finance gesture vocabulary. Synthetic events (recurring bills,
     paydays) render without swipe — they aren't real records and
     can't be deleted directly.
   - Upcoming row text now has `numberOfLines={1}` + `minWidth: 0`
     on the flex parent so long titles ellipsize instead of overflowing.

7. **Income paydays projected onto the calendar.** `buildSyntheticPaydays`
   in `app/(tabs)/schedule.tsx` mirrors `buildSyntheticBills`, seeded
   from `IncomeSource.lastPayDate` and walking forward by frequency.
   Yearly is skipped (too sparse). Both builders are now hardened —
   see Round-7.

8. **Nutrition Today rings + sparkline.**
   - 4 macro rings shrunk from 76 → 62 px, stroke 9 → 7 px so they fit
     comfortably on ~360 px screens. All inner texts have
     `numberOfLines={1}`.
   - Weight 30-day chart converted from a fake bar chart to a real
     polyline sparkline (same rotated-View-segment trick as the net
     worth chart).
   - Today food items extracted into `FoodItemRow` with the standard
     swipe pattern.

9. **Home dashboard:** Net Worth card shows the `$assets − $liabilities`
   breakdown line under the formula label.

10. **Generic "activity sources" copy.** Fitness empty state mentions
    Strava/Fitbit/Google Fit/Whoop/Polar/Garmin instead of just Strava.

---

## 🚨 2026-05-10 — Round-6 NTFS truncation incident + repair

During Round-5, two source files were truncated mid-write by the
NTFS mount:

- `app/(tabs)/finance.tsx` — disk ended at byte 116556 mid-line at
  `paddingVertical:` (no value, no closing brace).
- `app/(tabs)/schedule.tsx` — disk ended at byte 26991 mid-line at
  `flex: 1, backgroundColor:` (no value).

Both repaired by reading the truncated bytes via a fresh Python
`open()`, splicing in the canonical tail, and writing atomically:

```python
tmp = path + '.tmp'
with open(tmp, 'wb') as f:
    f.write(new_bytes)
    f.flush()
    os.fsync(f.fileno())
os.replace(tmp, path)
```

**Root cause hypothesis:** the IDE's Edit tool can succeed in its
in-memory view while the disk write to the NTFS mount gets cut short.
Subsequent Read calls return the in-memory view (looks fine);
`npx tsc`, Metro, and `python3 open()` see the truncated disk view
(crashes/parse errors).

**Detection signal:** if `npx tsc` reports `Expression expected`
mid-style at a column that lines up with a colon-no-value, or if
Metro suddenly can't bundle a file you just edited, treat it as a
truncation and verify with:

```python
with open(path, 'rb') as f: data = f.read()
print(len(data), data[-50:])
```

If the file ends mid-line, repair via the splice+fsync pattern above.

**Update to Critical Write Rules** (see also rules 5–7 below): after
ANY substantial sequence of Edits on a file under the NTFS mount,
verify the disk tail directly via Python `open()`, not via the file
tool, before continuing.

---

## 🐛 2026-05-10 — Round-7 schedule crash root cause

Independent of the file truncation, the Schedule tab had a real
runtime bug in `advanceDate` (`schedule.tsx` line ~25). The function
was:

```ts
function advanceDate(dateStr: string, freq: Frequency): string {
  const d = new Date(dateStr + 'T12:00:00');
  if (freq === 'weekly') ...
  return d.toISOString().slice(0, 10);
}
```

Two crash modes:

- If `dateStr` was malformed (or a stored `IncomeSource.lastPayDate` /
  `RecurringExpense.nextDate` had drifted to a non-`YYYY-MM-DD`
  shape), `new Date(...)` returned Invalid Date and `toISOString()`
  threw `RangeError: Invalid time value`. That throw escaped the
  `useMemo` callback in `ScheduleScreen` and crashed the tab.
- If `freq` didn't match any of the four known values, `d` never
  advanced and the **emit loop** in `buildSyntheticBills` /
  `buildSyntheticPaydays` had no safety counter — infinite loop on
  render, app freeze, native crash.

**Fix:** `advanceDate` now returns `string | null`. Returns `null`
on:
- Non-`YYYY-MM-DD` input
- Invalid Date after parse
- Unknown frequency
- Invalid Date after the per-freq mutation

Both builders treat `null` as "stop iterating" and `continue` the
outer source loop. Both emit loops now have a hard cap of 60
emissions per source so an unforeseen no-advance bug can never
infinite-loop.

**Rule for new synthetic projectors:** every `while (date <= bound)`
that advances a date MUST have BOTH a null check on the advance
result AND a numeric emission cap. Don't trust the bound alone.

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

## 🛠 2026-05-10 — Round-8 native UX polish + AI-validator catch-up

Round dedicated to (a) closing AI-validator gaps Codex's audit found,
(b) the user-requested "swipe a synthetic event → manage source"
chooser in Schedule, and (c) several smaller UX wins.

### AI-validator catch-up

1. **`services/elAI.ts` `quickCapture` and `answerWithActions` now go
   through `validateElAction`.** Both had drifted back to raw
   `JSON.parse(...) as ElAction` casts during a Codex-driven session.
   Re-wired so every AI-emitted action JSON passes the same schema
   guard before reaching `confirmAdd` UI. Convention reinforced:
   **every JSON.parse on an LLM response MUST go through the matching
   `validate*` function.** No exceptions.

2. **`app/(tabs)/nutrition.tsx` `scanFoodWithClaude`** — the Claude
   Vision food / nutrition-label scanner. Now per-field validates the
   AI response before returning. Caps name at 200 chars, calories
   0–10000, protein 0–600 g, carbs 0–1200 g, fat 0–500 g. Out-of-bound
   fields are dropped (the rest of the response is kept as a partial).

3. **`app/(tabs)/finance.tsx` `scanReceiptWithClaude`** — Claude Vision
   receipt scanner. Same pattern: validates description (200), category
   (60), type (`'expense' | 'income'`), date (`YYYY-MM-DD` regex), and
   amount (finite, 0–1M, rounded to cents). Drops bad fields silently.

### Synthetic event delete chooser (the user-asked-for piece)

4. **`RecurringExpense` interface gained `skippedDates?: string[]`.**
   Stores per-occurrence skip dates so the user can hide a single
   projected bill without disrupting the source's `nextDate`.
   `buildSyntheticBills` filters these dates out of future projections
   automatically. Empty/undefined → no skips (default).

5. **`useElData` exposes `skipRecurringInstance(id, dateStr)`.** Adds
   the date to the source's `skippedDates` (deduped via `Set`) and
   persists. Pure data action — no UI logic.

6. **`DisplayEvent` in `schedule.tsx` carries `synthetic?`,
   `syntheticKind?: 'recurring' | 'payday'`, `sourceId?: string`.**
   Synthetic builders fill these so the UI can target the right action.
   These fields are ALL produced by in-app builders — never from user
   or AI input — so no validator needed; trust by construction.

7. **`UpcomingRow` now offers a chooser, not an info dump.**
   - Real event swipe → confirm Alert → delete.
   - Synthetic recurring swipe → "Skip just this one" / "Delete
     recurring item" / "Cancel". Skip writes to `skippedDates`; delete
     calls `deleteRecurring`.
   - Synthetic payday swipe → "Delete income source" / "Cancel" (no
     per-instance skip; income paydays don't have a stable per-date
     concept).
   - Long-press shows the same options plus "Add to Google Calendar"
     when GCal is connected.
   - **Cross-tab consistency:** since both Schedule (Upcoming) and
     Finance (Recurring tab) read the same `data.recurring` state,
     deleting a recurring item from Schedule reflects on the Recurring
     tab automatically — no navigation required.

### Other UX wins this round

8. **Schedule Add Event modal: keyboard dismisses on tap-outside.**
   Outer overlay is now a `<Pressable onPress={Keyboard.dismiss}>`.
   Inputs inside the sheet still work; the modal's dimmed area becomes
   a soft "tap to close keyboard" target.

9. **Schedule day view: empty state is now an inline add button.**
   "No events this day. Tap to add one." — tappable, opens the Add
   Event sheet pre-filled with the selected date.

### Security catch from this round's audit

10. **`sanitizeStored` now validates `skippedDates` per-item.** A
    corrupted or hostile-stored recurring item with non-string members
    in `skippedDates` would have passed through cleanly into the
    runtime Set lookup. Members are now filtered to `YYYY-MM-DD`
    strings only; bad entries are dropped silently.

### Truncations repaired this round

Multiple files truncated mid-Edit again, all repaired via the splice
+ fsync + `os.replace` pattern:
- `services/elAI.ts` (twice — both validator wires)
- `app/(tabs)/finance.tsx` (StyleSheet tail)
- `app/(tabs)/nutrition.tsx` (StyleSheet tail)
- `app/(tabs)/schedule.tsx` (twice — Cards style block, then Modal
  style block)
- `hooks/useElData.ts` (twice — context value provider object)

This is now a recurring pain point. **Critical Write Rule #8 stands
and is being followed:** after every substantial edit run on this
tree, verify the disk tail with Python `open()` not the file tool.
The truncations would otherwise have shipped to Eddie as silent app
crashes.

### Pre-share status after Round-8

- TypeScript compiles clean across all source files.
- All 12 critical files end with `});` / `}` and have balanced
  braces+parens.
- Zero new security blockers from the post-round audit.
- One MEDIUM finding (chat history `JSON.parse` in `ai.tsx` lacks
  shape validation) deferred — already has try/catch fallback, low
  exploitability.
- One LOW finding (Strava credentials JSON.parse in `settings.tsx`
  has minimal validation) deferred — same reasoning.

---

## 🚀 2026-05-10 — Round-9 deployment milestones

This round is about getting Eddie's app off the laptop and onto a
real iPhone. No new features; just deployment plumbing + a small UX
clean-up that surfaced during testing.

### EAS / Apple Developer / dev-client install — DONE

1. **GitHub remote wired for ElNative.** `Downloads/ElNative` was
   previously local-only. Now pushed to
   `https://github.com/EddieTorresi/ElNative` (private). Branch
   `master`, HTTPS remote (SSH key wasn't set up; switched). All
   uncommitted work through Round-8 is committed.

2. **Apple Developer Program enrollment + EAS iOS dev build.**
   - Apple ID: `eddietorresi@yahoo.com`
   - Apple Team: `Eddie Torres (LBD4JAP8XA)` — Individual account.
   - Bundle ID `com.eddietorresi.elnative` registered with Apple.
   - Distribution certificate generated server-side by EAS, valid
     until 2027-05-10.
   - Ad-Hoc provisioning profile generated, includes Eddie's iPhone
     (UDID `00008130-00016D263A93803A`).
   - EAS auto-installed `expo-dev-client` (~5KB dep) when it noticed
     the dev profile didn't have it. Committed.
   - Build #1: `0cca8b78-6f17-4e42-9bb8-182bd5d1e491` —
     `https://expo.dev/accounts/returningnovice/projects/ElNative/builds/...`
   - Project owner: Expo username `returningnovice`.

3. **Dev client installed on Eddie's iPhone.** First-launch hit the
   iOS 16+ "Developer Mode" gate. Process documented:
   - Tap app icon (fails) → forces Developer Mode toggle to appear in
     Settings → Privacy & Security → Developer Mode → toggle ON.
   - Phone restart required (iOS prompts).
   - After reboot, "Turn On Developer Mode?" popup → Turn On.
   - For ad-hoc-distributed dev clients with Developer Mode ON, the
     "VPN & Device Management" trust step is **not** required. The
     app launches directly. (Different from older iOS or
     enterprise-distribution apps where you must trust the developer
     under VPN & Device Management.)

4. **Daily dev workflow now is:**
   ```
   cd "C:\Users\Lap top\Downloads\ElNative"
   npx expo start --dev-client
   ```
   Open the `ElNative (dev)` app on iPhone → it auto-detects Metro on
   the same WiFi → loads the bundle. JS/TSX edits hot-reload in
   seconds. OAuth flows complete because the binary is registered to
   the `elnative://` scheme.

   For non-WiFi networks: `npx expo start --dev-client --tunnel`.

   New native builds only needed when: bumping Expo SDK, changing
   `app.json`, or adding a native module not yet in the bundle.

### Round-9 UX polish

5. **Activity Sync section reframed.** Settings → Activity Sync used
   to label the OAuth provider list as "Provider APIs (mainly for
   developer testing)." Misleading — Phone Health (HealthKit) isn't
   actually wired yet, so the OAuth providers ARE the production path
   for fitness sync today. Reworded:
   - Section intro now says "Connect a fitness service to sync your
     workouts."
   - Toggle button reads "Connect Fitness Services" / "Hide Fitness
     Services" instead of "Show Provider APIs."
   - Hint inside the expanded list points users at each provider's
     developer portal for a Client ID and notes which services need
     a Client Secret.

   The underlying `ActivityProviderCard` component (~90 lines in
   `settings.tsx` line 890) was already correct — saves credentials
   to SecureStore via `providerCredsKey(...)`, runs `oauth.connect`
   with the right args based on `config.requiresSecret`. No code
   change needed.

   **Superseded by Round-10:** this provider-credential UI is no
   longer the user-facing path. Normal app builds should use Apple
   Health for on-device activity data and app-owned backend/proxy
   services for any provider-specific cloud sync.

### Pre-launch items still open

- **Round-10 update (2026-05-10): app-owned connections replace user
  credential setup.** After testing the dev client on iPhone, Eddie
  confirmed the app must feel like a normal consumer app, not a
  developer console. `ElNative/constants/appServices.ts` now reads
  build-time service config from `expo.extra.appServices`:
  `googleCalendarClientId`, `aiProxyUrl`, `transcriptionProxyUrl`,
  and `fitnessBackendUrl`. Secrets must stay server-side behind those
  proxy/backend endpoints; never put client secrets in `app.json`.

- **Settings no longer asks normal users for API keys or provider
  developer credentials.** `settings.tsx` now shows app-managed AI,
  voice, activity sync, and Google Calendar states. Google Calendar
  calls `useGoogleCalendar().connect()` with the bundled client ID
  when present. Activity Sync points users toward Apple Health as the
  main no-credential path and hides the old provider credential form.
  The old direct-key paths are retained only as local developer
  fallbacks when a key was already saved on the device.

- **AI/voice/scanner connection behavior changed.** `useAI.ts` uses
  `appServices.aiProxyUrl` when configured, with a SecureStore key only
  as a developer fallback. `useVoiceInput.ts` uses
  `appServices.transcriptionProxyUrl` first. Finance receipt scanning
  and Nutrition food scanning now use the app AI proxy when configured
  and otherwise show a build-configuration message instead of telling
  users to add an API key.

- **Apple Health prep added, but HealthKit import is not wired yet.**
  `app.json` now includes `NSHealthShareUsageDescription` and
  `NSHealthUpdateUsageDescription` copy. A future native pass still
  needs to add the HealthKit dependency/plugin and implement the actual
  read/import flow for workouts, activities, weight/body metrics, and
  compatible wearable app data.

- **Apple Health UI wording cleanup.** The user-facing Settings card
  now says **Apple Health**, not "Phone Health." The card clearly says
  HealthKit import is not connected in the current build and labels the
  path as "Coming in next dev build." The confusing "Cloud provider
  sync" row was removed from the visible app because it was backend
  implementation language, not an action a normal user can take.

- **SheetJS SRI hash** in El web `index.html` — paste before any
  public launch. Comment above the constant has the curl one-liner.
- **Privacy policy** for the App Store / Google Play submission.
- **TestFlight (iOS) or Internal Testing (Android) release** when
  Eddie wants non-local testers. The `eas.json` already has a
  `preview` profile that's correctly configured for both — switch
  the command from `--profile development` to `--profile preview`.
- **Two deferred LOW security items** from the Round-8 audit
  (`ai.tsx:164` chat-history JSON.parse, `settings.tsx:906` Strava
  credentials JSON.parse) — both have try/catch fallback, neither
  is exploitable today; clean up in a v2 sprint.

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

5. **Don't trust `wc -l` / `tail -1` from bash immediately after a
   Read/Write/Edit on `index.html`.** The NTFS mount returns a stale
   metadata view for several seconds — bash will report the file is
   shorter than it actually is and "tail -1" will show the wrong
   final line. After any edit, verify line count and end-of-file by
   reading the file with the file tool (or wait + `sync` + retry
   bash). Multiple times this pass, bash said the file was 8539 lines
   ending mid-`fetch(...)` while the file tool correctly showed 8720
   lines ending in `</html>`. Trust the file tool.

6. **Anything concatenated into the AI system prompt MUST go through
   `_safe(s, max)` in `buildDynamicContext`.** That helper neutralizes
   `[[EL_ACTION:` injection, strips control chars, and caps length.
   New context fields are the most common source of prompt-injection
   regressions — wrap them at the point of concat, not later.

7. **Anything merged from untrusted parsed data (XLSX, CSV, imported
   JSON) MUST use the `_safeMerge(...)` helper, never `Object.assign(
   {}, target, parsed)` directly.** `_safeMerge` drops `__proto__`,
   `constructor`, `prototype` keys to block prototype pollution.
   Defined locally in `_showXLSXPreview`; copy the same pattern into
   any new import path.

8. **Edit-tool writes to the NTFS mount can silently truncate.** The
   Edit tool's in-memory view can return success while the disk write
   gets cut mid-stream. Symptoms: `npx tsc` reports `TS1109: Expression
   expected` at a column that aligns with a colon-no-value mid-style;
   Metro fails to bundle a file you just edited; `python3 open()` and
   bash `tail` show a truncated tail while the file tool's `Read` shows
   complete content. **After any substantial edit run on the ElNative
   tree, verify the disk tail with `python3 -c "open(p,'rb').read()[-50:]"`
   not via the file tool.** If truncated, repair via the splice + fsync +
   `os.replace` pattern documented in the 2026-05-10 Round-6 section.

9. **Synthetic-event date projectors require a null-safe advance + hard
   emission cap.** Any `while (date <= bound)` loop that walks a date
   forward MUST: (a) treat the advance function as returning `string |
   null` and `break`/`continue` on null, AND (b) cap the per-source
   emission count numerically. Don't rely on the bound check alone —
   if the advance is a no-op (unknown frequency, NaN date), the loop
   will infinite-loop the entire app. See `advanceDate` /
   `buildSyntheticBills` / `buildSyntheticPaydays` in
   `app/(tabs)/schedule.tsx` for the canonical implementation.

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

## ElNative App (React Native / Expo)

**Location:** `C:\Users\Lap top\Downloads\ElNative`

**Framework:** Expo SDK 54, expo-router file-based routing, TypeScript.

### Repository Status

**Current as of 2026-05-11:** `ElNative` is no longer just an Expo Go
test project. It has EAS configuration, an App Store Connect record,
Apple Developer credentials, HealthKit entitlements, and TestFlight
builds in progress. Older notes that say "Expo Go only", "local-only",
or "Phase 4 not started" are historical and should not guide current
deployment/testing work.

Use Expo Go only for UI that does not depend on native modules. For
Apple Health/HealthKit, use a real native development build or
TestFlight build.

### Data Layer

**File:** `hooks/useElData.ts`

- AsyncStorage key: `el_data`
- `ElDataProvider` wraps the root layout (`app/_layout.tsx`)
- `useElData()` hook exposes: `addTransaction`, `deleteTransaction`, `addMacroLog`, `updateMacroLog`, `addWorkoutLog`, `saveSettings`, `clearAllData`

### Strava Integration

**File:** `hooks/useStrava.ts`

- AsyncStorage key: `el_strava`
- OAuth via `expo-web-browser` (no WebView — opens system browser)
- Deep link scheme: `elnative://`
- Token auto-refresh built into the hook

### Screens

All screens live under `app/(tabs)/`:

| File | Screen |
|---|---|
| `index.tsx` | Dashboard |
| `finance.tsx` | Finance |
| `fitness.tsx` | Fitness |
| `nutrition.tsx` | Nutrition |
| `web.tsx` | Web (PWA embed) |
| `settings.tsx` | Settings |

### Color Palette

**File:** `constants/theme.ts`

Exports an `El` object with the following keys: `bg`, `card`, `border`, `textPrimary`, `textSecondary`, `green`, `blue`, `orange`, `red`. All components must use these constants — no raw hex strings anywhere in the codebase.

### Tab Layout

**File:** `app/(tabs)/_layout.tsx`

6 tabs, uses `El` palette throughout, `HapticTab` for native haptic feedback on tab press.

### Root Layout

**File:** `app/_layout.tsx`

Wraps the entire app in `ElDataProvider` so all screens have access to shared data state.

### Running Locally

```bash
cd ElNative && npx expo start --dev-client
```

Requires the installed El development client/TestFlight build on the
phone. Do not scan/open with Expo Go when testing Apple Health.

### Phase 4 (Started)

EAS/App Store Connect work is active. Current iOS bundle identifier is
`com.eddietorresi.elnative`; App Store Connect generated listing name is
`El (3a10f3)` because `El` was unavailable. See Round-19 for the current
TestFlight state and exact next steps.

### Codex Checklist for Any ElNative Change

Before committing any change to the ElNative directory, verify:

1. **TypeScript compiles** — no `any` types unless explicitly annotated with a comment explaining why.
2. **AsyncStorage reads have try/catch** — every `AsyncStorage.getItem` / `setItem` call must be wrapped in a try/catch block.
3. **No hardcoded secrets** — Strava `clientId` and `clientSecret` come from user input at runtime; they must never appear as literals in source files.
4. **El color constants used everywhere** — no raw hex strings; all colors must reference the `El` object from `constants/theme.ts`.

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

---

## 📱 2026-05-09 — ElNative feature parity complete (78/78)

All features from the El PWA have been shipped in ElNative. Beyond strict parity, four new native-only features were added:

- **Receipt scanner** — 📷 button in Add Transaction modal; picks image via `expo-image-picker`, sends base64 to Claude Haiku vision API, auto-fills amount/merchant/date/category.
- **Voice input (Whisper STT)** — 🎙 push-to-talk on AI Chat and Quick Capture; records via `expo-av`, transcribes via OpenAI Whisper API (`/v1/audio/transcriptions`). Requires separate OpenAI API key stored as `el_whisper_key` in SecureStore. See backlog for planned migration to native platform STT.
- **Spreadsheet import** — 📂 document picker for `.xlsx`/`.csv`; parsed with `xlsx` npm package; visual column-mapping UI (date/amount/description/category/type/skip); adds rows as transactions.
- **Google Calendar OAuth** — Settings → Google Calendar; PKCE + state OAuth flow; 📅 button per event in Schedule sends event to Google Calendar API.

### New/changed files in this pass

| File | Change |
|---|---|
| `hooks/useVoiceInput.ts` | Created — expo-av recording + Whisper transcription |
| `hooks/useGoogleCalendar.ts` | Created — GCal OAuth (PKCE + state) + event POST |
| `app/(tabs)/ai.tsx` | Full rewrite — ActionCard system, voice mic, useLocalSearchParams pre-fill |
| `app/(tabs)/finance.tsx` | Receipt scanner in TransactionModal; SpendingChart; CategoryDrilldownModal; Swipeable delete; SubscriptionTracker; JobLossSimCalc; EmergencyImpactCalc |
| `app/(tabs)/index.tsx` | Last Month Recap card; voice mic on QuickCaptureCard |
| `app/(tabs)/schedule.tsx` | Synthetic bill injection; GCal 📅 button per event |
| `app/(tabs)/settings.tsx` | Voice key section; GCal connect section; Spreadsheet import modal |
| `app/(tabs)/fitness.tsx` | Schedule workout → adds to calendar |

---

## 🔒 2026-05-09 — API key security model

### Can a user trick El into revealing the API key?

**Short answer: No, for the native app.**

In ElNative the Anthropic key (`el_anthropic_key`) and Whisper key (`el_whisper_key`) are stored in `expo-secure-store` (iOS Keychain / Android Keystore). They are retrieved immediately before an API call and placed in an HTTP `Authorization` / `x-api-key` header. They are **never** injected into any prompt string, ne

---

## 🍎 2026-05-10 — Round-13: Apple Health full integration (ElNative)

This round took Apple Health from "stub UI / not actually connected" to a
real, end-to-end HealthKit integration that surfaces in five places across
the app. Builds on Round-12's `@kingstinct/react-native-healthkit` v14
install + config plugin work.

### Architecture

| Layer | File | Role |
|---|---|---|
| Native binding | `app.json` | HealthKit plugin entry with `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`; usage descriptions also in `ios.infoPlist`. Requires a fresh dev build (`eas build --profile development --platform ios`). |
| Hook | `hooks/useAppleHealth.ts` | Comprehensive v14 wrapper. 24 read identifiers covering rings, movement, workouts, body composition, vitals, sleep, dietary intake, mindfulness. Single-object auth signature `await fn({ toRead, toShare })`. Every native call wrapped in `try/catch` and surfaced through `state.error` rather than thrown. |
| Data import | `hooks/useElData.ts` | Two new methods exported on the provider: `importHealthWeights(weights)` dedups against `weightLog` by date and returns the count of new entries; `importHealthDayMacros(today)` validates and replaces today's `macroLog` entry. |
| Component (Settings) | `components/apple-health-card.tsx` | Auto-syncs on focus via `useFocusEffect`. Rich status block when synced (rings, movement, sleep, body, vitals, diet, workout count, sources). |
| Component (Dashboard) | `components/health-today-card.tsx` | Compact summary: rings (Move/Exercise/Stand), steps, distance, flights, sleep last night. Auto-fetches on mount + focus. |
| Component (Fitness) | `components/health-workouts-card.tsx` | Last 7 days of HealthKit workouts (type, duration, distance, calories). Auto-fetches on mount + focus, deduped by uuid, newest-first. |
| Component (Nutrition) | `components/import-health-button.tsx` | Reusable button with `kind="weight" \| "macros"`. Dispatches to `useAppleHealth` then `useElData`. |

### Where the user touches Apple Health data

| Screen | Surface |
|---|---|
| Dashboard (`app/(tabs)/index.tsx`) | `<HealthTodayCard />` directly under the Health Score card |
| Fitness → Workouts tab (`app/(tabs)/fitness.tsx`) | `<HealthWorkoutsCard />` at the top of the Workouts segment, above Templates |
| Nutrition → Today tab (`app/(tabs)/nutrition.tsx`) | `<ImportFromAppleHealthButton kind="macros" />` at top of ScrollView |
| Nutrition → Weight Log section | `<ImportFromAppleHealthButton kind="weight" />` directly above the section title |
| Settings → Apple Health card | Auto-syncs on focus, rich multi-section status block |

### Conventions every health component follows

1. `if (!health.isAvailable) return null;` — Android/web render nothing so the parent can drop the component in unconditionally.
2. iOS-without-authorization renders a small "Connect Apple Health" CTA that routes to `/(tabs)/settings`.
3. iOS-with-authorization auto-fetches on mount **and** on screen focus via `useFocusEffect`. Reads are local (no network), so refreshing on every focus is cheap.
4. Native errors are caught inside the hook; components never see thrown errors.
5. Theme colors via `useElTheme()` only; no hardcoded hex.

### Critical: HealthKit v14 API signature

The `requestAuthorization` call **must** pass a single object, not positional arrays:

```typescript
// ✅ CORRECT (v14)
await hk.requestAuthorization({ toRead: READ_IDENTIFIERS, toShare: [] });

// ❌ WRONG (legacy / pre-v14) — throws "expected 1 argument, but received 2"
await hk.requestAuthorization(READ_IDENTIFIERS, []);
```

This is the bug Eddie hit when first tapping Connect on AppleHealthCard. Do not regress this.

### NTFS mid-write truncation — recurring issue

The Edit/Write tools occasionally report success but the file gets cut off
mid-stream on disk (NTFS mount artifact). Symptoms:
- `tsc` reports `TS1005 '}' expected` mid-style or mid-block
- Metro bundle fails with mismatched braces
- `wc -c` shows the file is hundreds of bytes shorter than expected

**Repair pattern (proven this round on `nutrition.tsx`, `fitness.tsx`,
`useElData.ts`, `settings.tsx`, `index.tsx`, `schedule.tsx`, `app.json`):**

```python
import os, tempfile
p = "path/to/file"
with open(p, "rb") as f: data = f.read()

# Append/splice the missing tail
new_data = data + missing_bytes  # or splice via marker

dir_ = os.path.dirname(p) or "."
fd, tmp = tempfile.mkstemp(prefix=".tmp.", dir=dir_)
with os.fdopen(fd, "wb") as f:
    f.write(new_data)
    f.flush()
    os.fsync(f.fileno())   # critical
os.replace(tmp, p)         # atomic
```

The combination of `fsync()` then `os.replace()` defeats the truncation —
ordinary writes through the Edit tool keep getting cut off.

### Files changed this round

| File | Change |
|---|---|
| `hooks/useAppleHealth.ts` | Expanded from stub to comprehensive v14 wrapper (24 identifiers, fetchTodayAll aggregator, fetchWorkouts/fetchWeight/fetchTodayRings/fetchTodayMovement/fetchBodyComposition/fetchVitals/fetchLastNightSleep/fetchTodayNutrition) |
| `hooks/useElData.ts` | +`importHealthWeights`, +`importHealthDayMacros` exposed on context value |
| `components/apple-health-card.tsx` | Auto-sync on focus + rich status block |
| `components/health-today-card.tsx` | New — Dashboard summary card |
| `components/health-workouts-card.tsx` | New — Fitness Workouts tab card |
| `components/import-health-button.tsx` | New — Reusable import button (weight/macros) |
| `app/(tabs)/index.tsx` | Mount `<HealthTodayCard />` after Health Score |
| `app/(tabs)/fitness.tsx` | Mount `<HealthWorkoutsCard />` at top of Workouts tab |
| `app/(tabs)/nutrition.tsx` | Mount `<ImportFromAppleHealthButton />` × 2 (macros + weight) |
| `app/(tabs)/settings.tsx` | Auto-sync via `useFocusEffect`; reworded "Connect Fitness Services" |
| `app/(tabs)/schedule.tsx` | (Round-12 carry-over) `advanceDate` now returns `string \| null`; hard-cap 60 emissions per source; chooser modal for synthetic recurring events |
| `app.json` | HealthKit plugin entry + Info.plist usage descriptions; bundle id `com.eddietorresi.elnative` |

### Test steps for the next dev build

1. `cd ElNative && eas build --profile development --platform ios`
2. Install the resulting `.ipa` on Eddie's iPhone (Ad-Hoc provisioning, dev mode enabled).
3. Open El → Settings → tap Apple Health → grant all categories. Card should switch to "Synced" and show rings/movement/sleep/body/vitals/diet rows when data exists.
4. Pull-down on Dashboard → `HealthTodayCard` should render rings + steps.
5. Fitness → Workouts → `HealthWorkoutsCard` should list any workouts logged via Watch / Strava-to-Health / Nike Run / etc. in the last 7 days.
6. Nutrition → Today → tap "Import from Apple Health" (macros) → today's macroLog should populate from any food-tracking app that writes to HealthKit (MyFitnessPal, Lifesum, etc.).
7. Nutrition → Weight Log → tap "Import from Apple Health" (weight) → up to 30 days of body mass entries should appear, dedup by date.

### Known follow-up

- **Garmin Connect** integration (next): OAuth + activity import. No native SDK available; will use Garmin Connect IQ / Health API REST endpoints over OAuth 1.0a (or OAuth 2.0 via the new Connect Developer Portal).
- **Strava** integration tightening (after Garmin): activity import is wired but should also write back to Apple Health via `saveQuantitySample` so cross-app sync is bidirectional.
- **iOS write-back to Health**: currently `toShare: []` everywhere. Future expansion can let El write weight, water, mindfulness sessions back to HealthKit so other apps see El's data.


---

## 2026-05-10 — Rounds 14-16: Native polish + Apple Health data view (ElNative)

### Round-14 theme contrast pass

- `constants/theme.ts` now has higher-contrast light/dark secondary text plus `textOnAccent` and `cyan`.
- Active tabs, blue buttons, FABs, swipe-delete labels, selected calendar dates, chat bubbles, save buttons, and selected chips use `El.textOnAccent`.
- Finance category chips use `readableTextOn(cat.color)` so bright imported/custom category colors choose readable text automatically.
- `components/themed-text.tsx` link text now asks the theme for `tint`.
- Hidden `app/(tabs)/web.tsx` now uses `useElTheme()`.
- `hooks/useElData.ts` returns updated state from `importHealthDayMacros()` after Apple Health macro import.

### Round-15 Apple Health render-loop fix

- `hooks/useAppleHealth.ts` memoizes the object returned from `useAppleHealth()`.
- This fixes the "Maximum update depth exceeded" crash when opening Apple Health surfaces. The hook previously returned a fresh object on every render; Health cards used that object as a callback dependency, so local `setLoading` / `setData` updates retriggered the fetch effect indefinitely.
- Keep Apple Health callbacks dependent on the stable hook return or specific hook methods/primitives. Do not reintroduce a fresh object return from the hook.

### Round-16 Apple Health data view

- Added `components/health-data-card.tsx`, a full Apple Health data surface that shows the data El can read:
  - Activity today: move calories, exercise, stand, steps, walk/run distance, cycling distance, flights, mindful minutes.
  - Body: weight, body fat, lean mass, BMI, height.
  - Vitals: resting heart rate, HRV, SpO2, respiratory rate, body temperature.
  - Sleep: date, asleep, deep, REM.
  - Nutrition today: calories, protein, carbs, fat, water.
  - Workouts: last-7-day count and latest workout summary.
- Mounted this card in **Fitness -> Activities** as the primary place to see Apple Health data.
- Mounted the same card under **Settings -> Activity Sync** after the Apple Health connection card, so the connection screen also previews real data after authorization.
- `useAppleHealth.ts` checks HealthKit's `getRequestStatusForAuthorization()` on startup. If Apple Health was already connected in a previous app run, El marks it connected and can show data without making the user tap Connect again.
- Fitness empty-state copy now says Apple Health is the main no-key source instead of referencing a future HealthKit pass.

### Round-18 Apple Health visibility + Budget dark-mode chip fix

- `app/(tabs)/finance.tsx` now gives `smallChipLabel` an explicit `El.textSecondary` color. This fixes the Finance -> Budget transaction/category chips defaulting to black in dark mode.
- `components/health-data-card.tsx` now defaults to a visible unavailable state instead of returning `null`, and the copy explains the real constraint: Apple Health needs an iOS development, TestFlight, or App Store build. Expo Go and web previews cannot load the native HealthKit module.
- `app/(tabs)/fitness.tsx` and `app/(tabs)/settings.tsx` force the Apple Health data card to remain visible on Fitness -> Activities and Settings -> Activity Sync, so connection state and diagnostics are visible even before data is flowing. `components/health-today-card.tsx` now does the same on Home.
- `hooks/useAppleHealth.ts` normalizes HealthKit responses that may arrive as either arrays or `{ samples: [...] }`, and treats `requestAuthorization()` as connected unless the native module explicitly returns `false`. This prevents the UI from staying blank after the Apple permission sheet completes.
- Apple Health still must be tested on a real iPhone build with HealthKit entitlements. The proper path is an iOS development build or TestFlight/App Store build, then Settings -> Activity Sync -> Connect Apple Health, grant read permissions, and check Fitness -> Activities plus Settings -> Activity Sync.

### Round-19 TestFlight / EAS current state

- Current iOS path is **EAS + App Store Connect/TestFlight**, not Xcode. Eddie is on Windows; Xcode Cloud/Xcode is optional and not required for this workflow.
- Do not use Expo Go for HealthKit validation. Apple Health requires a real native build with HealthKit entitlements. Use either:
  - Development build: `eas build --platform ios --profile development`, then `npx expo start --dev-client`.
  - TestFlight build: `eas build --platform ios --profile production`, then `eas submit --platform ios --latest`.
- Build workflow rule:
  - Most JS/TSX/UI/business-logic changes do **not** require a fresh native build when testing locally. Use the installed development client and run `npx expo start --dev-client`; the app loads the newest bundle from the computer.
  - TestFlight installs are fixed snapshots. To see JS changes in TestFlight, upload a new TestFlight build.
  - Fresh native builds are required for `app.json`, icon/splash assets, app name/bundle id, iOS permission strings, HealthKit/plugin/entitlement changes, native dependency add/remove, Expo SDK/React Native upgrades, and any build meant for TestFlight/App Store testers.
- App Store Connect app record currently shows generated name `El (3a10f3)` because the exact listing name `El` was already taken/reserved. This does not block the installed app from being named `El`; it only affects the public App Store listing name, which can be changed later to a unique name.
- Production build history:
  - Build `1.0.0 (2)` uploaded successfully but was sent into TestFlight Beta App Review and shows `Waiting for Review`. Ignore it for immediate internal testing.
  - Build `1.0.0 (3)` uploaded successfully on 2026-05-10 around 11:42 PM and shows `Ready to Submit` on the iOS Builds page. It should be used for internal testing.
- Internal testing setup:
  - Internal group: `Team`.
  - Tester: `eddietorresi@yahoo.com` / Eddie Torres.
  - If TestFlight on the phone asks for an invite code, the usual cause is that no usable build is attached to the internal group yet.
  - In App Store Connect, go to `TestFlight -> Internal Testing -> Team -> Builds` and add build `1.0.0 (3)`. Do not use External Testing and do not click Submit for Review for internal-only testing.
  - After build `3` is attached to the group and Eddie is listed under `Team -> Testers`, TestFlight should show the app or send an invite email. If it does not, remove/re-add Eddie to the group to resend the invite.
  - Confirmed fix: Eddie removed himself from the internal tester group, added himself back, received the TestFlight email, and was then able to install the app. If TestFlight asks for an invite code again, refresh the internal tester membership before rebuilding or changing Xcode/EAS settings.
- App icon/splash are still using Expo starter assets (`assets/images/icon.png` is the blue Expo-style A). This is cosmetic and not a setup failure. Replace icon/splash before wider TestFlight/public sharing; any asset change requires a new native build.

### Round-20 Apple Heal
---

## 🔧 2026-05-11 — Round-22 setup: filesystem branch-subdirectory issue

When creating a git branch with a slash in the name (e.g. `fix/ai-tab-key-entry`), git failed with:

```
fatal: cannot lock ref 'refs/heads/fix/ai-tab-key-entry':
unable to create directory for .git/refs/heads/fix/ai-tab-key-entry
```

The filesystem (Windows NTFS / OneDrive / restrictive ACL on the path) prevents git from creating subdirectories under `.git/refs/heads/`. Slash branch names require git to mkdir a subdirectory; the underlying filesystem won't allow it.

**Resolution: use hyphenated branch names instead of slash-prefixed.** All future branches in this repo follow the pattern `<type>-<slug>` not `<type>/<slug>`:

- `fix-ai-tab-key-entry` (not `fix/ai-tab-key-entry`)
- `feat-privacy-reset-all-data` (not `feat/privacy-reset-all-data`)
- `chore-privacy-policy-and-audit` (not `chore/...`)

GitHub renders these identically in the branch list. The `<type>-` prefix preserves the categorization. No code or workflow changes needed beyond the naming convention.

If you need to debug whether the FS issue persists, from PowerShell:

```powershell
cd 'C:\Users\Lap top\Downloads\ElNative'
mkdir .git\refs\heads\test-subdir; rmdir .git\refs\heads\test-subdir
```

If `mkdir` errors, the FS still blocks subdirectories. If it succeeds, slash-named branches would work — but the hyphenated convention is fine to keep regardless.

