import SwiftUI

/// Profile tab: login/register when logged out, otherwise the premium card and the account sections;
/// the toolbar holds downloads and settings (0x1000f7c78). improvement: logout moved to the end of Settings, so the
/// first toolbar slot is no longer an unlabeled destructive action.
struct ProfileView: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("hasPremium") var hasPremium: String = ""
    @AppStorage("mirror") var settingStore: String = DefaultSettings.mirror
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @AppStorage("hideNotch") var isHidingNotch: Bool = false
    @AppStorage("useInfuse") var useInfuse: Bool = false
    @AppStorage("showVotesCount") var showVotesCount: Bool = false
    @AppStorage("shareMenuVariation") var shareMenuVariation: ShareMenuVariation = .url
    @AppStorage("startupPageVariation") var startupPageVariation: StartupPageVariation = .watching
    @AppStorage("background_url_session") var backgroundUrlSession: Bool = true
    @AppStorage("autoplayNextEpisode") var autoplayNextEpisode: Bool = true
    @AppStorage("preferredQuality") var preferredQuality: PlayerQualityPreference = .ask
    @AppStorage("saveHistory") var saveHistory: Bool = true
    @AppStorage("preferOriginalTitle") var preferOriginalTitle: Bool = false
    @AppStorage("downloadDestination") var downloadDestination: DownloadDestination = .app
    @Binding var isPresentedDetail: Bool
    @Binding var id: String
    @EnvironmentObject var downloadManager: DownloadManager

    var body: some View {
        NavigationStack {
            // improvement: scrolls instead of truncating every card at accessibility sizes; the minimum height
            // keeps the login prompt centred and the cards at the top, as before.
            GeometryReader { proxy in
                ScrollView {
                    VStack {
                        if !isLoggedIn {
                            VStack {
                                Text("key_not_logged_in")
                                    .font(.title)
                                    .bold()
                                    .padding(5)
                                Text("key_login_description")
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom)
                                // improvement: system buttons; 1.6.0 drew its own rounded rectangle behind accent text.
                                NavigationLink(destination: LogInView(accountService: AccountService())) {
                                    Text("login")
                                        .frame(maxWidth: 280)
                                }
                                .buttonStyle(.borderedProminent)
                                // The fill, not the tint: white on the dark-mode tint is about 3:1.
                                .tint(Color("AccentFill"))
                                .controlSize(.large)
                                Text("Or")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                                NavigationLink(destination: RegisterView()) {
                                    Text("key_register")
                                        .frame(maxWidth: 280)
                                }
                                .buttonStyle(.bordered)
                                .tint(.primary)
                                .controlSize(.large)
                            }
                            // iOS 26 draws large bordered buttons as capsules; DESIGN.md keeps capsules for list chips.
                            .buttonBorderShape(.roundedRectangle(radius: DesignTokens.radiusButton))
                        } else {
                            if let status = PremiumStatus(raw: hasPremium) {
                                PremiumCard(status: status)
                                    .padding(.bottom, 10)
                            }
                            NavigationLink(destination:
                                WatchLaterView()
                                    .environmentObject(AccountParser())) {
                                AccountCardViewComponent(name: "key_watch_later", desc: "key_watch_later_description", image: "clock")
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 10)
                            NavigationLink(destination:
                                BookmarksView()
                                    .environmentObject(AccountParser())) {
                                AccountCardViewComponent(name: "key_bookmarks", desc: "key_bookmarks_description", image: "bookmark")
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 10)
                            NavigationLink(destination: SeriesUpdateView()) {
                                AccountCardViewComponent(name: "key_series_updates", desc: "key_series_updates_description", image: "bell.badge")
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 10)
                            Spacer()
                        }
                    }
                    .padding()
                    .frame(minHeight: proxy.size.height, alignment: isLoggedIn ? .top : .center)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // improvement: named icons (VoiceOver read the symbol names).
                    NavigationLink(destination: DownloadsView()) {
                        Label("Downloads", systemImage: "arrow.down.circle")
                            .labelStyle(.iconOnly)
                    }
                    NavigationLink(destination:
                        SettingsView(
                            settingStore: $settingStore,
                            remoteVersion: $remoteVersion,
                            isHidingNotch: $isHidingNotch,
                            useInfuse: $useInfuse,
                            showVotesCount: $showVotesCount,
                            shareMenuVariation: $shareMenuVariation,
                            startupPageVariation: $startupPageVariation,
                            backgroundUrlSession: $backgroundUrlSession,
                            autoplayNextEpisode: $autoplayNextEpisode,
                            preferredQuality: $preferredQuality,
                            saveHistory: $saveHistory,
                            preferOriginalTitle: $preferOriginalTitle,
                            downloadDestination: $downloadDestination)) {
                        Label("key_settings", systemImage: "gear")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .navigationDestination(isPresented: $isPresentedDetail) {
                DetailsView(id: id)
            }
        }
    }
}
