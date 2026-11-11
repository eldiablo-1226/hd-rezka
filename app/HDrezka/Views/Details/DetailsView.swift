import SwiftUI

struct DetailsView: View {
    var id: String
    /// improvement: «Продолжить» opens the page on its «Смотреть» half (playback starts from its button).
    var opensOnWatch = false

    // Every movie page gets its own parser (closure #1 in DetailsView.body.getter, 0x10007caa8).
    // improvement (Details redesign): one adaptive page for the iPhone and the iPad (1.6.0 picked a component per
    // idiom), with the system back button and swipe-back (1.6.0 hid it and drew its own).
    var body: some View {
        DetailsViewComponent(id: id, opensOnWatch: opensOnWatch)
            .environmentObject(MovieDetailsParser())
    }
}
