# El App — AI Collaboration Context

> Read this before touching any file. It exists so Claude, Codex, or any other AI has full context and doesn't suggest changes that break what's already working.

---

## What El Is

El is a single-file HTML personal life assistant app built for Eddie Torresi. It's currently in personal iPhone testing via GitHub Pages. The goal is not a polished public product yet — it's a useful personal tool that becomes the first place to capture calendar items, money decisions, reminders, meals, workouts, and loose thoughts before they get forgotten.

**Live URL:** https://eddietorresi.github.io/El/  
**Repo:** https://github.com/EddieTorresi/El  
**Local path:** `C:\Users\Lap top\Downloads\El\El\`

---

## Product Direction

El should give clarity to people who are unorganized, overwhelmed, or normally bad planners. The product pillars in order:

1. **Capture first** — anything can be dropped in, natural language
2. **Organize second** — El parses and files it correctly
3. **Advise third** — El gives smart financial and life advice

Finance is the long-term core. The goal is conversational decision clarity: not just budget tracking but answering questions like "I make $150k, have $5k saved, and want an $80k car with $70k debt. How bad is that really, and what would happen if I invested instead?"

---

## Architecture — Critical to Understand

**Single-file app.** Everything lives in `index.html` — all CSS, HTML, and JavaScript. No build step, no npm, no bundler. This is intentional for the current testing phase.

**No backend.** The app runs entirely in the browser. Data is stored in `localStorage` under the key `el_data`. There is no server, no database, no API of our own.

**Key JavaScript objects:**
- `El.state` — manages localStorage: `load()`, `save()`, `get()`, `set()`, `defaults()`, `migrate()`. The starter category list lives in module-level `DEFAULT_CATEGORIES` (outside `defaults()`); IDs `cat1..cat6` are stable.
- `El.ai` — the AI assistant: `init()`, `send()`, `respond()`, `saveHistory()`, `clear()`, `quickCapture()`, `isConfigured()` (true only when provider is claude/openai AND apiKey is set), `pickClaudeModel(text)` / `pickOpenAiModel(text)` (Auto routing), `analyzePurchaseFromForm()` (OK-to-Buy AI deep-dive), `_STATIC_PROMPT` + `buildDynamicContext()` (split for Anthropic prompt caching).
- `El.render` — renders each screen: `home()`, `finance()`, `schedule()`, `fitness()`, `ai()`, `settings()`
- `El.nav` — tab navigation including `refreshAiVisibility()` which hides `#nav-ai` until an API key is configured.
- `El.finance` — feature module. Includes `healthScore()` / `healthDetail()` (5-component weighted score) and `openHealthBreakdown()` (modal), `evaluateBuy({price, downPayment?, months?, apr?})` (local OK-to-Buy verdict), `processRecurring()`, `calcPayoff()`.
- `El.schedule`, `El.fitness` — feature modules
- `El.ui` — UI helpers including `showToast(msg, type, duration)`, `closeModal()`, `openModal()`, `catOptions()` (shared category-dropdown HTML), `updateOkToBuy()`, `toggleOkToBuyFinance()`.
- `El.debug` — boolean flag (default false). Gates expected-path `console.warn` / `console.error` so production logs stay clean.
- `window.EL_BUILD` — global build string set in `<head>`. Must match `BUILD` constant in `sw.js` and the `<!-- El fix build: ... -->` comment. Bump on every release so the SW cache self-invalidates and the visible "build" tag in Settings updates.

**Boot sequence (DO NOT BREAK):**
```javascript
document.addEventListener('DOMContentLoaded', () => {
  const data = El.state.load();
  if (data && data.profile && data.profile.name) {
    document.getElementById('onboarding').style.display = 'none';
    document.getElementById('app').style.display = 'flex';
    try { El.init(); } catch(e) { /* safe mode fallback */ }
  }
});
```
This is what skips onboarding for returning users. If this block is missing or broken, every page refresh shows the onboarding screen. **This has been accidentally deleted twice — protect it.**

**AI action system:**
The AI uses a structured action format embedded in its response:
```
[[EL_ACTION:{"type":"income","data":{"name":"Job","amount":3000,"frequency":"monthly"}}]]
```
Multiple action blocks per response are supported and expected. `extractElActions()` parses all of them; `handleElAction()` executes each. The system prompt tells Claude to emit multiple blocks when the user mentions multiple items.

Supported action types: `transaction`, `income`, `income_events`, `debt`, `savings`, `event` / `events`, `log_food`, `log_workout`, `category`, **`set_budget`** (added v4 — updates a category's `allocated` amount, creates the category if missing).

**Model selection (v4):**
- `d.settings.aiClaudeModel` — `'auto'` (default) or a specific model id. Auto routing in `pickClaudeModel(text)`: short capture-style messages → `claude-haiku-4-5-20251001`, heavy analysis ("ok to buy", "plan", "strategy", >400 chars) → `claude-opus-4-6`, everything else → `claude-sonnet-4-6`.
- `d.settings.aiOpenAiModel` — `'auto'` (default) or a specific model id. Same routing logic in `pickOpenAiModel(text)`: lite → `gpt-4o-mini`, heavy → `gpt-4.1`, default → `gpt-4o`.
- The user can pin a specific model via Settings; Auto only runs when the setting is `'auto'`.

**Token optimization (v4):**
- System prompt is split into a static block (action schemas, format rules, role) and a dynamic block (live data snapshot).
- Anthropic calls send the static block with `cache_control: { type: 'ephemeral' }` so it's cached for ~5 minutes and charged at ~10% on repeat turns.
- Dynamic block is capped: top 10 debts/savings, last 60 month-of transactions, last 12 in the recent line, max 10 upcoming events, last 5 workout sessions.

**AI history persistence:**
Conversation history is saved to `d.aiHistory` (last 40 messages) via `El.ai.saveHistory()`. On `init()`, saved history is reloaded so conversations persist across sessions.

---

## Current Features (as of 2026-04-29 build v4)

- **Home screen:** Capture card with natural language input + voice/mic button, daily command center (today/tomorrow/next action), greeting with financial summary, **30-day backup-reminder banner** (v3) that disappears when `d.settings.lastExportAt` is fresh, **API-key-required banner** (v3) inside the capture card when `El.ai.isConfigured()` is false.
- **Finance tab:** Transactions, recurring expenses and income, debts, savings goals, net worth tracking, budget categories.
  - **What If?** subtab: New Debt Impact, Compound Interest, Goal Planner, Buy vs Loan, Job Loss Runway (auto-fills monthly expenses from transactions, v3), Emergency Impact, **🛒 OK to Buy?** card (v4 — instant local verdict + optional "Ask El for deeper analysis" button).
  - **Financial Health** card on Home is tappable; opens a breakdown modal showing the 5 weighted components (v3 rewrite — emergency fund / DTI / net-worth / budget adherence / 30-day trend).
- **Schedule tab:** Calendar view with recurring item dots, event management, Google Calendar OAuth integration.
- **El AI tab:** Full chat assistant with voice input, history persistence, auto-action parsing. Tab is **hidden in the bottom nav until an API key is configured** (v3). Auto routing picks the cheapest model that fits the question (v4). System prompt uses Anthropic prompt caching (v4).
- **Fitness tab:** Macro tracking (calories/protein/carbs/fat) and workout logging with templates.
- **Settings:** AI provider config with model picker for both Claude and OpenAI (v4 — Auto / Opus 4.6 / Sonnet 4.6 / Haiku 4.5 for Claude; Auto / GPT-4.1 / GPT-4o / GPT-4.1 mini / GPT-4o mini for OpenAI), Google Calendar OAuth, theme toggle, Export Data with `lastExportAt` stamp shown (v3), Reset, build tag at the bottom (v3).

**PWA support:** `manifest.webmanifest` (icons trimmed to PNG-only with `purpose:"any"` after v3 — iOS ignored the SVG icons anyway), `sw.js` service worker with cache name tied to `BUILD` constant so every release self-invalidates (v3), icons (`el-icon.svg`, `el-icon-180.png`, `el-icon-192.png`, `el-icon-512.png`).

**Integrity tooling (v3):**
- `scripts/check-integrity.sh` — fails if `index.html` is under 5,500 lines, doesn't end with `</html>`, or has a brace imbalance > 2.
- `scripts/pre-commit-hook.sh` — local pre-commit hook source; install once via `Copy-Item scripts\pre-commit-hook.sh .git\hooks\pre-commit -Force` (or `bash scripts/install-hooks.sh` on a system with bash on PATH).
- `.github/workflows/integrity.yml` — runs the same check on every push/PR as a server-side safety net. The truncation problem can no longer reach the repo.

---

## File Integrity Rules — Non-Negotiable

**The file has been accidentally truncated multiple times.** As of v3 there is automated enforcement:

- Local **pre-commit hook** at `.git/hooks/pre-commit` runs `scripts/check-integrity.sh` and blocks any commit where `index.html` fails the checks. Install once via PowerShell: `Copy-Item scripts\pre-commit-hook.sh .git\hooks\pre-commit -Force`.
- **GitHub Actions workflow** `.github/workflows/integrity.yml` runs the same check on every push and PR as a server-side safety net.
- Manual checks if needed:
  ```bash
  tail -10 index.html    # must end with </html>
  wc -l index.html       # must be 5500+ lines (v4 is ~6246)
  ```

The file must end in this exact sequence:
1. `window.El = El;`
2. `window.ElDebug = ...`
3. `document.addEventListener('DOMContentLoaded', ...)` — the boot check
4. Service worker registration block
5. `</script></body></html>`

If any of these are missing, **do not commit**. Restore with `git checkout -- index.html` and try again with smaller edits. When making large edits, prefer atomic Python `apply_patches.py`-style scripts over multiple Edit-tool calls — the truncation has historically happened during multi-edit sequences.

---

## What Has Already Been Fixed (Don't Redo or Revert)

| Fix | Commit | Notes |
|-----|--------|-------|
| Recurring expenses appear on calendar | `c25dfca` | `renderCalendar()` called after save |
| Income modal no longer shows "recurring expense" label | `c25dfca` | Modal resets to clean state on open |
| Modal swipe-to-dismiss works anywhere (not just top 56px) | `c25dfca` | Rewrote `initModalSwipe()` |
| AI auto-action system | `c25dfca` | `[[EL_ACTION:{...}]]` blocks trigger app updates |
| AI conversation history persists across sessions | Prior session | Saved to `d.aiHistory`, loaded on `init()` |
| Front page stuck bug (onboarding every refresh) | `e54b98d7` baseline | DOMContentLoaded boot check |
| File truncation recovery | Multiple | File was cut off at ~5000 lines twice |
| Budget default $0 for fresh users | `90009f8` | Was hardcoded $2,250 |
| Voice/mic on Capture card | `90009f8` | Mirrors AI chat mic via `toggleCaptureSpeech()` |
| GCal OAuth flow | `90009f8` | Implicit flow, token saved to `d.settings.gcalToken` |
| AI batch action parsing | `90009f8` | Multiple `[[EL_ACTION]]` blocks per response |
| Glassmorphism UI redesign | `3911d8b` | Glass cards, gradient buttons, ambient orbs, frosted nav |
| Capture mic visibility | `bb99c23` | Check moved into `render.home()` after DOM is ready |
| `El.ui.showToast` helper | `bb99c23` | Was called but never defined |
| GCal uses OAuth token for API calls | `bb99c23` | Falls back to template URL if no token |
| Light mode glass variables | `bb99c23` | Overrides added to `body.light-mode` |
| Reduced motion for ambient orbs | `bb99c23` | Wrapped in `@media (prefers-reduced-motion)` |
| Post-capture feedback toasts | `bb99c23` | "Added to calendar ✓" etc. after AI action |
| Financial Health score rewrite | `ec1093e` (v3) | 5-component weighted: emergency fund / DTI / net-worth / budget / 30-day trend. Tap card opens breakdown modal. Returns `null` (renders `—`) when no data exists. |
| El AI tab gating | `ec1093e` (v3) | Bottom-nav AI button hidden until `El.ai.isConfigured()` true. Capture card shows "Add an API key" banner when not configured. |
| Job Loss Runway auto-fill | `ec1093e` (v3) | Pre-fills monthly expenses from avg of last 3 months of expense transactions, falls back to recurring sum / allocations / 70% of income. |
| Pre-commit + GitHub Action integrity check | `ec1093e` (v3) | `scripts/check-integrity.sh` enforces line count and `</html>` ending. |
| SW cache tied to BUILD | `ec1093e` (v3) | `sw.js` cache name uses `BUILD` constant; bump per release auto-invalidates. |
| `window.EL_BUILD` build tag in Settings | `ec1093e` (v3) | Visible at the bottom of Settings — confirms which version the PWA is actually serving. |
| Backup reminder banner | `ec1093e` (v3) | Home banner after 30 days without `lastExportAt`, dismisses on export. |
| `netWorthHistory` cap raised | `ec1093e` (v3) | 90 entries → 1100 (~3 years) for long-term trend charting. |
| `escapeHtml` on AI confirmation cards | `ec1093e` (v3) | Closes the only realistic XSS vector (model-generated text). |
| Manifest icon trim | `ec1093e` (v3) | Dropped SVG entries from `icons[]`; kept PNG-only with `purpose:"any"`. |
| Capture mic always visible | `ec1093e` (v3) | `toggleCaptureSpeech()` shows a clear toast when WebSpeech isn't available (iOS PWA standalone) instead of silently hiding. |
| `set_budget` AI action | (v4) | New EL_ACTION type — chat can update or create category allocations. |
| OK to Buy What If card | (v4) | Instant local verdict (Bad idea / Tight / Manageable / Within means) + optional "Ask El for deeper analysis" button. Same structured response shape works in chat. |
| Auto model routing | (v4) | `pickClaudeModel()` / `pickOpenAiModel()` route based on message length and intent. Defaults to "auto" for new users. |
| Anthropic prompt caching | (v4) | System prompt split into static (cached, ~10% cost on repeat) + dynamic blocks. Combined with data caps, drops typical second-message input cost by 70-90%. |
| Latest model support | (v4) | Claude Opus 4.6, Sonnet 4.6, Haiku 4.5; OpenAI GPT-4.1 / 4o / 4.1-mini / 4o-mini all selectable. |

---

## Known Constraints

**No backend, no secrets in the repo.** The Google Calendar OAuth client ID is NOT committed. The settings UI has a "Save Client ID" step where Eddie enters his own client ID. Any AI suggesting to hardcode an OAuth client ID or add a backend should be redirected.

**Single-file constraint is intentional.** Don't suggest splitting into modules yet. The testing log notes this as a future consideration after behavior stabilizes.

**GitHub Pages deployment.** The app is served as a static site. No server-side redirects, no `.htaccess`. The service worker handles offline — don't complicate it.

**Git workflow:** The bash sandbox (Claude's Linux environment) cannot push to GitHub due to a proxy block. Eddie pushes manually from PowerShell. The `.git/HEAD.lock` and `.git/index.lock` files are frequently left stale — always `Remove-Item` them before committing.

---

## Collaboration Model

**Claude (Dispatch/Cowork):** Bug fixes, architecture decisions, reviewing Codex findings, writing this kind of context doc, coordinating deploys.

**Codex:** Feature additions, UI polish, performance improvements, detailed code analysis.

**Handoff protocol:**
1. Whoever finishes work updates `docs/PERSONAL_TESTING_LOG.md`
2. The other AI reads this file and the testing log before starting
3. Always commit Codex's work before Claude starts (and vice versa) — parallel edits to `index.html` without syncing cause conflicts
4. Never use `git add .` or `git add -A` — only `git add index.html` (or specific files) to avoid committing temp files

---

## Planned Next Work

Done items pruned. Still on the list:

- **Code structure:** Module splitting is future work — stabilize behavior first.
- **Finance clarity engine:** OK-to-Buy was the first piece (v4). Remaining: scenario comparison, life-goal projections, retirement readiness.
- **Inline-card result display:** Toasts cover the basics; an inline confirmation card could be richer UX for some captures.
- **Maskable-safe icon:** The manifest currently lists PNG icons with `purpose:"any"`. A dedicated maskable PNG with an 80% safe zone would render cleaner on Android.

Already shipped (don't re-suggest):
- Export/Import (v0) + 30-day backup reminder + `lastExportAt` stamp (v3)
- Auto model routing across providers (v4) and Anthropic prompt caching (v4)
- `set_budget` chat action (v4) + tappable per-category budget editing + "Reset all" button (v5)
- OK-to-Buy What If card with optional AI deep-dive (v4)
- Pre-commit + GitHub Actions integrity check (v3)
- Financial Health 5-component weighted score with breakdown modal (v3)
- El AI tab gating + Home capture API-key banner (v3)
- Job Loss Runway auto-fill from transaction history (v3)
