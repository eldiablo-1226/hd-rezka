import SwiftUI

struct StarsView: View {
    var rating: CGFloat

    // Five gray stars with a yellow bar masked by the same stars; rating is out of 10 (0x10010c00c, bar 0x10010c350).
    var body: some View {
        stars
            .overlay(
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: rating / 5 * 0.5 * geometry.size.width)
                            .foregroundColor(.yellow)
                    }
                }
                .mask(stars)
            )
            .foregroundColor(.gray)
    }

    private var stars: some View {
        HStack {
            ForEach(0..<5, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
