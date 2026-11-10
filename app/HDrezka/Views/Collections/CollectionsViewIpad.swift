import SwiftUI

/// Collections tab (iPad): the list with a fresh parser (0x1000a95d4).
struct CollectionsViewIpad: View {
    @Binding var isPresented: Bool
    @Binding var id: String

    var body: some View {
        CollectionsListViewComponentIpad(isPresented: $isPresented, id: $id)
            .environmentObject(CollectionsParser())
    }
}
