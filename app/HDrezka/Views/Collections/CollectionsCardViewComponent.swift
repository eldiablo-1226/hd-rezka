import SwiftUI
import NukeUI

/// Collection poster with a shimmer placeholder and its name (0x10008be0c).
struct CollectionsCardViewComponent: View {
    var collection: Collection
    @State var isAnimated: Bool = false

    var body: some View {
        VStack {
            LazyImage(url: URL(string: collection.poster), transaction: Transaction(animation: .easeInOut)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .transition(wipe)
                } else {
                    Rectangle()
                        .foregroundStyle(.quinary)
                        .overlay {
                            Rectangle()
                                .frame(height: 200)
                                .frame(width: 16)
                                .foregroundStyle(.quaternary)
                                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.primary, .gray]),
                                                                startPoint: .top, endPoint: .bottom))
                                .rotationEffect(.degrees(30))
                                .offset(x: isAnimated ? 120 : -120)
                                .blur(radius: 15)
                                .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut.repeatForever(autoreverses: false).speed(0.2), value: isAnimated)
                        }
                        .onAppear {
                            withAnimation {
                                isAnimated = true
                            }
                        }
                        .transition(wipe)
                }
            }
            .scaledToFill()
            .frame(width: 170, height: 98)
            .scaleEffect(1.1)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPoster, style: .continuous))

            // improvement: Dynamic Type (1.6.0: a fixed 12 pt in a fixed-height frame), and the number of films the
            // listing carries (parsed, never shown).
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(2, reservesSpace: true)
                if collection.count > 0 {
                    Label("\(collection.count)", systemImage: "film.stack")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(width: 170, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
    }

    // 0x10008ca88/0x10008ceec: both branches build this inline (Wipe consts 0x100439f80…fb0).
    private var wipe: AnyTransition {
        .asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10))
    }
}

extension Collection {
    /// improvement: skeleton card while the collections load; no poster URL, so the card shows its shimmer.
    static let placeholder = Collection(id: "", name: "Подборка фильмов", poster: "", count: 0)
}
