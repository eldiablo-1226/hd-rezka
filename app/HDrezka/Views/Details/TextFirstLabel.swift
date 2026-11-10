import SwiftUI

/// Label with the title before the icon (0x1000dfe50).
struct TextFirstLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}
