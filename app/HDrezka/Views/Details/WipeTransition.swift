import SwiftUI

extension AnyTransition {
    /// Wipe along `angle` with a blurred edge; the blur radius is clamped to 0...30 (0x100042754).
    /// Every LazyImage call site of the original inlines this as
    /// `.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10))`.
    static func wipe(angle: Angle, blurRadius: CGFloat) -> AnyTransition {
        // improvement: with Reduce Motion a poster fades in instead of wiping across with a blur.
        if UIAccessibility.isReduceMotionEnabled { return .opacity }
        var radius = blurRadius > 30 ? 30 : blurRadius
        radius = radius >= 0 ? radius : 0
        return .modifier(active: Wipe(angle: angle, animatableData: AnimatablePair(0, radius)),
                         identity: Wipe(angle: angle, animatableData: AnimatablePair(1, radius)))
    }
}

extension CGSize {
    /// The larger of the two boxes that contain this size rotated by `angle` (0x100050638).
    func boundingSize(at angle: Angle) -> CGSize {
        var theta = CGFloat(angle.radians)
        let sizeA = CGSize(width: abs(width * cos(theta) + height * sin(theta)),
                           height: abs(width * sin(theta) + height * cos(theta)))
        theta += .pi / 2
        let sizeB = CGSize(width: abs(width * sin(theta) + height * cos(theta)),
                           height: abs(width * cos(theta) + height * sin(theta)))
        return sizeB.width * sizeB.height < sizeA.width * sizeA.height ? sizeA : sizeB
    }
}

/// animatableData is (progress 0...1, blur radius).
private struct Wipe: AnimatableModifier {
    var angle: Angle
    var animatableData: AnimatablePair<CGFloat, CGFloat>

    func body(content: Content) -> some View {
        content.mask(
            // closure #1 in Wipe.body(content:) (0x10004f8cc): the edge gets sharper as the wipe completes.
            GeometryReader { proxy in
                mask(size: proxy.size)
                    .blur(radius: animatableData.second * (1 - animatableData.first))
                    .compositingGroup()
            }
            .padding(-animatableData.second)
            .animation(nil, value: animatableData)
        )
    }

    // 0x10004fcbc
    func mask(size: CGSize) -> some View {
        let rect = CGRect(origin: .zero, size: size)
        let bounds = size.boundingSize(at: angle)
        let maskRect = CGRect(x: rect.midX - bounds.width / 2, y: rect.midY - bounds.height / 2,
                              width: bounds.width, height: bounds.height)
        return ZStack(alignment: .leading) {
            Color.clear
            Rectangle()
                .frame(width: maskRect.width * animatableData.first)
        }
        .frame(width: maskRect.width, height: maskRect.height)
        .position(x: maskRect.midX, y: maskRect.midY)
        .rotationEffect(angle)
        .animation(nil, value: animatableData.first)
        .animation(nil, value: angle)
    }
}
