import SwiftUI

/// Title bar of HeaderScrollView (0x10002960c…0x100029e60); the app dropped the large title (an empty ZStack).
struct HeaderScrollViewTitle: View {
    var title: String
    var titleColor: Color
    var height: CGFloat
    var largeTitle: Double

    var body: some View {
        let largeTitleOpacity = (max(largeTitle, 0.5) - 0.5) * 2
        let tinyTitleOpacity = 1 - min(largeTitle, 0.5) * 2
        return ZStack {
            ZStack(alignment: .bottom) {}
                .padding(.bottom, 8)
                .opacity(sqrt(largeTitleOpacity))

            ZStack {
                HStack {
                    BackButton(color: .primary)
                    Spacer()
                    ShareButton(color: .primary)
                }
                HStack {
                    Text(String(title.prefix(32)))
                        .font(.system(size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .padding(.bottom, (height - 18) * 0.5)
            .opacity(sqrt(tinyTitleOpacity))
        }
        .frame(height: height)
    }
}
