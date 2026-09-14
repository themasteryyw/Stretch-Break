# StretchBreak

Reminds you to stand up every hour and do a non-repeating 3–5 minute YouTube
stretch video (or a built-in offline routine) covering your **whole body** —
lower back, hips, hamstrings, neck & shoulders, upper back, chest, wrists,
quads, calves & ankles. One tap rates how it went; discomfort is logged
before/after and charted as a trend over time.

A solo side project by [Sharon Yang](https://github.com/themasteryyw), a QA
automation engineer — built with the same test-first discipline used
professionally: every scheduling, recommendation, and localization rule below
is backed by an XCTest case (see [Testing](#testing)).

**Tech stack**: Swift, SwiftUI, SwiftData, WKWebView (YouTube iframe API),
XCTest — no backend, no third-party packages.

- iOS 17+ / Xcode 15+
- SwiftUI + SwiftData, no backend, no third-party packages
- Reminders are local notifications — no network required, nothing is uploaded
- Fully bilingual: **English** and **Traditional Chinese (繁體中文)**, switchable
  anytime in Settings — no restart needed

---

## Building

### Option A — XcodeGen (recommended)

```bash
brew install xcodegen
cd ~/Documents/StretchBreak
xcodegen generate
open StretchBreak.xcodeproj
```

In Xcode:
1. Select target `StretchBreak` → Signing & Capabilities → pick your Team (a
   personal Apple ID works too).
2. Connect an iPhone, select it as the run destination, press ▶︎.
3. First launch on the phone: Settings → General → VPN & Device Management →
   trust your developer certificate.
4. Complete onboarding in the app and allow notifications.

> A free Apple ID's sideload certificate expires after 7 days and needs a
> re-run from Xcode; also capped at 3 sideloaded apps at a time. For
> longer-term use, distribute via TestFlight (requires a paid developer account).

### Option B — Manual project setup (no XcodeGen)

1. Xcode → File → New → Project → iOS → App.
   - Product Name: `StretchBreak`
   - Interface: SwiftUI, Language: Swift, Storage: None
   - Minimum deployment: iOS 17.0
2. Delete the template's `ContentView.swift` and `StretchBreakApp.swift`.
3. Drag everything from this folder's `Sources/` into the project (check
   "Copy items if needed" and add to target):
   `App.swift` `Models.swift` `Services.swift` `Localization.swift`
   `Views.swift` `YouTubePlayerView.swift` `PlayerWarmer.swift`
   `VideoStore.swift` `routine.json`
4. Target → Info → add a String key `YTAPIKey` (leave blank, or fill in a key —
   see below).
5. Run on your phone.

---

## Language

The app ships with two complete translations — English and Traditional
Chinese — covering every screen, all 20+ notification messages, and the
offline routine. Switch freely at any time from **Settings → Language**;
the whole UI updates immediately, no restart required. It defaults to
Traditional Chinese on devices with a Chinese system language, English
otherwise.

Adding a language: extend `AppLanguage` and add a translation column to every
entry in the `strings` dictionary in `Sources/Localization.swift`, plus a
matching key in each `routine.json` move's `name`/`cue` objects.
`LocalizationTests.swift` fails the build if any key is missing a translation
in a supported language, so the compiler/test suite catches gaps early.

## YouTube video sources

Three modes, auto-detected:

| Setup | Behavior |
|---|---|
| **`YTAPIKey` set** | Rotates YouTube search queries across every body area (piriformis, hip flexors, hamstrings, thoracic spine, neck, shoulders, chest, wrists/forearms, quads, calves/ankles…), fetches embeddable 4–20 min videos, excludes recently played → effectively non-repeating, unlimited content |
| **YouTube link(s) pasted in Settings** | Builds a personal playlist, merged with the source above |
| **Neither** | Falls back to the built-in timed routine (`routine.json`, 11 moves, ~5 min, full body, works offline) |

**Getting a key**: Google Cloud Console → create a project → enable
*YouTube Data API v3* → create an API key.
Set it via `YT_API_KEY` in `.env.local` (gitignored — see
`.env.local.example`), then run `export $(cat .env.local | xargs) &&
xcodegen generate`; or, with Option B, paste it directly into the target's
Info `YTAPIKey` field. Free quota is 10,000 units/day; this app uses well
under 1% of that per day.

**Prefetching (two layers)**:
- `VideoStore`: searches + verifies a video pool in the background on launch
  and foreground, cached in memory and on disk (`video_cache.json`, 6h TTL).
- `PlayerWarmer`: keeps a hidden `WKWebView` around and, on app open / after
  each session / whenever the pool updates, pre-builds the YouTube player
  (iframe API + player object) for the *next* likely video. Tapping "Stretch
  now" hands that warmed webview straight to the session when it's a hit →
  playback starts almost instantly instead of waiting the usual ~2–3s for
  player init. A reroll or a miss falls back to a normal fresh load.

**iOS Simulator plays audio only, no picture moves**: this is a Simulator
limitation in `WKWebView` media decoding (you'll see a `WebKit Media
Playback` assertion failure in the log) — not an app bug. **A real iPhone
plays normally.**

**Reliability**:
- The player loads the real `youtube.com/embed/<id>` URL directly (not
  `loadHTMLString` + `baseURL` — that gives `WKWebView` the wrong origin, so
  the iframe API handshake fails and every video errors out).
- After search, a second `videos.list` call keeps only videos with
  `status.embeddable=true` and `public` (search's own `videoEmbeddable`
  filter is unreliable) — this kills the 150/152 errors at the source.
- Since a direct embed load has no reliable JS lifecycle events, a timer set
  to the video's real duration auto-advances to rating (capped at 7 min).
  Network-layer failures are caught via the navigation delegate → the app
  moves to the next video; 4 consecutive failures fall back to the offline
  routine.
- The playback screen has a manual "Next video" control.

**Discomfort check-in**: each session rotates through a different body area
(lower back → left hip → right hip → hamstrings → neck & shoulders →
piriformis → upper back → chest → wrists & forearms → quads → calves &
ankles), never repeating the same area twice in a row; recorded in
`SessionLog.focusArea`.

**Following up on soreness**: if a body area scored ≥ 7 last time (and that
stretch wasn't rated 😖, and it was < 24h ago), the next session opens by
asking "Last time your X was 7/10 — same stretch again?" → Repeat it / Try
something new. Choosing Repeat also locks the check-in to that sore area
instead of the normal rotation.

---

## Scheduling details

- iOS allows at most 64 pending local notifications at a time. The app
  reschedules the next 8 days (capped at 60) every time it enters the
  foreground.
- Notification actions: `Stretch now` (opens the app straight into the
  stretch flow) / `Snooze 5 min` / `Not today` (cancels the rest of today's
  reminders). Action titles and all 22 rotating message variants are
  localized and re-registered whenever the language changes.
- Crossing midnight, changing the interval, or daylight saving all trigger
  an automatic reschedule the next time the app opens.

## Files

```
project.yml                 XcodeGen config
.env.local.example          Template for the YT_API_KEY env var (see .env.local, gitignored)
Sources/
  App.swift                 App entry point, notification delegate
  Models.swift              SwiftData models + enums (BodyArea, FocusArea, …)
  Localization.swift        AppLanguage + the full EN/繁中 string catalog (t(_:))
  Services.swift            Notification scheduling, YouTube search, recommender, stats
  YouTubePlayerView.swift   WKWebView + iframe API player
  PlayerWarmer.swift        Pre-warms the next likely video's player
  VideoStore.swift          Background search + on-disk video cache
  Views.swift               All screens (home / stretch flow / rating / pain / history / settings / onboarding)
  routine.json              Offline routine — 11 moves, bilingual name/cue, full body
  Info.plist                Contains the YTAPIKey field
```

## Testing

`Tests/` has a `StretchBreakTests` target (`@testable import`, host = App).

```bash
xcodebuild test -scheme StretchBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
or press `⌘U` in Xcode.

- **Pure unit tests** (fast, no network): `ParsingTests` (YouTube URL parsing,
  ISO8601 duration, API JSON decoding), `RecommenderTests` (no repeats within
  the recent window, excludes broken/disliked videos, prefers unseen),
  `StatsTests` (streak incl. one freeze day, today's count, weekly minutes),
  `PolicyTests` (body-area rotation never repeats consecutively, the ≥7 pain
  follow-up condition), `LocalizationTests` (every key translated in both
  languages, language switching actually changes output, template
  formatting, whole-body coverage in `BodyArea`/`FocusArea`, the
  notification prompt bank has ≥ 20 unique messages per language, every
  offline routine move has both a `en` and `zh` name/cue).
- **`YouTubeLiveTests`** (needs network + `YTAPIKey`, auto-skips without one):
  actually calls the YouTube API via `YouTubeProvider.pool()`, asserts it
  returns ≥ 3 videos, all embeddable, reasonable length, unique ids; then
  loads the first video's `embed` page in a real `WKWebView` to confirm it
  actually loads. This is the real "does YouTube integration work" check.

## App icon & theme

Settings → Appearance has 3 presets — one tap changes the accent color *and*
the app icon together:

| Theme | Color | Source |
|---|---|---|
| Teal (default) | `#11B6AB`-ish teal gradient | original app color |
| Peach Fuzz | `#FFBE98` | Pantone 13-1023, Color of the Year 2024 |
| Mocha Mousse | `#A47764` | Pantone 17-1230, Color of the Year 2025 |

`Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` is the primary
(teal) icon; `Sources/AltIcons/AppIcon-{Pink,Latte}@{2x,3x}.png` are the
alternate icons, switched at runtime via
`UIApplication.setAlternateIconName`. All of them — the same white
stand-and-stretch "Reach" figure on a diagonal gradient — are generated by
one script: edit `tools/make_icon.py` (pure Pillow, `pip3 install Pillow`,
color constants at the bottom of the file) then run
`python3 tools/make_icon.py` to regenerate everything at once, then rebuild.

## Not yet done (v2)

Apple Watch, HealthKit writes, cross-device sync, dark / tinted icon
variants, social features, additional languages beyond English and
Traditional Chinese.
