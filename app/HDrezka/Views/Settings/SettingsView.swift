import SwiftUI

/// Settings root: links to the sub-pages, the debug page once unlocked, and the Telegram channel (0x100057b94).
struct SettingsView: View {
    @Binding var settingStore: String
    @Binding var remoteVersion: String
    @Binding var isHidingNotch: Bool
    @Binding var useInfuse: Bool
    @Binding var showVotesCount: Bool
    @Binding var shareMenuVariation: ShareMenuVariation
    @Binding var startupPageVariation: StartupPageVariation
    @Binding var backgroundUrlSession: Bool
    @Binding var allowDebug: Bool
    @Binding var autoplayNextEpisode: Bool
    @Binding var preferredQuality: PlayerQualityPreference
    @Binding var saveHistory: Bool
    @Binding var preferOriginalTitle: Bool
    @Binding var downloadDestination: DownloadDestination
    @Environment(\.openURL) var openURL

    var body: some View {
        NavigationStack {
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
                        NavigationLink(destination: AboutUsView(allowDebug: $allowDebug)) {
                            Label("about_app_settings", systemImage: "heart")
                        }
                        if allowDebug {
                            NavigationLink(destination: DebugSettingsView(mirror: $settingStore, allowDebug: $allowDebug)) {
                                // Not localized: the binary uses the StringProtocol initializer.
                                Label("Debug" as String, systemImage: "gear.badge.xmark")
                            }
                        }
                        Button {
                            openURL(URL(string: "https://t.me/apphdrios")!)
                        } label: {
                            Label("key_telegram+channel", systemImage: "paperplane")
                        }
                    }
                }
                Spacer()
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}
