import SwiftUI
import NukeUI

/// iPhone movie card (0x1000d7248; poster 0x1000d7b64, loading shimmer 0x1000d83c4).
struct TitleCardComponent: View {
    var model: MovieSimple
    /// improvement: a grid's card fills its column at accessibility sizes, where the grid shows two (`columnMinimum`);
    /// a card in a horizontal row keeps the phone's 113 pt poster.
    var fillsColumn = true
    @State var isAnimated: Bool = false
    // improvement: the text block grows with Dynamic Type (1.6.0: a fixed 44pt under fixed 12/10pt fonts).
    @ScaledMetric(relativeTo: .caption) var textHeight: CGFloat = 48
    @Environment(\.dynamicTypeSize) private var typeSize

    /// About three columns on a phone; two at accessibility sizes, so titles wrap instead of ending in «…».
    static func columnMinimum(_ size: DynamicTypeSize, phone: CGFloat = 100) -> CGFloat {
        size.isAccessibilitySize ? 150 : phone
    }

    private var isFilling: Bool { fillsColumn && typeSize.isAccessibilitySize }

    var body: some View {
        VStack {
            LazyImage(url: URL(string: model.poster), transaction: Transaction(animation: .easeInOut)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))
                } else if state.error != nil && !model.poster.isEmpty {
                    // A skeleton card has no poster URL, so its "error" is no request at all; it keeps the shimmer.
                    MissingPoster()
                } else {
                    Rectangle()
                        .foregroundStyle(.quinary)
                        .overlay(alignment: .center) {
                            Rectangle()
                                .frame(height: 200)
                                .frame(width: 16)
                                .foregroundStyle(.quaternary)
                                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.primary, .gray]), startPoint: .top, endPoint: .bottom))
                                .rotationEffect(.degrees(30), anchor: .center)
                                .offset(x: isAnimated ? 120 : -120)
                                .blur(radius: 15)
                                .animation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut.repeatForever(autoreverses: false).speed(0.2), value: isAnimated)
                        }
                        .onAppear { withAnimation { isAnimated = true } }
                        .transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))
                }
            }
            .scaledToFill()
            .modifier(PosterFrame(fills: isFilling))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPoster), style: FillStyle())
            .overlay(alignment: .bottomLeading) {
                TitleBadge(entity: model.entity, info: model.info)
                    .padding(DesignTokens.space4)
            }
            VStack(alignment: .leading) {
                // improvement: no shrinking: a long title ends in «…» at the grid's one size (it shrank to 80%, so
                // neighbouring titles came out in different sizes).
                Text(model.name)
                    .font(.caption.bold())
                    .lineLimit(2)
                Text(model.details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            // The phone's fixed 112 pt: in a horizontal row nothing else gives the block a width, and a short title would
            // sit centred under the poster.
            .frame(width: isFilling ? nil : 112, alignment: .topLeading)
            .frame(maxWidth: isFilling ? .infinity : nil, alignment: .topLeading)
            .frame(height: textHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
    }
}

/// The phone's 113 × 171 poster, or the column's width at 2:3.
private struct PosterFrame: ViewModifier {
    var fills: Bool

    func body(content: Content) -> some View {
        if fills {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { content }
        } else {
            content.frame(width: 113, height: 171)
        }
    }
}

/// improvement: type and series progress from the listing card's cover ("СЕРИАЛ" / "2 сезон, 8 серия"), over the poster.
struct TitleBadge: View {
    var entity: String?
    var info: String?

    var body: some View {
        if entity != nil || info != nil {
            VStack(alignment: .leading, spacing: 0) {
                if let entity {
                    // textCase, not uppercased(): VoiceOver reads "Сериал" as a word, not letter by letter.
                    Text(entity)
                        .textCase(.uppercase)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let info {
                    Text(Self.shortInfo(info))
                        .font(.caption2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.space8)
            .padding(.vertical, DesignTokens.space4)
            // Solid, not a material: dozens of blurs in a lazy grid cost scrolling smoothness.
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: DesignTokens.radiusBadge))
            // The poster doesn't grow with Dynamic Type, so the badge stops growing before it covers it.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    /// "Завершен (все серии)" (121pt at 11pt) doesn't fit a 113pt poster; "Завершен" says the same. Other text stays.
    static func shortInfo(_ info: String) -> String {
        info.replacingOccurrences(of: " (все серии)", with: "")
    }
}

extension MovieSimple {
    /// Skeleton card while a listing loads: no poster URL, so the card shows its shimmer; the text is redacted.
    static let placeholder = MovieSimple(id: "", name: "Название фильма", details: "2026, Страна, Жанр", poster: "")
}

/// improvement: a poster that can't load ends here, a film symbol on the loading fill, instead of a shimmer or grey
/// fill that looks like it is still coming.
struct MissingPoster: View {
    var body: some View {
        Rectangle()
            .foregroundStyle(.quinary)
            .overlay {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}
