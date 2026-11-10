import SwiftUI

/// Shares the film open in DetailsView (`SharedFilmId.id`) as a site link, an hdr:// link or both (0x10010f254…0x11168c).
struct ShareButton: View {
    var color: Color
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

    private var label: some View {
        Image(systemName: "square.and.arrow.up").circleButtonLabel(color: color)
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
