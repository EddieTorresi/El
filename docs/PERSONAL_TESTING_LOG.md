# El Personal Testing Log

Last updated: 2026-04-30

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

## Next Conversations

### Data safety and backups

Discuss import/export, backup reminders, and a safer path before friends and family testing. Local browser storage is fine for personal testing, but it needs stronger backup habits before other people rely on it.

### Code structure

Discuss when to split the one-file prototype into modules. The current single-file format is fast for testing, but finance, AI, schedule, and fitness will become easier to improve if separated after the main behavior stabilizes.

### Finance clarity engine

Keep finance as a major app pillar. Future work should turn What If tools into a conversational decision engine for debt, cars, housing, investing, emergency funds, and major life choices.
