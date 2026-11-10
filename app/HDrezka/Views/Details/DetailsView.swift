import SwiftUI

struct DetailsView: View {
    var id: String

    // Every movie page gets its own parser (closure #1 in DetailsView.body.getter, 0x10007caa8).
    var body: some View {
        VStack {
            if UIDevice.current.userInterfaceIdiom == .phone {
                DetailsViewComponent(id: id)
                    .environmentObject(MovieDetailsParser())
            } else {
                DetailsViewComponentIpad(id: id)
                    .environmentObject(MovieDetailsParser())
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
