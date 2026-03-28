import SwiftUI
import AVKit
#if os(macOS)
import AppKit
#endif

struct VaultPlayerView: View {
    let video: VaultVideoRef
    let streamURL: URL
    let headers: [String: String]
    let startSeconds: Double
    let onSavePosition: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let player {
                SystemAVPlayerView(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            Button {
                saveAndDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .padding(18)
        }
        .onAppear {
            if player == nil {
                let newPlayer = makePlayer()
                player = newPlayer
                newPlayer.play()
            }
        }
        .onDisappear {
            let seconds = player?.currentTime().seconds ?? 0
            onSavePosition(seconds)
            player?.pause()
        }
    }

    private func saveAndDismiss() {
        let seconds = player?.currentTime().seconds ?? 0
        onSavePosition(seconds)
        player?.pause()
        #if os(macOS)
        if let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        #endif
        dismiss()
    }

    private func makePlayer() -> AVPlayer {
        let options: [String: Any] = ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: streamURL, options: options)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        if startSeconds > 1 {
            player.seek(to: CMTime(seconds: startSeconds, preferredTimescale: 600))
        }
        return player
    }
}

#if os(iOS)
private struct SystemAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.exitsFullScreenWhenPlaybackEnds = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
#else
private struct SystemAVPlayerView: NSViewRepresentable {
    let player: AVPlayer

    final class Coordinator {
        var didToggleFullScreen = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .default
        view.videoGravity = .resizeAspect
        view.showsFrameSteppingButtons = false
        view.showsFullScreenToggleButton = true
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player

        guard !context.coordinator.didToggleFullScreen else { return }
        guard let window = nsView.window else { return }

        context.coordinator.didToggleFullScreen = true
        DispatchQueue.main.async {
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
}
#endif
