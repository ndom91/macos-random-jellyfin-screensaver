# MacOS Screensaver - Random Jellyfin media

This is a macOS screensaver application that picks a random unwatched Jellyfin
movie or TV episode and plays it when the screensaver is triggered. Playback is
muted by default, starts at the 2-minute mark, and briefly shows the selected
title in the lower-left corner.

## Documentation

1. Read the latest ./docs/*.md documents to get up to speed on the project
2. When writing a new document to ./docs/*.md, always prefix the document file
   name with the date of when it was authored. For example,
   `2025-05-25-initial-plan.md` for the initial project plan.

## Development

The project is intentionally small and can be developed without opening Xcode.

Typical workflow:

```text
edit Swift files
make build
make install
open -a ScreenSaverEngine
```

For a clean rebuild/install cycle, use:

```sh
make dev-install
```

Source layout:

```text
Resources/Info.plist
Sources/JellyfinRandomMovieScreensaverView.swift
Sources/ScreensaverSettings.swift
Sources/SettingsWindowController.swift
Sources/JellyfinClient.swift
Sources/JellyfinModels.swift
Sources/PlaybackURLBuilder.swift
Sources/VideoPlaybackController.swift
```

The implementation uses:

- `ScreenSaver.framework` for the `.saver` lifecycle.
- `AppKit` for the configuration sheet and title overlay.
- `URLSession` for Jellyfin API requests.
- `AVFoundation` / `AVPlayerLayer` for playback.

Playback implementation notes:

- The screensaver prefers AVPlayer-compatible Jellyfin items (`mp4`, `mov`, `m4a`, `m4v`).
- Playback URL priority starts with Jellyfin's `/Videos/{itemId}/stream.mp4` endpoint.
- The app intentionally does not call Jellyfin playback progress/session APIs, so it should not mark items as played or add Continue Watching entries.
- Normal buffering/ready/playing status is logged only. On-screen status should be reserved for the title overlay and actionable errors.

## Troubleshooting

If the screensaver is black, check logs:

```sh
command log show --last 5m --style compact --predicate 'eventMessage CONTAINS "JellyfinRandomMovieScreensaver" OR eventMessage CONTAINS "AMFI"'
```

Common issues:

- **Missing settings**: fill in base URL, API key, and user ID in Options.
- **404 from Jellyfin**: the user ID may be wrong. Use the ID from `/Users/{userId}/Items`.
- **AMFI or Gatekeeper errors**: rebuild and reinstall so the bundle is ad-hoc signed.
- **Unsupported media**: AVPlayer works best with MP4/MOV-compatible media. The screensaver prefers compatible items and requests Jellyfin's MP4 stream endpoint.

Modern macOS may show Wallpaper settings labels while custom `.saver` modules are launched through the legacy screensaver host. If logs mention `Setting module “JellyfinRandomMovieScreensaver”`, the custom module is being loaded.

## Distribution

Local builds do not require a paid Apple Developer account or notarization.

Public distribution should use:

- Apple Developer Program membership.
- Developer ID Application certificate.
- Code signing.
- Notarization.
- Stapling.

Unsigned or unnotarized shared builds may trigger Gatekeeper warnings or require manual security overrides.
