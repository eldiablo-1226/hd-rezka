import SwiftUI

/// One account section card of the profile (watch later, bookmarks, series updates) (0x1000b985c).
struct AccountCardViewComponent: View {
    var name: LocalizedStringKey
    var desc: LocalizedStringKey
    var image: String

    var body: some View {
        // The binary wraps the card in its own NavigationStack (body witness 0x1000b9f50).
        NavigationStack {
            ViewThatFits {
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Label {
                                Text(name)
                                    .bold()
                            } icon: {
                                // improvement: secondary, not the accent: the icon names the card, the card is the button.
                                Image(systemName: image)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 2)
                            Text(desc)
                        }
                        Spacer()
                    }
                }
                .padding(15)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.radiusButton, style: .continuous)
                        .foregroundStyle(.quinary)
                }
            }
        }
    }
}
