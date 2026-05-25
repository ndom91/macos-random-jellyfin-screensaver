import AppKit
import AVFoundation

@MainActor
final class VideoPlaybackController {
    private let playerView: NSView
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerLayer: AVPlayerLayer?
    private var observations: [NSKeyValueObservation] = []
    private var statusHandler: ((String) -> Void)?
    private var diagnosticsTask: Task<Void, Never>?

    init(hostView: NSView) {
        playerView = NSView(frame: hostView.bounds)
        playerView.wantsLayer = true
        playerView.layer?.backgroundColor = NSColor.black.cgColor
        playerView.autoresizingMask = [.width, .height]
        hostView.addSubview(playerView, positioned: .below, relativeTo: nil)
    }

    func play(url: URL, muted: Bool, startTime: TimeInterval = 0, statusHandler: ((String) -> Void)? = nil) {
        stop()
        self.statusHandler = statusHandler

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = muted

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = playerView.bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.zPosition = 0

        playerView.layer?.addSublayer(playerLayer)

        self.player = player
        self.playerItem = playerItem
        self.playerLayer = playerLayer
        observe(player: player, item: playerItem)
        startDiagnostics(player: player, item: playerItem)

        let startPlayback = { [weak player, statusHandler] in
            player?.playImmediately(atRate: 1.0)
            statusHandler?("Playback requested")
        }

        if startTime > 0 {
            let seekTime = CMTime(seconds: startTime, preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                Task { @MainActor in
                    startPlayback()
                }
            }
        } else {
            startPlayback()
        }
    }

    func layout() {
        playerLayer?.frame = playerView.bounds
    }

    func stop() {
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        statusHandler = nil
        observations.removeAll()
        player?.rate = 0
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    private func observe(player: AVPlayer, item: AVPlayerItem) {
        observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self?.statusHandler?("Video ready to play")
                case .failed:
                    self?.statusHandler?("Video item failed: \(item.error?.localizedDescription ?? "unknown error")")
                case .unknown:
                    self?.statusHandler?("Video item status unknown")
                @unknown default:
                    self?.statusHandler?("Video item status changed")
                }
            }
        })

        observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                switch player.timeControlStatus {
                case .paused:
                    self?.statusHandler?("Player paused after playback request")
                case .waitingToPlayAtSpecifiedRate:
                    self?.statusHandler?("Player waiting: \(player.reasonForWaitingToPlay?.rawValue ?? "unknown")")
                case .playing:
                    self?.statusHandler?("Player playing")
                @unknown default:
                    self?.statusHandler?("Player status changed")
                }
            }
        })
    }

    private func startDiagnostics(player: AVPlayer, item: AVPlayerItem) {
        diagnosticsTask = Task { [weak self, weak player, weak item] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, let player, let item else {
                    return
                }

                let itemStatus: String
                switch item.status {
                case .unknown:
                    itemStatus = "unknown"
                case .readyToPlay:
                    itemStatus = "ready"
                case .failed:
                    itemStatus = "failed"
                @unknown default:
                    itemStatus = "other"
                }

                let playerStatus: String
                switch player.timeControlStatus {
                case .paused:
                    playerStatus = "paused"
                case .waitingToPlayAtSpecifiedRate:
                    playerStatus = "waiting(\(player.reasonForWaitingToPlay?.rawValue ?? "unknown"))"
                case .playing:
                    playerStatus = "playing"
                @unknown default:
                    playerStatus = "other"
                }

                let time = CMTimeGetSeconds(player.currentTime())
                let size = item.presentationSize

                self.statusHandler?("Diagnostics: item=\(itemStatus), player=\(playerStatus), rate=\(player.rate), time=\(String(format: "%.1f", time)), size=\(Int(size.width))x\(Int(size.height)), error=\(item.error?.localizedDescription ?? "none")")
            }
        }
    }
}
