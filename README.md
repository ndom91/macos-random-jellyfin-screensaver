# Jellyfin Random Media Screensaver

A native macOS screensaver that plays a random unwatched Jellyfin media item when the screensaver starts.

The first version is planned as a Swift-only `.saver` bundle using `ScreenSaver.framework`, `URLSession`, and `AVPlayerLayer`.

## Status

This project is in early planning/implementation.

See:

- `docs/2025-05-25-initial-plan.md`
- `docs/2026-05-25-implementation-plan.md`

## Planned Settings

The screensaver will include a native macOS Screen Saver Options sheet with:

- Jellyfin base URL
- Jellyfin API key
- Jellyfin user ID from `/Users/{userId}/Items`, not a media item ID
- Media type: movies or TV episodes
- Play muted toggle

## Development Setup

Install Xcode from the Mac App Store or Apple Developer downloads, then install the command-line tools:

```sh
xcode-select --install
```

Accept the Xcode license if needed:

```sh
sudo xcodebuild -license accept
```

Xcode is useful for project/target configuration and macOS framework integration, but this repo also includes a `Makefile` that can build the `.saver` bundle directly with `swiftc`.

A typical Neovim workflow is:

```text
edit Swift files in nvim
build with make
install the .saver bundle locally
test through macOS Screen Saver Settings
```

Useful editor tooling:

- `sourcekit-lsp` for Swift language server support
- `swift-format` for formatting, if added to the project later
- `xcodebuild` for command-line builds
- `make` for the current CLI build/install workflow

## Building With Make

Build the screensaver bundle:

```sh
make build
```

Print the built bundle path:

```sh
make print-bundle
```

Install the screensaver for the current user:

```sh
make install
```

Clean build output:

```sh
make clean
```

The local build output is:

```text
build/Debug/JellyfinRandomMovieScreensaver.saver
```

The build performs local ad-hoc code signing with:

```sh
codesign --force --sign - --timestamp=none build/Debug/JellyfinRandomMovieScreensaver.saver
```

This is required on modern macOS so the screensaver bundle can be loaded locally by the system screensaver process.

## Building Without Opening Xcode

The current project can be built with `make` as described above. If an Xcode project is added later, the equivalent command-line workflow will look like this.

List available schemes:

```sh
xcodebuild -list -project JellyfinRandomMovieScreensaver.xcodeproj
```

Build the screensaver:

```sh
xcodebuild \
  -project JellyfinRandomMovieScreensaver.xcodeproj \
  -scheme JellyfinRandomMovieScreensaver \
  -configuration Debug \
  build
```

Clean the build:

```sh
xcodebuild \
  -project JellyfinRandomMovieScreensaver.xcodeproj \
  -scheme JellyfinRandomMovieScreensaver \
  clean
```

The built `.saver` bundle will be under Xcode's derived data build output. The exact path can vary by machine and Xcode settings.

To find the build directory, run:

```sh
xcodebuild \
  -project JellyfinRandomMovieScreensaver.xcodeproj \
  -scheme JellyfinRandomMovieScreensaver \
  -configuration Debug \
  -showBuildSettings
```

Look for `BUILT_PRODUCTS_DIR`.

## Local Installation

Install the built screensaver into your user-local Screen Savers folder:

```sh
mkdir -p "$HOME/Library/Screen Savers"
cp -R path/to/JellyfinRandomMovieScreensaver.saver "$HOME/Library/Screen Savers/"
```

Then open macOS Screen Saver Settings and select `JellyfinRandomMovieScreensaver`.

For local development, a paid Apple Developer account and notarization should not be required.

## Local Testing

Launch the currently selected screensaver immediately:

```sh
open -a ScreenSaverEngine
```

View recent screensaver logs:

```sh
command log show --last 2m --style compact --predicate 'eventMessage CONTAINS "JellyfinRandomMovieScreensaver"'
```

Modern macOS may show Wallpaper settings labels while custom `.saver` modules are launched through the legacy screensaver host. If the logs mention `Setting module “JellyfinRandomMovieScreensaver”`, the custom module is being loaded.

## Distribution Notes

For personal local builds, unsigned or ad-hoc signed builds are usually enough.

For public distribution, expect to use:

- Apple Developer Program membership
- Developer ID Application certificate
- code signing
- notarization
- stapling

Unsigned or unnotarized shared builds may trigger Gatekeeper warnings or require manual security overrides.
