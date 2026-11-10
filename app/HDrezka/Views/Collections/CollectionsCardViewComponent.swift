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
                                .animation(.easeOut.repeatForever(autoreverses: false).speed(0.2), value: isAnimated)
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading) {
                Text(collection.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }
            .frame(width: 170, height: 30, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
    }

    // 0x10008ca88/0x10008ceec: both branches build this inline (Wipe consts 0x100439f80…fb0).
    private var wipe: AnyTransition {
        .asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10))
    }
}
