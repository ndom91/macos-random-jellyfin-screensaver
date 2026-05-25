# Implementation Plan: Jellyfin Random Media Screensaver

## Objective

Build the first working version of a native macOS `.saver` bundle that fetches a random unwatched Jellyfin media item and plays it inside the screensaver view with `AVPlayerLayer`.

The MVP should prioritize a simple, installable, debuggable screensaver over broad media support or polished UI.

## Non-Goals For The MVP

- No TypeScript, Electron, Node, or WebView runtime.
- No external player process such as `ffmpeg`, `mpv`, or VLC.
- No automatic Jellyfin login flow.
- No automatic Jellyfin user discovery.
- No custom transcoding pipeline.
- No elaborate loading or metadata overlay.

## Target Architecture

```text
JellyfinRandomMovieScreensaver.saver
├─ Info.plist
├─ Swift ScreenSaverView subclass
├─ Settings model
├─ AppKit configuration sheet
├─ Jellyfin API client
├─ Jellyfin response models
├─ Playback URL builder
└─ AVPlayerLayer playback controller
```

## Proposed Source Layout

```text
JellyfinRandomMovieScreensaver.xcodeproj
JellyfinRandomMovieScreensaver/
├─ Info.plist
├─ JellyfinRandomMovieScreensaverView.swift
├─ ScreensaverSettings.swift
├─ SettingsWindowController.swift
├─ JellyfinClient.swift
├─ JellyfinModels.swift
├─ PlaybackURLBuilder.swift
└─ VideoPlaybackController.swift
```

This can be collapsed further during implementation if Xcode target setup is easier with fewer files. The important separation is between screensaver lifecycle, settings persistence, Jellyfin networking, and video playback.

## Build System

Use Xcode project scaffolding for the `.saver` bundle.

Reasons:

- Xcode understands bundle targets, signing, `Info.plist`, and framework linking.
- A `.saver` is a native plugin bundle, not a command-line Swift package product.
- Manual `swiftc` bundle assembly is possible but would add unnecessary build complexity.

Expected frameworks:

```text
ScreenSaver.framework
AppKit.framework
AVFoundation.framework
QuartzCore.framework
```

If available in the installed Xcode version, use the Screen Saver target template. If not, create a bundle target and configure the product extension as `.saver`.

## Bundle Identity

Working names:

```text
Product name: JellyfinRandomMovieScreensaver
Bundle name: JellyfinRandomMovieScreensaver.saver
Principal class: JellyfinRandomMovieScreensaverView
Defaults module name: JellyfinRandomMovieScreensaver
```

The principal class must be referenced from `Info.plist` so macOS can instantiate the screensaver view.

## Settings Model

Persist settings using:

```swift
ScreenSaverDefaults(forModuleWithName: "JellyfinRandomMovieScreensaver")
```

Initial fields:

```text
baseURL: String
apiKey: String
userID: String
mediaType: MediaType
muted: Bool
```

Initial media type enum:

```text
movies -> IncludeItemTypes=Movie
```

Use `Episode` for TV in the MVP rather than `Series`, because a series item is a container and not directly playable. The label in the UI can still say `TV Episodes` or `TV Shows` depending on how precise we want the first version to be.

Default settings:

```text
baseURL: empty
apiKey: empty
userID: empty
mediaType: movies
muted: true
```

Do not attempt playback until `baseURL`, `apiKey`, and `userID` are non-empty.

## Configuration Sheet

Implement a native AppKit configuration sheet exposed by the screensaver view:

```swift
override var hasConfigureSheet: Bool { true }
override var configureSheet: NSWindow? { settingsWindowController.window }
```

Use a programmatic AppKit form for the MVP.

Controls:

```text
Jellyfin Base URL: NSTextField
Jellyfin API Key: NSSecureTextField
Jellyfin User ID: NSTextField
Media Type: NSPopUpButton
Play Muted: NSButton checkbox
Cancel: NSButton
Save: NSButton
```

Save behavior:

- Normalize the base URL by trimming whitespace and removing trailing slashes.
- Persist all values to `ScreenSaverDefaults`.
- Call `synchronize()` after saving.
- End the sheet.

Cancel behavior:

- Discard unsaved edits.
- End the sheet.

## Screensaver Lifecycle

The `ScreenSaverView` subclass should own high-level lifecycle only.

On initialization:

- Enable layer-backed rendering.
- Set a black background.
- Create a playback controller.

On `startAnimation()`:

- Load current settings.
- If required settings are missing, show a black screen and return.
- Fetch/select media asynchronously.
- Build candidate playback URLs.
- Start playback on the main thread.

On `stopAnimation()`:

- Cancel in-flight network work if practical.
- Pause playback.
- Remove player layer.
- Release player resources.

On resize/layout:

- Keep the `AVPlayerLayer` frame equal to the screensaver view bounds.

## Jellyfin Client

Implement a small `JellyfinClient` using `URLSession` and `JSONDecoder`.

Primary method:

```swift
fetchRandomItems(settings: ScreensaverSettings) async throws -> [JellyfinItem]
```

Request path:

```text
/Users/{userID}/Items
```

Query parameters:

```text
IncludeItemTypes={Movie|Episode}
Recursive=true
SortBy=Random
Limit=100
Fields=ExternalUrls,MediaSources
```

Headers:

```text
X-Emby-Token: {apiKey}
Accept: application/json
```

Selection rule for the MVP:

- Prefer the first item where `UserData.Played == false`.
- If every item is played or the field is absent, do not play anything in the first version.

This keeps the behavior aligned with the original goal and avoids unexpectedly replaying watched media.

## Jellyfin Models

Decode only fields needed by the MVP.

```text
JellyfinItemsResponse
├─ Items: [JellyfinItem]

JellyfinItem
├─ Id: String
├─ Name: String?
├─ Type: String?
├─ MediaType: String?
└─ UserData: JellyfinUserData?

JellyfinUserData
└─ Played: Bool?
```

Use optional fields liberally because Jellyfin responses can vary by media type and server version.

## Playback URL Strategy

The main implementation unknown is which Jellyfin playback endpoint works best with `AVPlayer`.

Implement a small URL builder that can produce candidate URLs in priority order:

```text
1. /Videos/{itemID}/master.m3u8?api_key={apiKey}
2. /Videos/{itemID}/stream?static=true&api_key={apiKey}
```

Start with HLS because it is the most Apple-native streaming format.

If HLS fails, fallback to direct stream.

For the first implementation, it is acceptable to try one URL first, log failures with `NSLog`, and add fallback immediately after if needed.

Authentication note:

- API requests should use `X-Emby-Token`.
- Playback URLs may need `api_key` query auth because `AVPlayer` URL loading is simpler when credentials are embedded in the URL.

## Playback Controller

Implement a small controller around `AVPlayer` and `AVPlayerLayer`.

Responsibilities:

- Create `AVPlayer(url:)`.
- Set `player.isMuted` from settings.
- Create an `AVPlayerLayer`.
- Set `videoGravity = .resizeAspectFill`.
- Insert the layer into the screensaver view.
- Start playback.
- Observe playback failure/end if needed.
- Stop and clean up.

MVP behavior:

- Play once from the beginning.
- If playback ends while the screensaver is still active, fetch and play another item if the lifecycle code is already simple enough; otherwise stop on black for the first pass.

Preferred first-pass behavior: fetch another item on playback end, because screensavers may run for a while and ending on black will feel broken.

## Error Handling

Use `NSLog` for MVP diagnostics.

Expected errors:

- Missing settings.
- Invalid base URL.
- Jellyfin API request failure.
- Empty item list.
- No unwatched item found.
- Invalid playback URL.
- `AVPlayer` playback failure.

Do not show user-facing error UI during screensaver playback. A black screen is acceptable for failures in the MVP.

Add richer diagnostics to the configuration sheet later.

## Installation And Testing

Build output should be copied to:

```text
~/Library/Screen Savers/JellyfinRandomMovieScreensaver.saver
```

Manual test flow:

1. Build the `.saver` target.
2. Install the bundle into `~/Library/Screen Savers`.
3. Open macOS Screen Saver Settings.
4. Select the screensaver.
5. Open Options and enter base URL, API key, user ID, media type, and mute preference.
6. Use Preview to test playback.

Command-line validation before UI testing:

```text
curl -H 'X-Emby-Token: {apiKey}' '{baseURL}/Users/{userID}/Items?...'
```

Playback URL validation:

```text
open '{baseURL}/Videos/{itemID}/master.m3u8?api_key={apiKey}'
```

or test with a tiny temporary `AVPlayer` harness if browser behavior differs from AVFoundation.

## Implementation Order

1. Create Xcode `.saver` project/target and confirm macOS can load an empty black screensaver.
2. Add `ScreenSaverDefaults` settings model with defaults.
3. Add AppKit configuration sheet and verify settings persist.
4. Add Jellyfin model decoding and random-items request.
5. Add item selection for unwatched media.
6. Add playback URL builder.
7. Add `AVPlayerLayer` playback using a hardcoded known-good URL.
8. Connect Jellyfin selection to playback.
9. Add playback end handling to start another random item.
10. Add minimal logging around all failure paths.

## Acceptance Criteria

The MVP is complete when:

- The bundle installs as a selectable macOS screensaver.
- The Options sheet appears inside macOS Screen Saver Settings.
- Base URL, API key, user ID, media type, and mute preference persist.
- Previewing the screensaver fetches a random unwatched Jellyfin item.
- The selected item plays inside the screensaver view.
- Muted playback is enabled by default and respects the setting.
- Stopping the screensaver stops playback and releases player resources.

## Open Questions

- Which Jellyfin playback endpoint works most reliably with `AVPlayer` for this server?
- Does `AVPlayer` handle `api_key` query authentication for both HLS playlists and segment requests?
- Will direct stream URLs require transcoding parameters for some containers/codecs?
- Should TV mode select `Episode` only, or eventually support a series-first selection flow?
- Do we need code signing/notarization for local installation, or is unsigned local use acceptable for the MVP?

## Follow-Up Improvements

- Automatically discover user ID from API key.
- Add a `Test Connection` button in the settings sheet.
- Add a `Test Playback` button in the settings sheet.
- Display title/backdrop while loading.
- Cache recently played item IDs to avoid repeats.
- Add a setting for movie-only, episode-only, or mixed media.
- Add a setting for whether partially watched items are allowed.
- Add structured diagnostic logs or a diagnostics pane.
