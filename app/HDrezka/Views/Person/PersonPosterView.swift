import SwiftUI
import NukeUI

struct PersonPosterView: View {
    @State var isAnimated: Bool = false
    var url: String

    var body: some View {
        LazyImage(url: URL(string: url), transaction: Transaction(animation: .easeInOut)) { state in
            if let image = state.image {
                image
                    .resizable()
                    .transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))
            } else {
                // Shimmer placeholder while the photo loads.
                Rectangle()
                    .foregroundStyle(.quinary)
                    .overlay {
                        Rectangle()
                            .frame(height: 350)
                            .frame(width: 30)
                            .foregroundStyle(.quaternary)
                            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.primary, .gray]), startPoint: .top, endPoint: .bottom))
                            .rotationEffect(.degrees(30))
                            .offset(x: isAnimated ? 120 : -120)
                            .blur(radius: 15)
                    }
                    .onAppear {
                        withAnimation(.easeOut.repeatForever(autoreverses: false).speed(0.3)) {
                            isAnimated = true
                        }
                    }
                    .transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))
            }
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: 140, height: 213)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
