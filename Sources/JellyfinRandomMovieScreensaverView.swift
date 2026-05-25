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
    private var hideTitleTask: Task<Void, Never>?
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

                let subtitleCues: [SubtitleCue]
                if settings.subtitlesEnabled {
                    subtitleCues = (try? await jellyfinClient.fetchSubtitleCues(item: item, settings: settings)) ?? []
                    NSLog("JellyfinRandomMovieScreensaver: loaded \(subtitleCues.count) subtitle cues")
                } else {
                    subtitleCues = []
                }

                await MainActor.run { [weak self] in
                    guard self?.playbackRequestID == requestID else {
                        return
                    }

                    let itemName = item.name ?? item.id
                    self?.showTemporaryTitle(itemName)
                    NSLog("JellyfinRandomMovieScreensaver: starting \(itemName)")
                    NSLog("JellyfinRandomMovieScreensaver: selected item container: \(item.container ?? "unknown")")
                    NSLog("JellyfinRandomMovieScreensaver: playback URL: \(playbackURL.absoluteString)")
                    self?.playbackController?.play(url: playbackURL, muted: settings.muted, subtitlesEnabled: settings.subtitlesEnabled, subtitleCues: subtitleCues, startTime: 120) { [weak self] status in
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
        hideTitleTask?.cancel()
        hideTitleTask = nil
        hideStatus()
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
        statusLabel.font = NSFont.systemFont(ofSize: 44, weight: .semibold)
        statusLabel.alignment = .left
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.backgroundColor = .clear
        statusLabel.wantsLayer = true
        statusLabel.layer?.zPosition = 10
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)
        layoutStatusLabel()
    }

    private func layoutStatusLabel() {
        let horizontalPadding: CGFloat = 72
        let bottomPadding: CGFloat = 72
        let width = min(bounds.width - (horizontalPadding * 2), 980)
        let height: CGFloat = 130
        statusLabel.frame = NSRect(
            x: horizontalPadding,
            y: bottomPadding,
            width: width,
            height: height
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

    private func showTemporaryTitle(_ title: String) {
        hideTitleTask?.cancel()
        showStatus(title)

        hideTitleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.hideStatus()
            }
        }
    }

    private func logAndShowStatus(_ message: String) {
        NSLog("JellyfinRandomMovieScreensaver: \(message)")
        showStatus(message)
    }

    private func handlePlaybackStatus(_ status: String, itemName: String) {
        NSLog("JellyfinRandomMovieScreensaver: \(itemName): \(status)")
        let normalizedStatus = status.lowercased()

        if normalizedStatus == "player playing" || normalizedStatus == "video ready to play" {
            return
        }

        if normalizedStatus == "subtitles enabled" || normalizedStatus == "no subtitle track exposed by stream" || normalizedStatus == "no selectable subtitle track exposed by stream" {
            return
        }

        if normalizedStatus == "playback requested" || normalizedStatus == "video item status unknown" {
            return
        }

        if normalizedStatus.hasPrefix("player waiting:") || normalizedStatus == "player paused after playback request" {
            return
        }

        if normalizedStatus.hasPrefix("diagnostics:") {
            if normalizedStatus.contains("error=none") {
                return
            }

            showStatus("\(itemName): \(status)")
            return
        }

        if !normalizedStatus.contains("failed") && !normalizedStatus.contains("error") && !normalizedStatus.contains("cannot") {
            return
        }

        showStatus("\(itemName): \(status)")
    }
}
