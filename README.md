# Jellyfin Random Media Screensaver

A native macOS screensaver that plays a random unwatched Jellyfin movie or TV episode.

It fetches random unwatched items from your Jellyfin server, skips the first two minutes to avoid studio intros, briefly shows the selected title, and plays the video inside the macOS screensaver.

## Features

- Native macOS `.saver` bundle.
- Plays random unwatched Jellyfin media.
- Supports movies and TV episodes.
- Muted by default, with an option to enable audio.
- Subtitles enabled by default when the Jellyfin stream exposes compatible subtitle tracks.
- Starts playback at the 2-minute mark.

## Install

1. Download the latest `.zip` from GitHub Releases.
2. Unzip it.
3. Copy `JellyfinRandomMovieScreensaver.saver` to `~/Library/Screen Savers/`.
4. Open macOS Screen Saver Settings, select **Jellyfin Random Media Screensaver**, and fill in **Options...**.

## Configuration

After installing, open macOS Screen Saver Settings, select **Jellyfin Random Media Screensaver**, and open **Options...**.

Settings:

- **Jellyfin Base URL**: your Jellyfin server URL, for example `https://watch.example.com`.
- **Jellyfin API Key**: a Jellyfin API key.
- **Jellyfin User ID**: the ID from Jellyfin API paths like `/Users/{userId}/Items`; this is not a media item ID.
- **Media Type**: movies or TV episodes.
- **Play muted**: enabled by default.
- **Enable subtitles**: enabled by default; depends on subtitles being exposed by the Jellyfin playback stream.

## Build And Install

Prebuilt `.saver` bundles are available from GitHub Releases. Download the latest `.zip`, unzip it, and install `JellyfinRandomMovieScreensaver.saver` into:

```text
~/Library/Screen Savers/
```

To build from source, install Xcode Command Line Tools if needed:


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
make dev-install
make print-bundle
make clean
```

`make dev-install` runs a clean build, installs the screensaver, and prints the command for launching the current screensaver manually.

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

## LICENSE

MIT
