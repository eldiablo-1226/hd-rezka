import SwiftUI

/// «Каталог» tab (iPhone; 1.6.0: Collections): the list with a fresh parser (0x100086d54).
struct CollectionsView: View {
    @Binding var isPresented: Bool
    @Binding var id: String

    var body: some View {
        CollectionsListViewComponent(isPresented: $isPresented, id: $id)
            .environmentObject(CollectionsParser())
    }
}
