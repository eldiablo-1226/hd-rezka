import SwiftUI

/// 0x100057870.
struct HomeViewIpad: View {
    @Binding var isPresented: Bool
    @Binding var id: String

    var body: some View {
        VStack {
            HomeGridViewIpad(isPresented: $isPresented, id: $id)
                .preferredColorScheme(nil)
        }
    }
}
