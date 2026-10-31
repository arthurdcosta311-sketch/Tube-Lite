# Youtube adless lite

A lightweight, ad-blocking YouTube launcher for iOS.

**Project page:** https://arthurdcosta311-sketch.github.io/Tube-Lite/

Youtube adless lite opens straight into YouTube in a built-in web view and keeps it free of ads:

- **Content-blocking rules** that cancel requests to known ad and tracking networks and YouTube's ad endpoints
- **CSS + injected script** that hides ad slots in the feed and player, and auto-clicks "Skip" the moment it's clickable
- **Request filtering** as a second layer, which also counts blocked ads (shown on the shield badge in the toolbar)

## Features

- Minimal toolbar: a back button and a home button — nothing else
- Picture-in-picture and player controls via YouTube's own player
- Background playback: audio keeps streaming when you leave the app
- Ad blocking toggle and desktop/mobile layout switch in settings (tap the shield badge)
- Blocked-ad counter that persists across launches

## Building

Open `Youtube adless lite.xcodeproj` in Xcode and run, or build from the command line:

```sh
xcodebuild -project "Youtube adless lite.xcodeproj" -scheme "Youtube adless lite" build
```

### Unsigned .ipa

For self-signing (Sideloadly, AltStore, codesign):

```sh
./make-ipa.sh
# → build/Youtube Adless Lite-<version>.ipa
```

Or let GitHub Actions build it: push to `main` (or run the **Build unsigned ipa**
workflow manually from the Actions tab), then download the versioned
`Youtube-Adless-Lite-<version>-ipa` artifact from the finished run and sign it yourself.

The app shows its own version in the settings sheet (tap the shield badge).

## Project page

The landing page lives in `docs/index.html` and deploys to GitHub Pages via the
**Deploy project page** workflow. One-time setup on GitHub: repository
**Settings → Pages → Build and deployment → Source: GitHub Actions**. After that,
every push that touches `docs/` republishes the page at the URL above.

## Notes

- Ad blocking is best-effort: YouTube changes constantly, so a few ads may slip through.
- The audio background mode and the ad-blocking script target the mobile layout by default; desktop layout is an opt-in switch in settings.

## License

MIT — see [LICENSE](LICENSE).
