import SwiftUI
import NukeUI

/// iPhone movie card (0x1000d7248; poster 0x1000d7b64, loading shimmer 0x1000d83c4).
struct TitleCardComponent: View {
    var model: MovieSimple
    @State var isAnimated: Bool = false
    // improvement: the text block grows with Dynamic Type (1.6.0: a fixed 44pt under fixed 12/10pt fonts).
    @ScaledMetric(relativeTo: .caption) var textHeight: CGFloat = 48

    var body: some View {
        VStack {
            LazyImage(url: URL(string: model.poster), transaction: Transaction(animation: .easeInOut)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))
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
            .frame(width: 113, height: 171)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPoster), style: FillStyle())
            .overlay(alignment: .bottomLeading) {
                TitleBadge(entity: model.entity, info: model.info)
                    .padding(DesignTokens.space4)
            }
            VStack(alignment: .leading) {
                Text(model.name)
                    .font(.caption.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(model.details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 112, height: textHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity)
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
