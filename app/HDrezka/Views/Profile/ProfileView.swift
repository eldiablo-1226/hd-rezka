import SwiftUI

/// Profile tab: login/register when logged out, otherwise the premium card and the account sections;
/// the toolbar holds logout, downloads and settings (0x1000f7c78).
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
    @AppStorage("background_url_session") var backgroundUrlSession: Bool = false
    @AppStorage("allowDebug") var allowDebug: Bool = false
    @AppStorage("autoplayNextEpisode") var autoplayNextEpisode: Bool = true
    @AppStorage("preferredQuality") var preferredQuality: PlayerQualityPreference = .ask
    @AppStorage("saveHistory") var saveHistory: Bool = true
    @AppStorage("preferOriginalTitle") var preferOriginalTitle: Bool = false
    @AppStorage("downloadDestination") var downloadDestination: DownloadDestination = .app
    @Binding var isPresentedDetail: Bool
    @Binding var id: String
    @State var isPresented: Bool = false
    @EnvironmentObject var downloadManager: DownloadManager

    var body: some View {
        NavigationStack {
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
                        NavigationLink(destination: LogInView(accountService: AccountService())) {
                            Label("login", systemImage: "door.left.hand.open")
                                .labelStyle(TextFirstLabel())
                                .foregroundStyle(Color(.accent))
                                .padding(10)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .foregroundStyle(.quaternary)
                                }
                        }
                        .buttonStyle(.plain)
                        Text("Or")
                            .padding(.vertical, 8)
                        NavigationLink(destination: RegisterView()) {
                            Label("key_register", systemImage: "chevron.right")
                                .foregroundStyle(Color(.accent))
                        }
                        .labelStyle(TextFirstLabel())
                    }
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
                        AccountCardViewComponent(name: "key_series_updates", desc: "key_series_updates_description", image: "stopwatch")
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 10)
                    Spacer()
                }
            }
            .padding()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isLoggedIn {
                        Button {
                            isPresented.toggle()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .alert("key_logout_description", isPresented: $isPresented) {
                            Button("key_no", role: .cancel) {}
                            Button("key_yes", role: .destructive) {
                                // The session cookie is dropped by the site's answer to GET /logout;
                                // the binary does no cookie work of its own (no HTTPCookieStorage use outside Alamofire).
                                Task {
                                    try await AccountService().logout()
                                }
                                isLoggedIn = false
                            }
                        }
                    }
                    NavigationLink(destination: DownloadsView()) {
                        Image(systemName: "arrow.down.circle")
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
                            allowDebug: $allowDebug,
                            autoplayNextEpisode: $autoplayNextEpisode,
                            preferredQuality: $preferredQuality,
                            saveHistory: $saveHistory,
                            preferOriginalTitle: $preferOriginalTitle,
                            downloadDestination: $downloadDestination)) {
                        Image(systemName: "gear")
                    }
                }
            }
            .navigationDestination(isPresented: $isPresentedDetail) {
                DetailsView(id: id)
            }
        }
    }
}
