# El — Privacy Policy

**Effective:** May 11, 2026
**Last updated:** May 11, 2026
**Contact:** Eddie Torres &lt;eddietorresi@yahoo.com&gt;

This is the privacy policy for **El**, a personal finance, fitness, nutrition, and scheduling app for iPhone (App Store listing name: "El"). El is a personal project. There is no company behind it, no team, and no marketing department — just one person trying to build a useful app and ship it to friends and family.

The shortest possible version: **El does not run a server that stores your data**. Everything you enter lives on your phone. The few cases where data does leave your phone are listed below in plain English.

---

## What data the El app collects

El collects only what you type or import into the app on your device. That includes:

- **Finance** — transactions, budgets, debts, savings goals, recurring expenses, income sources, account balances, financial plan items.
- **Fitness** — workout templates, workout logs, exercise sets/reps/weights, fitness plan items.
- **Nutrition** — daily macro logs, food items, weight log entries, nutrition goals.
- **Schedule** — calendar events, reminders, appointment notes.
- **Apple Health (if you connect it)** — workouts, activity rings, steps, distance, flights climbed, sleep duration, body composition (weight, body fat, lean mass, BMI, height), vitals (resting heart rate, HRV, SpO₂, respiratory rate, body temperature), dietary intake, mindful minutes.
- **Connected fitness services (if you connect them)** — last 30 days of activities from Strava, Garmin, Oura, Fitbit, or any other provider you authorize.
- **AI chat history** — the messages you send to El AI and the replies you receive, kept on your phone so you can scroll back through past conversations.
- **App settings** — your theme preference, AI model choice, biometric lock toggle, and similar in-app preferences.

El **does not** collect: contact lists, photos (unless you tap "Scan Receipt" or "Scan Food Label", in which case the photo you select is used for that one scan and not retained), location, microphone audio outside of voice transcription requests you initiate, advertising identifiers, or any device telemetry.

## Where your data is stored

- **All app data stays on your phone**, in your device's encrypted app sandbox.
- **Sensitive credentials** (your Anthropic API key if you entered one, your transcription key if you entered one, OAuth tokens for Strava / Garmin / Oura / Fitbit / Google Calendar, and any client IDs / secrets you saved for those services) are stored in the **iOS Keychain**. The Keychain is encrypted by the operating system and protected by your device passcode and biometrics.
- **Non-sensitive app data** (transactions, workouts, settings, etc.) is stored in your device's normal app storage.
- **El does not sync, back up, or upload your data to any El-operated server.** There is no El cloud.

If you set up iCloud Backup on your iPhone, Apple's standard app-data backup may include El's data along with everything else on your phone. That backup is encrypted by Apple per their standard policies. El has no involvement in or control over Apple's iCloud Backup — that's between you and Apple.

## What leaves your phone, and when

There are exactly four kinds of network requests El can make. Each one is initiated by you, contains only the data needed for that single request, and never reuses your data for any other purpose.

### 1. El AI requests to Anthropic

When you tap into the **El AI** tab and ask a question, or use **Quick Capture** voice/text input, El sends:

- the text of your question,
- a short summary of related data (for example: this month's spending totals, recent workouts, today's macros — the specific summary depends on the question),
- and your saved Anthropic API key (or, if a future build deploys it, a built-in El AI service URL).

This goes to **Anthropic's Claude API** at `api.anthropic.com`. Anthropic's response comes back to your phone and is shown in the chat, then saved locally to your AI chat history. El does not log, store, or otherwise retain your prompts on any El-operated infrastructure (because there is no such infrastructure).

Anthropic's own data handling for API requests is governed by their published API terms and privacy policy. As of this writing, Anthropic states that API content is not used to train their models by default. Refer to https://www.anthropic.com/legal for the current policy.

### 2. Voice transcription to OpenAI Whisper

If you use the microphone button to dictate a Quick Capture or AI message, the audio you record is sent to **OpenAI's Whisper API** at `api.openai.com` for transcription. The text comes back to your phone and is dropped into the input field. The audio is not retained by El. OpenAI's own data handling for API requests is governed by their published terms.

### 3. Connected fitness services (only if you connect them)

If you connect Strava, Garmin, Oura, Fitbit, Polar, WHOOP, Withings, MapMyRun, or Google Fit:

- El opens the provider's official OAuth login page in your phone's browser.
- You log in to that provider directly. El never sees your provider password.
- The provider redirects back to El with an access token.
- That token is stored in your phone's Keychain.
- When you ask El to sync activities, El calls the provider's API directly (e.g. `www.strava.com`, `connectapi.garmin.com`, `api.ouraring.com`) using your token, and the activity data comes back to your phone.

Each provider has its own privacy policy that governs what they do with the data you've authorized El to read. Disconnecting a provider in **Settings → Activity Sync** removes the access token from your phone immediately.

### 4. Google Calendar (only if you connect it)

If you connect Google Calendar, the same OAuth flow applies. El sends scheduled events you tap to add (title, date, time, notes — only the event you chose to add) to `www.googleapis.com`. Google's privacy policy governs what they do with that data.

## What El does NOT do

- El does not show you ads.
- El does not sell, rent, or share your data with any third party for marketing.
- El does not contain any third-party analytics SDKs (no Firebase, no Amplitude, no Mixpanel, no Segment, no advertising SDKs).
- El does not track you across other apps or websites.
- El does not collect device fingerprints or advertising identifiers.
- El does not send crash reports anywhere by default. (Apple's TestFlight may collect crash reports per your TestFlight settings — that's between you and Apple.)
- El does not phone home for telemetry.

## Children

El is not directed to children under 13. If you are under 13, please do not use El.

## How to delete your data

You have several options, all of which work without contacting anyone:

- **Settings → Clear All Data** — wipes every transaction, workout, nutrition log, debt, savings goal, AI chat history entry, app preference, and every stored API key + connected-service token from your phone. This is permanent and cannot be undone.
- **Disconnect a single service** — Settings → Activity Sync → tap Disconnect on the provider's card. Removes that provider's access token. Saved client credentials stay (so you can reconnect) unless you also tap "Forget creds".
- **Delete the El app from your phone** — removes everything El stored on this device, including Keychain entries.

Because El stores no data outside your phone, there is no copy on a server for us to delete or for anyone to subpoena.

## Security

- Sensitive credentials are stored in the iOS Keychain, encrypted by the operating system.
- All API requests use HTTPS.
- The optional **Face ID / passcode** lock at app launch (Settings → Security) adds a biometric gate before El opens.
- El has been through several rounds of internal security review focused on prompt injection in AI requests, prototype pollution in spreadsheet imports, OAuth state validation, and deep-link allow-listing. The development notes for these reviews are public on the project's GitHub.

If you find a security issue, please email eddietorresi@yahoo.com so I can fix it.

## Changes to this policy

If this policy changes materially, the "Last updated" date at the top will change and the new version will be visible in this repository. Because El currently has no email collection or push notification system, I cannot proactively notify you of changes — please check this page if you're curious.

## Your rights under various privacy laws

El does not collect or process your personal data on any El-operated server. The legal frameworks that apply to data controllers and data processors (GDPR, CCPA, etc.) are written for organizations that hold your data on infrastructure they operate. El does not hold your data. Your rights are exercised by:

- Choosing not to install or use the app,
- Choosing not to connect any third-party service,
- Tapping **Clear All Data** in Settings, or
- Deleting the app.

For data that lives with the third-party services you've connected (Anthropic, OpenAI, Strava, Garmin, etc.), please refer to those companies' own privacy policies and exercise your rights with them directly.

## Contact

Questions, security concerns, or requests: **eddietorresi@yahoo.com**

This policy applies only to the El iOS app distributed via TestFlight and (when launched) the App Store. It does not apply to any other software written by Eddie Torres.
