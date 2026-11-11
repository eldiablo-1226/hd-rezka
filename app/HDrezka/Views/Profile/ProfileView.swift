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
            Group {
                if isLoggedIn {
                    accountList
                } else {
                    loginPrompt
                }
            }
            .navigationTitle("key_profile")
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

    /// improvement: a system list. 1.6.0 drew a grey card per section, each with a line of description the people
    /// who use this app don't need.
    private var accountList: some View {
        List {
            if let status = PremiumStatus(raw: hasPremium) {
                Section {
                    PremiumCard(status: status)
                }
            }
            Section {
                NavigationLink(destination: WatchLaterView().environmentObject(AccountParser())) {
                    Label("key_watch_later", systemImage: "clock")
                }
                NavigationLink(destination: BookmarksView().environmentObject(AccountParser())) {
                    Label("key_bookmarks", systemImage: "bookmark")
                }
                NavigationLink(destination: SeriesUpdateView()) {
                    // improvement: a plain bell; bell.badge drew a "new" dot whether or not a series had new episodes.
                    Label("key_series_updates", systemImage: "bell")
                }
            }
        }
    }

    // improvement: scrolls instead of truncating at accessibility sizes; the minimum height keeps it centred.
    private var loginPrompt: some View {
        GeometryReader { proxy in
            ScrollView {
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
                    .primaryButtonStyle()
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
                    .secondaryButtonStyle()
                    .tint(.primary)
                    .controlSize(.large)
                }
                // The bordered styles before iOS 26; glass is a capsule there.
                .buttonBorderShape(.roundedRectangle(radius: DesignTokens.radiusButton))
                .padding()
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}
