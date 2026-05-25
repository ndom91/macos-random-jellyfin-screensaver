# Jellyfin Random Media Screensaver

A native macOS screensaver that plays a random unwatched Jellyfin movie or TV episode.

It fetches random unwatched items from your Jellyfin server, skips the first two minutes to avoid studio intros, briefly shows the selected title, and plays the video inside the macOS screensaver.

## Features

- Native macOS `.saver` bundle.
- Plays random unwatched Jellyfin media.
- Supports movies and TV episodes.
- Muted by default, with an option to enable audio.
- Starts playback at the 2-minute mark.
- Shows the selected title for the first 10 seconds.
- Native Screen Saver Options sheet for configuration.
- No Electron, Node, TypeScript, or external video player runtime.

## Requirements

- macOS with Screen Saver support.
- Jellyfin server reachable from the Mac.
- Jellyfin API key.
- Jellyfin user ID.
- Swift toolchain / Xcode Command Line Tools for building from source.

## Configuration

After installing, open macOS Screen Saver Settings, select **Jellyfin Random Media Screensaver**, and open **Options...**.

Settings:

- **Jellyfin Base URL**: your Jellyfin server URL, for example `https://watch.example.com`.
- **Jellyfin API Key**: a Jellyfin API key.
- **Jellyfin User ID**: the ID from Jellyfin API paths like `/Users/{userId}/Items`; this is not a media item ID.
- **Media Type**: movies or TV episodes.
- **Play muted**: enabled by default.

## Build And Install

Install Xcode Command Line Tools if needed:

```sh
xcode-select --install
```

Build and install for the current user:

```sh
make install
```

The screensaver is installed to:

```text
~/Library/Screen Savers/JellyfinRandomMovieScreensaver.saver
```

The build output is:

```text
build/Debug/JellyfinRandomMovieScreensaver.saver
```

Other useful commands:

```sh
make build
make print-bundle
make clean
```

The build ad-hoc signs the local `.saver` bundle with `codesign --sign -`. This is required on modern macOS so the system screensaver host can load the bundle locally.

## Testing

Launch the currently selected screensaver immediately:

```sh
open -a ScreenSaverEngine
```

View recent project logs:

```sh
command log show --last 2m --style compact --predicate 'eventMessage CONTAINS "JellyfinRandomMovieScreensaver"'
```

If audio keeps playing after exiting during development, kill the legacy screensaver host:

```sh
killall legacyScreenSaver ScreenSaverEngine
```

## Development

The project is intentionally small and can be developed without opening Xcode.

Typical workflow:

```text
edit Swift files
make build
make install
open -a ScreenSaverEngine
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

## Project Notes

Planning documents are kept in `docs/` for future reference.
