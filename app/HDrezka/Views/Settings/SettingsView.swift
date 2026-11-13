import SwiftUI

/// Settings root: links to the sub-pages (0x100057b94).
/// improvement: no «О приложении» (the original developers' credits and the debug unlock), no debug page and no link to
/// the original app's Telegram channel: this build carries nothing of the decompiled app's authorship.
struct SettingsView: View {
    @Binding var settingStore: String
    @Binding var remoteVersion: String
    @Binding var isHidingNotch: Bool
    @Binding var useInfuse: Bool
    @Binding var showVotesCount: Bool
    @Binding var shareMenuVariation: ShareMenuVariation
    @Binding var startupPageVariation: StartupPageVariation
    @Binding var backgroundUrlSession: Bool
    @Binding var autoplayNextEpisode: Bool
    @Binding var preferredQuality: PlayerQualityPreference
    @Binding var saveHistory: Bool
    @Binding var preferOriginalTitle: Bool
    @Binding var downloadDestination: DownloadDestination
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @State var isConfirmingLogout: Bool = false

    var body: some View {
        // improvement: no NavigationStack of its own; the screen is pushed onto Profile's stack.
        Group {
            VStack {
                Form {
                    Section {
                        NavigationLink(destination: AppearanceSettingsView(showVotesCount: $showVotesCount, preferOriginalTitle: $preferOriginalTitle)) {
                            Label("key_appearance", systemImage: "paintbrush.pointed")
                        }
                        NavigationLink(destination:
                            PlayerSettingsView(
                                hideNotch: $isHidingNotch,
                                useInfuse: $useInfuse,
                                autoplayNextEpisode: $autoplayNextEpisode,
                                preferredQuality: $preferredQuality)) {
                            Label("key_player", systemImage: "rectangle.inset.filled.and.person.filled")
                        }
                        NavigationLink(destination:
                            BehaviorSettingsView(
                                backgroundUrlSession: $backgroundUrlSession,
                                saveHistory: $saveHistory,
                                shareMenuVariation: $shareMenuVariation,
                                startupPageVariation: $startupPageVariation,
                                downloadDestination: $downloadDestination)) {
                            Label("key_behavior", systemImage: "slider.horizontal.3")
                        }
                        // improvement: the mirror outside the debug page; the error screens open the same view.
                        NavigationLink(destination: MirrorSettingsView()) {
                            LabeledContent {
                                Text(settingStore)
                            } label: {
                                Label("key_mirror", systemImage: "network")
                            }
                        }
                    }
                    // improvement: logout here, at the end, instead of the first icon of the Profile toolbar.
                    if isLoggedIn {
                        Section {
                            Button("key_logout", role: .destructive) {
                                isConfirmingLogout = true
                            }
                            .confirmationDialog("key_logout_description", isPresented: $isConfirmingLogout, titleVisibility: .visible) {
                                Button("key_logout", role: .destructive) {
                                    // AccountNetwork.logout drops the session cookies, then sends GET /logout with them.
                                    Task {
                                        try? await AccountService().logout()
                                    }
                                    isLoggedIn = false
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationTitle("key_settings")
        }
    }
}
