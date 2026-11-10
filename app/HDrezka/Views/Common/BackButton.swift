import SwiftUI

/// 0x100087aa8…0x1000888d0.
struct BackButton: View {
    var color: Color
    @Environment(\.presentationMode) var presentationMode
    @State var hasBeenShownAtLeastOnce: Bool = false

    var body: some View {
        if presentationMode.wrappedValue.isPresented || hasBeenShownAtLeastOnce {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .circleButtonLabel(color: color)
            }
            .onAppear { hasBeenShownAtLeastOnce = true }
        }
    }
}

extension Image {
    /// Label of BackButton and ShareButton (the binary merged both closures).
    func circleButtonLabel(color: Color) -> some View {
        resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 18, alignment: .leading)
            .foregroundColor(color)
            .padding(.horizontal, 18)
            .font(.system(size: 16, weight: .semibold))
            .background(alignment: .center) {
                Circle()
                    .frame(height: 30)
                    .foregroundStyle(.ultraThinMaterial)
            }
    }
}
