import SwiftUI

/// Behavior page: download destination and background session (locked while downloads run),
/// share menu type, startup page, watch history (0x1000e3658).
struct BehaviorSettingsView: View {
    @Binding var backgroundUrlSession: Bool
    @Binding var saveHistory: Bool
    @Binding var shareMenuVariation: ShareMenuVariation
    @Binding var startupPageVariation: StartupPageVariation
    @Binding var downloadDestination: DownloadDestination
    @EnvironmentObject var downloadManager: DownloadManager

    var body: some View {
        // improvement: no NavigationStack of its own; the screen is pushed onto Profile's stack.
        Group {
            VStack {
                Form {
                    Section(header: Label("key_downloads_settings_footer", systemImage: "square.and.arrow.down"),
                            footer: Text("key_background_url_session+description")) {
                        Picker("key_download_destination", selection: $downloadDestination) {
                            ForEach(DownloadDestination.allCases) { destination in
                                Text(destination.displayName)
                                    .tag(destination)
                            }
                        }
                        .disabled(downloadManager.hasActiveDownloads)
                        Toggle(isOn: $backgroundUrlSession) {
                            Text("key_background_url_session")
                        }
                        .disabled(downloadManager.hasActiveDownloads)
                    }
                    Section(header: Label("key_share_menu_header", systemImage: "square.and.arrow.up"),
                            footer: Text("key_shareMenuVariation+description")) {
                        Picker("key_shareMenuVariation", selection: $shareMenuVariation) {
                            Text("key_shareMenuVariation+selectOption")
                                .tag(ShareMenuVariation.selectOption)
                            Text("key_share+with+url")
                                .tag(ShareMenuVariation.url)
                            Text("key_share+with+universal+link")
                                .tag(ShareMenuVariation.universalLink)
                        }
                    }
                    Section(header: Label("key_startup_page", systemImage: "square.grid.2x2"),
                            footer: Text("key_startup_page_footer")) {
                        Picker("key_startup_page", selection: $startupPageVariation) {
                            Text("Now watching")
                                .tag(StartupPageVariation.watching)
                            Text("key_last_releases")
                                .tag(StartupPageVariation.last)
                            Text("key_popular")
                                .tag(StartupPageVariation.popular)
                            Text("key_comingsoon")
                                .tag(StartupPageVariation.soon)
                        }
                    }
                    Section(header: Label("key_section.history", systemImage: "clock"),
                            footer: Text("key_section.history.footer")) {
                        Toggle(isOn: $saveHistory) {
                            Text("key_save_history")
                        }
                    }
                }
            }
            .navigationTitle("key_behavior")
        }
    }
}
