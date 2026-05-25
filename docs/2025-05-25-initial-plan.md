# Initial Project Plan: Jellyfin Random Media Screensaver

## Goal

Build a macOS screensaver that plays a random unwatched Jellyfin media item when the screensaver starts. Playback should be muted by default, with a user-configurable option to enable sound.

## Key Decision

Use Swift, not TypeScript, for the first working version.

Although TypeScript is familiar, it is not a natural fit for a macOS `.saver` bundle. macOS screensavers are native plugin bundles loaded by the system and built around `ScreenSaver.framework`. A TypeScript-based approach would require extra layers such as `WKWebView`, Node, or Electron-style wrapping, which would make the MVP more fragile.

The simplest viable architecture is:

```text
Swift .saver bundle
├─ ScreenSaver.framework lifecycle
├─ native AppKit configuration sheet
├─ ScreenSaverDefaults/UserDefaults persistence
├─ URLSession Jellyfin API requests
├─ JSONDecoder response parsing
└─ AVPlayerLayer fullscreen video playback
```

## macOS Screensaver Architecture

The screensaver should be implemented as a native `.saver` bundle installed at:

```text
~/Library/Screen Savers/JellyfinRandomMovieScreensaver.saver
```

The main class should subclass `ScreenSaverView` and implement the standard screensaver lifecycle:

```swift
init?(frame: NSRect, isPreview: Bool)
override func startAnimation()
override func stopAnimation()
override func animateOneFrame()
```

Playback should start in `startAnimation()` and stop/clean up in `stopAnimation()`.

## Settings UI

The screensaver can provide its own native configuration sheet inside macOS Screen Saver Settings. This does not require a separate app.

The screensaver should expose:

```swift
override var hasConfigureSheet: Bool { true }
override var configureSheet: NSWindow? { ... }
```

Use a small native AppKit form rather than a web UI or TypeScript UI.

Initial settings:

```text
Jellyfin Base URL
Jellyfin API Key
Jellyfin User ID
Media Type: Movies / TV Shows
Play Muted: true / false
```

The raw Jellyfin user ID should be included as an explicit field for the MVP. Deriving it automatically from an API key can be considered later.

Persist settings with screensaver-specific defaults:

```swift
ScreenSaverDefaults(forModuleWithName: "JellyfinRandomMovieScreensaver")
```

## Jellyfin API Shape

Known random-items endpoint:

```text
/Users/{userId}/Items?IncludeItemTypes=Movie&Recursive=true&SortBy=Random&Limit=100&Fields=ExternalUrls
```

Example full URL:

```text
https://watch.example.com/Users/{userId}/Items?IncludeItemTypes=Movie&Recursive=true&SortBy=Random&Limit=100&Fields=ExternalUrls
```

The response contains an `Items` array. Each item includes fields such as:

```text
Name
Id
Type
MediaType
Container
UserData.Played
UserData.PlayCount
UserData.PlaybackPositionTicks
```

For the MVP, select the first item where `UserData.Played == false`.

Detailed item endpoint:

```text
/Users/{userId}/Items/{mediaId}
```

This returns richer metadata, including `Path` and `MediaSources`. The `Path` value is server-local and should not be treated as a playable URL from the Mac unless that filesystem is mounted locally.

## Streaming URL Unknown

The main open technical question is the exact Jellyfin streaming URL to feed into `AVPlayer`.

Likely Jellyfin API patterns to test:

```text
/Videos/{itemId}/stream
/Videos/{itemId}/stream.mp4
/Videos/{itemId}/master.m3u8
```

With authentication supplied either as:

```text
X-Emby-Token: {apiKey}
```

or, if supported for the playback URL:

```text
?api_key={apiKey}
```

Apple-native playback is likely easiest with HLS:

```text
https://{baseUrl}/Videos/{itemId}/master.m3u8?api_key={apiKey}
```

Direct file streaming may also work if the container and codecs are supported by AVFoundation:

```text
https://{baseUrl}/Videos/{itemId}/stream?static=true&api_key={apiKey}
```

This should be validated with `curl`, Safari, or a tiny local AVPlayer test before building too much around it.

## Playback Decision

Use native `AVPlayer` and `AVPlayerLayer`.

Reasons:

- Integrates directly into the screensaver view.
- Supports fullscreen layer-backed playback.
- Simple mute/unmute control.
- Avoids managing external processes.
- Avoids WebView autoplay, CORS, and codec quirks.

Avoid using `ffmpeg` for playback. `ffmpeg` is useful for decoding/transcoding, but it does not render video into a macOS screensaver view by itself. Shelling out would add process-management complexity and likely higher CPU usage.

Avoid using `mpv` or another external player for the MVP. Managing an external window from a screensaver plugin is fragile.

## MVP Plan

1. Create a Swift `.saver` bundle target.
2. Implement a `ScreenSaverView` subclass.
3. Add a native AppKit configuration sheet.
4. Persist base URL, API key, user ID, media type, and muted setting.
5. Fetch random Jellyfin items using `URLSession`.
6. Filter/select an unwatched media item.
7. Build and validate a Jellyfin playback URL.
8. Play the media with `AVPlayerLayer`.
9. Stop and clean up playback when the screensaver exits.

## Later Improvements

- Automatically discover the Jellyfin user ID from credentials/API key.
- Add support for mixed media types.
- Improve TV show behavior by selecting episodes rather than series containers.
- Add fallback behavior when a selected item cannot be played.
- Show a poster/backdrop/title overlay while loading.
- Add logging or a small diagnostics view in the settings sheet.
- Add option to skip partially watched items or resume them.
- Add local cache of recently played screensaver items to avoid immediate repeats.
