import SwiftUI

/// improvement (critique r2): «Все» at the end of a row's header opens its whole list, as the App Store and Music head
/// their rows. One word everywhere, with a 44 pt target: Home said «Все» and a person «больше», each the size of its
/// text, in the corner farthest from the thumb.
struct SeeAllLink<Destination: View>: View {
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            Text("key_all")
                .font(.subheadline.weight(.medium))
                // The word stays on the margin; the target grows away from it.
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
    }
}
