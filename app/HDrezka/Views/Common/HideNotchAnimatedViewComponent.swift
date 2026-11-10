import SwiftUI

/// Phone outline whose notch area turns black when "hide notch" is on (0x1000ad780, 0x1000adcf0).
struct HideNotchAnimatedViewComponent: View {
    @Binding var isAnimated: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(Color.black, lineWidth: 8)
                .frame(width: 300, height: 150)
                .background(alignment: .center) {
                    ZStack {
                        Rectangle()
                            .foregroundStyle(Color.black)
                            .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 25, bottomLeading: 25), style: .continuous))
                            .frame(width: isAnimated ? 40 : 0, height: isAnimated ? 150 : 140)
                            .offset(x: isAnimated ? -135 : -146, y: 0)
                            .animation(.spring(response: 0.5, dampingFraction: 1), value: isAnimated)
                        Rectangle()
                            .foregroundStyle(Color.black)
                            .clipShape(UnevenRoundedRectangle(cornerRadii: .init(bottomTrailing: 25, topTrailing: 25), style: .continuous))
                            .frame(width: isAnimated ? 40 : 0, height: isAnimated ? 150 : 140)
                            .offset(x: isAnimated ? 135 : 146, y: 0)
                            .animation(.spring(response: 0.5, dampingFraction: 1), value: isAnimated)
                    }
                }
            Capsule()
                .foregroundStyle(Color.black)
                .frame(width: 17, height: 50)
                .offset(x: -130, y: 0)
            Capsule()
                .foregroundStyle(Color.black)
                .frame(width: 3, height: 50)
                .offset(x: 140, y: 0)
        }
    }
}
