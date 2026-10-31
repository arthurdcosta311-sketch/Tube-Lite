# Youtube adless lite

A lightweight, ad-blocking YouTube launcher for iOS.

Youtube adless lite opens straight into YouTube in a built-in web view and keeps it free of ads:

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

## Notes

- Ad blocking is best-effort: YouTube changes constantly, so a few ads may slip through.
- The audio background mode and the ad-blocking script target the mobile layout by default; desktop layout is an opt-in switch in settings.
- Picture-in-picture is shitty, I know — but I'm too lazy to fix it, so don't ask.

## License

MIT — see [LICENSE](LICENSE).
