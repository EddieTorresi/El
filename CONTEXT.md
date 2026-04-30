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
- `El.state` — manages localStorage: `load()`, `save()`, `get()`, `set()`, `defaults()`, `migrate()`
- `El.ai` — the AI assistant: `init()`, `send()`, `respond()`, `saveHistory()`, `clear()`, `quickCapture()`
- `El.render` — renders each screen: `home()`, `finance()`, `schedule()`, `fitness()`, `ai()`, `settings()`
- `El.nav` — tab navigation
- `El.finance`, `El.schedule`, `El.fitness` — feature modules
- `El.ui` — UI helpers including `showToast(msg, type, duration)`, `closeModal()`, `openModal()`

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
[[EL_ACTION:{"type":"add_income","name":"Job","amount":3000,"frequency":"monthly"}]]
```
Multiple action blocks per response are supported and expected. `extractElActions()` parses all of them; `handleElAction()` executes each. The system prompt explicitly tells Claude to emit multiple blocks when the user mentions multiple items.

**AI history persistence:**  
Conversation history is saved to `d.aiHistory` (last 40 messages) via `El.ai.saveHistory()`. On `init()`, saved history is reloaded so conversations persist across sessions.

---

## Current Features (as of 2026-04-30)

- **Home screen:** Capture card with natural language input + voice/mic button, daily command center (today/tomorrow/next action), greeting with financial summary
- **Finance tab:** Transactions, recurring expenses and income, debts, savings goals, net worth tracking, budget categories
- **Schedule tab:** Calendar view with recurring item dots, event management, Google Calendar OAuth integration
- **El AI tab:** Full chat assistant with voice input, history persistence, and auto-action parsing. Suggestions chips at top.
- **Fitness tab:** Macro tracking (calories/protein/carbs/fat) and workout logging with templates
- **Settings:** AI provider config (built-in / Claude API / OpenAI), Google Calendar OAuth, theme toggle, export/import

**PWA support:** `manifest.webmanifest`, `sw.js` service worker, icons (`el-icon.svg`, `el-icon-180.png`, `el-icon-192.png`, `el-icon-512.png`)

---

## File Integrity Rules — Non-Negotiable

**The file has been accidentally truncated multiple times. Every commit must pass these checks:**

```bash
tail -10 index.html    # must end with </html>
wc -l index.html       # must be 5200+ lines (currently ~5586)
```

The file must end in this exact sequence:
1. `window.El = El;`
2. `window.ElDebug = ...`
3. `document.addEventListener('DOMContentLoaded', ...)` — the boot check
4. Service worker registration block
5. `</script></body></html>`

If any of these are missing, **do not commit**. Restore with `git checkout index.html` and try again with smaller edits.

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

## Planned Next Work (from testing log)

- **Data safety:** Import/export, backup reminders before expanding to other testers
- **Code structure:** Module splitting is future work — stabilize behavior first  
- **Finance clarity engine:** Turn What If tools into a conversational decision engine for debt, housing, investing, major life choices
- **Post-capture result display:** Show "Added to Calendar", "Logged expense" etc. inline (now done via toast, but inline card version may be better UX)
