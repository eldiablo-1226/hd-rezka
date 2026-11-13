import SwiftUI

/// Profile tab: login/register when logged out, otherwise the premium card and the account sections; the toolbar holds
/// settings (0x1000f7c78). improvement: logout moved to the end of Settings, so the first toolbar slot is no longer an
/// unlabeled destructive action. critique r2: «Загрузки» is a row of the list, signed in or not, as the library in
/// Music and Podcasts has one; it was an unlabelled arrow in the bar's far corner, beside the gear.
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
    @State private var isPresentingLogin = false
    @State private var isPresentingRegister = false

    var body: some View {
        NavigationStack {
            List {
                if isLoggedIn {
                    accountSections
                } else {
                    loginPrompt
                }
                // Files on this device need no account.
                Section {
                    NavigationLink(destination: DownloadsView()) {
                        LabeledContent {
                            downloadsValue
                        } label: {
                            Label("Downloads", systemImage: "arrow.down.circle")
                        }
                    }
                }
            }
            .navigationTitle("key_profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // improvement: a named icon (VoiceOver read the symbol's name).
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
            .navigationDestination(isPresented: $isPresentingLogin) {
                LogInView(accountService: AccountService())
            }
            .navigationDestination(isPresented: $isPresentingRegister) {
                RegisterView()
            }
            .navigationDestination(isPresented: $isPresentedDetail) {
                DetailsView(id: id)
            }
        }
    }

    /// How many files are ready to watch, and the system spinner while one is on its way.
    private var downloadsValue: some View {
        let ready = downloadManager.downloads.filter { $0.state == .completed }.count
        return HStack(spacing: DesignTokens.space8) {
            if downloadManager.hasActiveDownloads {
                ProgressView()
            }
            Text(ready, format: .number)
                .monospacedDigit()
        }
    }

    /// improvement: a system list. 1.6.0 drew a grey card per section, each with a line of description the people
    /// who use this app don't need.
    @ViewBuilder
    private var accountSections: some View {
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

    /// improvement: a row of the list over «Загрузки», so it scrolls instead of truncating at accessibility sizes. Buttons
    /// that push, not links: in a list row each styled button keeps its own tap.
    private var loginPrompt: some View {
        Section {
            VStack(spacing: DesignTokens.space8) {
                Text("key_not_logged_in")
                    .font(.title)
                    .bold()
                Text("key_login_description")
                    .multilineTextAlignment(.center)
                    .padding(.bottom, DesignTokens.space8)
                // improvement: system buttons; 1.6.0 drew its own rounded rectangle behind accent text.
                Button {
                    isPresentingLogin = true
                } label: {
                    Text("login")
                        .frame(maxWidth: 280)
                }
                .primaryButtonStyle()
                // The fill, not the tint: white on the dark-mode tint is about 3:1.
                .tint(Color("AccentFill"))
                .controlSize(.large)
                Text("Or")
                    .foregroundStyle(.secondary)
                Button {
                    isPresentingRegister = true
                } label: {
                    Text("key_register")
                        .frame(maxWidth: 280)
                }
                .secondaryButtonStyle()
                .tint(.primary)
                .controlSize(.large)
            }
            // The bordered styles before iOS 26; glass is a capsule there.
            .buttonBorderShape(.roundedRectangle(radius: DesignTokens.radiusButton))
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }
}
