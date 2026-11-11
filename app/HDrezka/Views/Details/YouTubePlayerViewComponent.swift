import SwiftUI
import YouTubePlayerKit

struct YouTubePlayerViewComponent: View {
    var youTubePlayer: YouTubePlayer

    // The overlay from the YouTubePlayerKit README, 16:9 with rounded corners (0x1000acefc).
    var body: some View {
        YouTubePlayerView(youTubePlayer) { state in
            switch state {
            case .idle:
                ProgressView()
            case .ready:
                EmptyView()
            case .error:
                Text(verbatim: "YouTube player couldn't be loaded")
            }
        }
        .aspectRatio(16 / 9, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusButton, style: .continuous))
    }
}
