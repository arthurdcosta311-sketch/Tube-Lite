# Tube Lite

A lightweight, ad-blocking YouTube launcher for iOS.

Tube Lite opens straight into YouTube in a built-in web view and keeps it free of ads:

- **Content-blocking rules** that cancel requests to known ad and tracking networks and YouTube's ad endpoints
- **CSS + injected script** that hides ad slots in the feed and player, and auto-clicks "Skip" the moment it's clickable
- **Request filtering** as a second layer, which also counts blocked ads (shown on the shield badge in the toolbar)

## Features

- Floating glass toolbar: back, forward, reload, home, blocked-ads badge
- YouTube search with direct pasted links (`youtube.com`, `youtu.be`)
- Quick destinations: Home, Shorts, Subscriptions, Trending, History, Watch later
- Picture-in-picture button (blocks YouTube's inline-forcing behavior)
- Movable toolbar icons: long-press and drag any button onto another to reorder them, including moving icons between the top and bottom bars
- Background playback: audio keeps streaming when you leave the app
- Ad blocking toggle and desktop/mobile layout switch in settings
- Blocked-ad counter that persists across launches

## Building

Open `Tube Lite.xcodeproj` in Xcode and run, or build from the command line:

```sh
xcodebuild -project "Tube Lite.xcodeproj" -scheme "Tube Lite" build
```

### Unsigned .ipa

For self-signing (Sideloadly, AltStore, codesign):

```sh
./make-ipa.sh
# → build/Tube Lite-<version>.ipa
```

Or let GitHub Actions build it: push to `main` (or run the **Build unsigned ipa**
workflow manually from the Actions tab), then download the versioned
`Tube-Lite-<version>-ipa` artifact from the finished run and sign it yourself.

The app shows its own version in the settings sheet (tap the shield badge).

## Notes

- Ad blocking is best-effort: YouTube changes constantly, so a few ads may slip through.
- The audio background mode and the ad-blocking script target the mobile layout by default; desktop layout is an opt-in switch in settings.

## License

MIT — see [LICENSE](LICENSE).
