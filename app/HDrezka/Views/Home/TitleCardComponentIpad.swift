import SwiftUI
import NukeUI

/// iPad movie card (0x1000db058; poster 0x1000db97c, loading shimmer 0x1000dc1dc).
struct TitleCardComponentIpad: View {
    var model: MovieSimple
    @State var isAnimated: Bool = false
    // improvement: the text block grows with Dynamic Type (1.6.0: a fixed 65pt).
    @ScaledMetric(relativeTo: .body) var textHeight: CGFloat = 65

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
                                .frame(height: 300)
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
            .frame(width: 164, height: 247)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusPoster), style: FillStyle())
            .overlay(alignment: .bottomLeading) {
                TitleBadge(entity: model.entity, info: model.info)
                    .padding(DesignTokens.space4)
            }
            VStack(alignment: .leading) {
                Text(model.name)
                    .font(.body)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(model.details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 163, height: textHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
    }
}
