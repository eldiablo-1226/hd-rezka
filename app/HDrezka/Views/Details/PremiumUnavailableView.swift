import SwiftUI

struct PremiumUnavailableView: View {
    @Environment(\.openURL) var openURL

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
                openURL(URL(string: "https://hdrezka.ag/payments")!)
            } label: {
                Label("key_buy", systemImage: "star.fill")
                    .labelStyle(TextFirstLabel())
                    .bold()
                    .padding(6)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 12)
            .tint(.purple)
            .padding(.bottom, 6)
            Text("key_this+premium+acting+caption")
                .font(.caption)
        }
        .padding(6)
        .multilineTextAlignment(.center)
    }
}
