# StretchBreak

A solo iOS side project by [Sharon Yang](https://github.com/themasteryyw).

Reminds you to stand up every hour and stretch — either a short YouTube
video matched to whatever body area you're currently sore in, or a
self-guided timer if you'd rather not wait on a video. Tracks your streak
and discomfort over time.

## Features

- **Two ways to stretch**: a ~5 min YouTube video, or a self-guided timer
  (drag to pick any length) that vibrates and chimes when it's done.
- **Whole-body targeting**: covers lower back, hips, hamstrings, neck &
  shoulders, upper back, chest, wrists, quads, and calves/ankles — rotates
  through a different area each session, and (when discomfort check-ins are
  on) picks a video that actually matches the area just asked about.
- **Discomfort tracking**: rate how a spot feels before/after each stretch;
  see the trend on the History tab. If an area scored high recently, the
  app offers to repeat the same stretch.
- **Quick like/dislike** on a video while it's playing, plus an emoji
  reaction after you finish.
- **Smart reminders**: local notifications only during the hours/days you
  set, with a rotating bank of varied messages — no network, nothing
  uploaded. Daily goal is worked out automatically from your reminder
  schedule.
- **Fully bilingual** — English and Traditional Chinese, switchable
  anytime in Settings, no restart needed.
- **Offline fallback**: no YouTube API key or no network → a built-in
  timed stretch routine, no internet required.
- Three theme colors (Morandi / Latte / Pink); the app icon stays fixed
  regardless of theme.

## Building

### Option A — XcodeGen (recommended)

```bash
brew install xcodegen
cd ~/Documents/StretchBreak
xcodegen generate
open StretchBreak.xcodeproj
```

In Xcode: pick your Team under Signing & Capabilities, connect your iPhone,
and run. First launch on the phone needs you to trust the developer
certificate under Settings → General → VPN & Device Management.

> A free Apple ID's sideload certificate expires after 7 days and needs a
> re-run from Xcode. For longer-term use, distribute via TestFlight.

### Option B — Manual project setup

Create a new SwiftUI iOS app in Xcode (min iOS 17), drag in everything
under `Sources/`, and add a `YTAPIKey` string key to the target's Info.

### YouTube video source (optional)

Without an API key, the app just uses the built-in offline routine. To
enable video search: get a YouTube Data API v3 key from Google Cloud
Console, put it in `YT_API_KEY` in `.env.local` (see
`.env.local.example`), then run `export $(cat .env.local | xargs) &&
xcodegen generate`.

## Testing

```bash
xcodebuild test -scheme StretchBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
or `⌘U` in Xcode. Covers scheduling, recommendation, localization, and app
logic; a separate `YouTubeLiveTests` suite exercises the real YouTube API
when a key is available (auto-skips otherwise).

## Not yet done (v2)

Apple Watch, HealthKit writes, cross-device sync, additional languages
beyond English and Traditional Chinese.
