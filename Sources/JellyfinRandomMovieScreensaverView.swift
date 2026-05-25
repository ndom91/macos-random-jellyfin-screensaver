import AppKit
import ScreenSaver

@objc(JellyfinRandomMovieScreensaverView)
final class JellyfinRandomMovieScreensaverView: ScreenSaverView {
    private let jellyfinClient = JellyfinClient()
    private let playbackURLBuilder = PlaybackURLBuilder()
    private var playbackController: VideoPlaybackController?
    private var settingsWindowController: SettingsWindowController?
    private var playbackTask: Task<Void, Never>?
    private var playbackRequestID: UUID?
    private let statusLabel = NSTextField(labelWithString: "")

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        initializeView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    override var hasConfigureSheet: Bool {
        true
    }

    override var configureSheet: NSWindow? {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }

        return settingsWindowController?.window
    }

    override func startAnimation() {
        super.startAnimation()
        startPlayback()
    }

    override func stopAnimation() {
        super.stopAnimation()
        playbackRequestID = nil
        playbackTask?.cancel()
        playbackTask = nil

        Task { @MainActor in
            playbackController?.stop()
        }
    }

    override func layout() {
        super.layout()
        playbackController?.layout()
        layoutStatusLabel()
    }

    private func initializeView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        animationTimeInterval = 1.0 / 30.0
        playbackController = VideoPlaybackController(hostView: self)
        configureStatusLabel()
        showStatus("Jellyfin screensaver loaded")
    }

    private func startPlayback() {
        playbackTask?.cancel()

        let settings = ScreensaverSettings.load()
        guard settings.hasRequiredPlaybackSettings else {
            logAndShowStatus("Missing Jellyfin settings. Open Options and fill base URL, API key, and user ID.")
            return
        }

        let requestID = UUID()
        playbackRequestID = requestID
        logAndShowStatus("Fetching random \(settings.mediaType.displayName.lowercased()) from Jellyfin...")
        NSLog("JellyfinRandomMovieScreensaver: random items URL: \(jellyfinClient.redactedRandomItemsURL(settings: settings))")

        playbackTask = Task { [jellyfinClient, playbackURLBuilder] in
            do {
                let items = try await jellyfinClient.fetchRandomItems(settings: settings)
                try Task.checkCancellation()

                guard let item = items.first(where: { $0.userData?.played == false }) else {
                    await MainActor.run { [weak self] in
                        self?.logAndShowStatus("No unwatched Jellyfin items found.")
                    }
                    return
                }

                guard let playbackURL = playbackURLBuilder.candidateURLs(for: item, settings: settings).first else {
                    await MainActor.run { [weak self] in
                        self?.logAndShowStatus("Could not build playback URL for \(item.name ?? item.id).")
                    }
                    return
                }

                await MainActor.run { [weak self] in
                    guard self?.playbackRequestID == requestID else {
                        return
                    }

                    let itemName = item.name ?? item.id
                    self?.logAndShowStatus("Playing \(itemName)")
                    NSLog("JellyfinRandomMovieScreensaver: playback URL: \(playbackURL.absoluteString)")
                    self?.playbackController?.play(url: playbackURL, muted: settings.muted) { [weak self] status in
                        self?.logAndShowStatus("\(itemName): \(status)")
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { [weak self] in
                    self?.logAndShowStatus("Playback startup failed: \(error)")
                }
            }
        }
    }

    private func configureStatusLabel() {
        statusLabel.textColor = .white
        statusLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3
        statusLabel.backgroundColor = .clear
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)
        layoutStatusLabel()
    }

    private func layoutStatusLabel() {
        let width = min(bounds.width - 80, 760)
        statusLabel.frame = NSRect(
            x: (bounds.width - width) / 2,
            y: (bounds.height - 90) / 2,
            width: width,
            height: 90
        )
    }

    private func showStatus(_ message: String) {
        statusLabel.stringValue = message
        statusLabel.isHidden = false
        layoutStatusLabel()
    }

    private func logAndShowStatus(_ message: String) {
        NSLog("JellyfinRandomMovieScreensaver: \(message)")
        showStatus(message)
    }
}
