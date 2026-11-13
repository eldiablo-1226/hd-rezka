import SwiftUI

@main
struct HDRezkaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var downloadManager = DownloadManager.shared
    var network = Network()

    /// 0x1000fe7ac. improvement (critique r1): an hdr:// link opens its title in the tab on screen (ContentView); 1.6.0's
    /// onOpenURL (0x1000feaa0) set an isPresented/id shared by every tab.
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(network)
                .environmentObject(downloadManager)
        }
    }

    /// "hdr://films/x/1-y" (ShareButton.universalLink) -> "https://ijobs.app/films/x/1-y.html"; nil for a bare "hdr://".
    /// The host is hard-coded in the binary, not the mirror setting.
    static func filmURL(fromDeepLink url: URL) -> String? {
        guard !url.description.replacingOccurrences(of: "hdr://", with: "").isEmpty else { return nil }
        return url.description.replacingOccurrences(of: "hdr://", with: "https://ijobs.app/") + ".html"
    }
}
