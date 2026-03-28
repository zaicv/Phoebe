import SwiftUI
import AVKit

struct VaultPlayerView: View {
    @EnvironmentObject var appState: AppState

    let video: VaultVideoRef
    let streamURL: URL
    let headers: [String: String]
    let startSeconds: Double
    let onSavePosition: (Double) -> Void

    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: appState.cardCornerRadius, style: .continuous))
                    .onAppear {
                        player.play()
                    }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(video.filename)
                .font(.system(size: appState.bodyFontSize + 1, weight: .semibold, design: .rounded))

            Text(video.relativePath)
                .font(.system(size: appState.bodyFontSize - 1, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .navigationTitle(video.filename)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if player == nil {
                player = makePlayer()
            }
        }
        .onDisappear {
            let seconds = player?.currentTime().seconds ?? 0
            onSavePosition(seconds)
            player?.pause()
        }
    }

    private func makePlayer() -> AVPlayer {
        let options: [String: Any] = ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: streamURL, options: options)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        if startSeconds > 1 {
            let time = CMTime(seconds: startSeconds, preferredTimescale: 600)
            player.seek(to: time)
        }

        return player
    }
}
