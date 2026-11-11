import SwiftUI

struct PremiumUnavailableView: View {
    @Environment(\.openURL) var openURL
    @AppStorage("mirror") private var mirror: String = DefaultSettings.mirror

    var body: some View {
        VStack {
            Text("key_this+premium+acting")
                .font(.title)
                .bold()
                .padding(.bottom, 6)
            Text("key_this+premium+acting+description")
                .font(.callout)
                .padding(.bottom, 12)
            Button {
                // improvement: the chosen mirror; 1.6.0 hard-coded hdrezka.ag, which is blocked on some networks.
                if let url = URL(string: "https://\(mirror)/payments") { openURL(url) }
            } label: {
                Label("key_buy", systemImage: "star.fill")
                    .labelStyle(TextFirstLabel())
                    .bold()
                    .padding(6)
                    .frame(maxWidth: .infinity)
            }
            .secondaryButtonStyle()
            // improvement: the app accent instead of `.tint(.purple)`; set here, since glass draws an untinted label in
            // the primary colour (`.bordered` used the accent by itself).
            .tint(.accentColor)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            Text("key_this+premium+acting+caption")
                .font(.caption)
        }
        .padding(6)
        .multilineTextAlignment(.center)
    }
}
