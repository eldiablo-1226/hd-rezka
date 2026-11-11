import CoreGraphics

/// improvement: spacing and corner radii on an 8pt grid, shared by the iPhone views and their iPad twins.
/// Only values that views use live here; add a token when a second view needs the same number.
enum DesignTokens {
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space16: CGFloat = 16
    static let space24: CGFloat = 24

    /// Concentric with `radiusPoster` at a `space4` inset.
    static let radiusBadge: CGFloat = 4
    static let radiusPoster: CGFloat = 8
    static let radiusButton: CGFloat = 12
}
