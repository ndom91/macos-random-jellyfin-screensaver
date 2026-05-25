import AppKit
import AVFoundation

@MainActor
final class VideoPlaybackController {
    private weak var hostView: NSView?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerLayer: AVPlayerLayer?
    private var observations: [NSKeyValueObservation] = []
    private var statusHandler: ((String) -> Void)?

    init(hostView: NSView) {
        self.hostView = hostView
    }

    func play(url: URL, muted: Bool, statusHandler: ((String) -> Void)? = nil) {
        stop()
        self.statusHandler = statusHandler

        guard let hostView else {
            return
        }

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = muted

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = hostView.bounds
        playerLayer.videoGravity = .resizeAspectFill

        hostView.layer?.addSublayer(playerLayer)

        self.player = player
        self.playerItem = playerItem
        self.playerLayer = playerLayer
        observe(player: player, item: playerItem)

        player.play()
    }

    func layout() {
        guard let hostView else {
            return
        }

        playerLayer?.frame = hostView.bounds
    }

    func stop() {
        observations.removeAll()
        player?.pause()
        player = nil
        playerItem = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        statusHandler = nil
    }

    private func observe(player: AVPlayer, item: AVPlayerItem) {
        observations.append(item.observe(\.status, options: [.new]) { [weak self] item, _ in
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
                    self?.statusHandler?("Player paused")
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
}
