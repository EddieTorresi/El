# El Personal Testing Log

Last updated: 2026-04-29 (build v5)

## Current Stage

El is still in personal iPhone testing through GitHub Pages. The near-term goal is not to make it feel like a finished public product yet. The goal is to make it useful enough that it becomes the first place to capture calendar items, money decisions, reminders, meals, workouts, and loose thoughts before they get forgotten.

## Product Direction

El should give clarity to people who are unorganized, overwhelmed, or normally bad planners. The product center is:

1. Capture first.
2. Organize second.
3. Advise third.

Finance stays a major pillar of the app. The long-term opportunity is not only budget tracking, but decision clarity: whether to buy, finance, save, invest, wait, or walk away. Example target question: "I make 150k, have 5k saved, and want an 80k car with 70k debt. How bad is that really, and what would happen if I invested instead?"

## Changes Logged For This Pass

### 1. Capture-first assistant entry

- Added a prominent Capture card to the Home screen.
- The Home capture box routes entries into El AI so existing confirmation cards are reused before anything is saved.
- Added quick personal-testing chips for common capture flows:
  - calendar item
  - expense
  - bill reminder
- Added a simple event parser for natural calendar entries like:
  - "dentist next Thursday at 2pm"
  - "pay Chase on the 15th"
  - "call mom tomorrow"

### 2. Daily command center

- Added a Daily Command Center to Home.
- It summarizes:
  - Today
  - Tomorrow
  - One next useful action
- It includes manual schedule items, recurring bills, and lightweight check-in prompts such as missing money or food logs.

### 4. GitHub Pages and iPhone PWA polish

- Replaced the inline data manifest with `manifest.webmanifest`.
- Added `el-icon.svg` and PNG icons for iPhone/Home Screen use.
- Added a GitHub Pages friendly `sw.js` service worker with relative scope.
- Changed service worker registration to `./sw.js` so it works better under a GitHub Pages project path.
- Added local date helpers so "today" and monthly views do not drift because of UTC time conversion on iPhone.

## Changes Logged For Build v3 (commit ec1093e — 2026-04-29)

### Financial Health, rewritten

Old score was meaningless — a fresh user with $0 of everything got 80/100, and a user with $4,800 income, $2,400 savings and $22k debt also got 80/100, because the formula ignored total debt. New score is a weighted average of five components: Emergency Fund (25%), Debt-to-Income (25%), Net Worth health (20%), Budget Adherence (15%), 30-Day Trend (15%). When there's no data the score is shown as `—` instead of a fake number. Tap the Health card on Home to open a breakdown modal showing each component's score, weight, value, and a one-line hint.

### El AI tab is gated behind an API key

The bottom nav hides the El AI button until you've selected Claude or ChatGPT and saved a key in Settings. Without a key the Home capture card shows a tappable "Add an API key to unlock smart capture" banner. Removes the dead-end that the old built-in keyword-matcher created.

### Other v3 changes

- Pre-commit hook + GitHub Actions check enforce that `index.html` ends with `</html>` and is at least 5,500 lines. Truncation can no longer reach the repo.
- Service-worker cache name is now tied to a `BUILD` constant; bump per release auto-invalidates the SW cache. The same string renders at the bottom of Settings as a "build YYYY-MM-DD-..." tag so I can tell on the phone which version is actually serving.
- 30-day backup reminder card on Home, dismisses for 30 days when I export. `lastExportAt` shown in Settings.
- Job Loss Runway pre-fills monthly expenses from the avg of my last 3 months of expense transactions (falls back to recurring sum, allocations, 70% of income).
- `netWorthHistory` cap raised from 90 days to ~3 years, so the long-term trend chart will actually have data.
- Capture mic always visible — toast explains the limitation when iOS PWA standalone mode hides the WebSpeech API.
- Manifest icon entries trimmed to PNG-only (iOS ignored SVGs anyway, dropped the `maskable` flag).
- AI confirmation cards now `escapeHtml` model-supplied text — the only realistic XSS path.
- File integrity guard caught its first save during this pass.

## Changes Logged For Build v4 (2026-04-29)

### Token-usage optimization

The system prompt is now split into a static block (action schemas, format rules, role) and a dynamic block (live data snapshot). Anthropic calls send the static block with `cache_control: { type: 'ephemeral' }` so it's cached and charged at ~10% of normal on repeat turns within ~5 minutes. The static block was also compressed about 40%. The data block is now capped: top 10 debts/savings, last 60 monthly transactions, max 10 upcoming events. Typical second-message input cost should drop 70-90%.

### Auto model routing

Both Claude and OpenAI pickers now have an "Auto" option (default) that routes:
- Short capture-style messages → Haiku 4.5 / GPT-4o-mini (cheapest)
- Heavy questions ("ok to buy", "plan", "strategy", >400 chars) → Opus 4.6 / GPT-4.1 (best reasoning)
- Everything in the middle → Sonnet 4.6 / GPT-4o

Manual override still works — pin a specific model in Settings if you want.

### `set_budget` AI action

Tell El "set my food budget to 400" or "make my entertainment budget 80 a month" and you get a confirmation card showing old → new. Creates the category if it doesn't exist.

### OK to Buy?

New Finance → What If? card. Type item + price, optionally toggle Financed (down payment / months / APR). As you type, instant local verdict (Bad idea / Tight / Manageable / Within means) with score + color-coded flags grounded in your data — payment as % of income, % of savings consumed, DTI before/after, emergency runway change, total interest. No API call. Below the verdict, an "Ask El for deeper analysis" button (only shown when a key is configured) sends a focused prompt to your model and renders the structured response inline. Auto routes the question to Opus 4.6 / GPT-4.1 because it matches the heavy-question pattern. Same shape works in chat: ask "should I buy a 150k car?" and you get the same Verdict / Why / Before you buy / Best way to afford it response.

## Changes Logged For Build v5 (2026-04-29)

### Tappable per-category budget editing

Every category row on the Budget tab is now tappable. Tap to open a modal pre-filled with the current name / icon / monthly budget — change it and Save. Add a Delete button if it's an existing category. Categories that haven't had a budget set show "tap to set budget" instead of "0 / 0".

### "Reset all" button

When any allocation is non-zero, the Categories card header shows a small Reset all link in red that confirms then sets every category's monthly budget back to $0. This is the cleanup for the legacy demo carryover (1200 + 400 + 300 + 150 + 100 + 100 = $2,250) that persisted after demo mode was used and there was no UI to clear it.

## Next Conversations

### Code structure

The single-file prototype still works, but finance, AI, schedule, and fitness will become easier to evolve once separated. Picking this up after the next round of feature stabilization.

### Finance clarity engine — beyond OK-to-Buy

OK-to-Buy was the first piece. Remaining: scenario comparison (compare two purchases or two payoff strategies side-by-side), retirement-readiness projections, life-goal projections (kids, house, sabbatical), early-retirement runway.

### Sharing with friends/family

Before letting anyone else use the app, address: server-side proxy for AI calls so they don't have to bring their own API keys, encrypted at-rest storage for `aiApiKey` and `gcalToken`, optional account/login. Out of scope for personal testing.
