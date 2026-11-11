import SwiftUI

struct DetailsView: View {
    var id: String
    /// improvement: «Продолжить» opens the page on its «Смотреть» half (playback starts from its button).
    var opensOnWatch = false
    /// improvement: the tapped card, shown while the page loads.
    var preview: MovieSimple? = nil

    // Every movie page gets its own parser (closure #1 in DetailsView.body.getter, 0x10007caa8).
    // improvement (Details redesign): one adaptive page for the iPhone and the iPad (1.6.0 picked a component per
    // idiom), with the system back button and swipe-back (1.6.0 hid it and drew its own).
    var body: some View {
        DetailsViewComponent(id: id, opensOnWatch: opensOnWatch, preview: preview)
            // improvement: one identity per film. A second hdr:// link into the same destination only changes `id`;
            // without this the page kept the first film's marks, half and choice.
            .id(id)
            .environmentObject(MovieDetailsParser())
    }
}
