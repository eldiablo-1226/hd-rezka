import SwiftUI

/// Shares the film open in DetailsView (`SharedFilmId.id`) as a site link, an hdr:// link or both (0x10010f254…0x11168c).
struct ShareButton: View {
    @AppStorage("shareMenuVariation") var shareMenuVariation: ShareMenuVariation = .url
    @Environment(\.presentationMode) var presentationMode
    @State var hasBeenShownAtLeastOnce: Bool = false

    var body: some View {
        if presentationMode.wrappedValue.isPresented || hasBeenShownAtLeastOnce {
            switch shareMenuVariation {
            case .selectOption:
                Menu {
                    ShareLink(item: URL(string: Self.siteLink(SharedFilmId.id))!) {
                        Text("key_share+with+url")
                    }
                    ShareLink(item: URL(string: Self.universalLink(SharedFilmId.id))!) {
                        Text("key_share+with+universal+link")
                    }
                } label: {
                    label
                }
                .onAppear { hasBeenShownAtLeastOnce = true }
            case .url:
                ShareLink(item: URL(string: Self.siteLink(SharedFilmId.id))!) { label }
                    .onAppear { hasBeenShownAtLeastOnce = true }
            case .universalLink:
                ShareLink(item: URL(string: Self.universalLink(SharedFilmId.id))!) { label }
                    .onAppear { hasBeenShownAtLeastOnce = true }
            }
        }
    }

    // improvement: the bare symbol; the toolbar draws the button. 1.6.0 put it in its own grey circle, which on
    // iOS 26 sat inside the system's glass capsule.
    private var label: some View {
        Image(systemName: "square.and.arrow.up")
            .accessibilityLabel(Text("key_share"))
    }

    /// The page on the public domain: "https://ijobs.app/films/x/1-y.html" -> "https://rezka.ag/films/x/1-y.html".
    static func siteLink(_ filmURL: String) -> String {
        filmURL.replacingOccurrences(of: "ijobs.app", with: "rezka.ag")
    }

    /// "https://<mirror>/films/x/1-y.html" -> "hdr://films/x/1-y" (opened again by HDRezkaApp.onOpenURL).
    static func universalLink(_ filmURL: String) -> String {
        "hdr://" + filmURL.removeMirror().replacingOccurrences(of: ".html", with: "")
    }
}
