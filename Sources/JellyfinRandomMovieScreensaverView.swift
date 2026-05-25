import AppKit
import ScreenSaver

@objc(JellyfinRandomMovieScreensaverView)
@MainActor
final class JellyfinRandomMovieScreensaverView: ScreenSaverView {
    private let jellyfinClient = JellyfinClient()
    private let playbackURLBuilder = PlaybackURLBuilder()
    private var playbackController: VideoPlaybackController?
    private var settingsWindowController: SettingsWindowController?
    private var playbackTask: Task<Void, Never>?
    private var playbackRequestID: UUID?
    private let statusLabel = NSTextField(labelWithString: "")
    private var windowWillCloseObserver: NSObjectProtocol?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        initializeView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)

        if let windowWillCloseObserver {
            NotificationCenter.default.removeObserver(windowWillCloseObserver)
        }
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
        stopPlayback()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let windowWillCloseObserver {
            NotificationCenter.default.removeObserver(windowWillCloseObserver)
            self.windowWillCloseObserver = nil
        }

        if let window {
            windowWillCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.stopPlayback()
                }
            }
        }

        if window == nil {
            stopPlayback()
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            stopPlayback()
        }

        super.viewWillMove(toWindow: newWindow)
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            stopPlayback()
        }

        super.viewWillMove(toSuperview: newSuperview)
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
        registerLifecycleObservers()
        hideStatus()
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
        NSLog("JellyfinRandomMovieScreensaver: fetching random \(settings.mediaType.displayName.lowercased()) from Jellyfin")
        NSLog("JellyfinRandomMovieScreensaver: random items URL: \(jellyfinClient.redactedRandomItemsURL(settings: settings))")

        playbackTask = Task { [jellyfinClient, playbackURLBuilder] in
            do {
                let items = try await jellyfinClient.fetchRandomItems(settings: settings)
                try Task.checkCancellation()

                let unwatchedItems = items.filter { $0.userData?.played == false }
                guard let item = unwatchedItems.first(where: { $0.isLikelyAVPlayerCompatible }) ?? unwatchedItems.first else {
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
                    self?.hideStatus()
                    NSLog("JellyfinRandomMovieScreensaver: starting \(itemName)")
                    NSLog("JellyfinRandomMovieScreensaver: selected item container: \(item.container ?? "unknown")")
                    NSLog("JellyfinRandomMovieScreensaver: playback URL: \(playbackURL.absoluteString)")
                    self?.playbackController?.play(url: playbackURL, muted: settings.muted) { [weak self] status in
                        self?.handlePlaybackStatus(status, itemName: itemName)
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

    private func stopPlayback() {
        NSLog("JellyfinRandomMovieScreensaver: stopping playback")
        playbackRequestID = nil
        playbackTask?.cancel()
        playbackTask = nil
        playbackController?.stop()
    }

    private func registerLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenIsUnlocked),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc private func applicationWillTerminate() {
        stopPlayback()
    }

    @objc private func applicationDidResignActive() {
        stopPlayback()
    }

    @objc private func screenIsUnlocked() {
        stopPlayback()
    }

    private func configureStatusLabel() {
        statusLabel.textColor = .white
        statusLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3
        statusLabel.backgroundColor = .clear
        statusLabel.wantsLayer = true
        statusLabel.layer?.zPosition = 10
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

    private func hideStatus() {
        statusLabel.isHidden = true
    }

    private func logAndShowStatus(_ message: String) {
        NSLog("JellyfinRandomMovieScreensaver: \(message)")
        showStatus(message)
    }

    private func handlePlaybackStatus(_ status: String, itemName: String) {
        NSLog("JellyfinRandomMovieScreensaver: \(itemName): \(status)")

        if status == "Player playing" || status == "Video ready to play" {
            hideStatus()
            return
        }

        if status.hasPrefix("Diagnostics:") {
            if status.contains("player=playing") && status.contains("error=none") {
                hideStatus()
            } else {
                showStatus("\(itemName): \(status)")
            }
            return
        }

        if status == "Playback requested" || status == "Video item status unknown" {
            return
        }

        showStatus("\(itemName): \(status)")
    }
}
