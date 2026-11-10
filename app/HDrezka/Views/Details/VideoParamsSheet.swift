import SwiftUI
import Alamofire

/// "Watch" sheet: voice acting / season / episode pickers, then the quality list (body 0x1000a25fc).
/// `id` is the title page URL: the sheet loads that page again with its own parser.
struct VideoParamsSheet: View {
    var id: String
    @AppStorage("useInfuse") var useInfuse: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("hasPremium") var hasPremium: String = ""
    @AppStorage("remoteVersion") var remoteVersion: String = ""
    @State var seasons: [MovieSeason]? = nil
    @State var voiceActing: [MovieVoiceActing]? = nil
    @State var selectedActing: MovieVoiceActing = MovieVoiceActing(id: "", name: "", translatorId: "", isCamrip: "", isAds: "", isDirector: "", isSelected: false, isPremium: false, url: nil)
    @State var premiumActings: [MovieVoiceActing]? = nil
    @State var nonPremiumActings: [MovieVoiceActing]? = nil
    @State var selectedSeason: MovieSeason = MovieSeason(id: "", name: "", episodes: [], isSelected: false, url: nil)
    @State var selectedEpisode: MovieEpisode = MovieEpisode(id: "", name: "", isSelected: false, url: nil)
    @State var canProceed: Bool = false
    @Binding var coverData: CoverData?
    @Binding var video: String
    @Environment(\.dismiss) var dismiss
    @StateObject var detailsNetwork = MovieDetailsParser()
    @EnvironmentObject var detailService: MovieDetailsService

    var body: some View {
        if detailsNetwork.movieDetailed.isEmpty {
            ProgressView()
                .progressViewStyle(.circular)
                .onAppear {
                    // closure #1 (0x1000a2af8): GET with only the two app headers, no Content-Type.
                    AF.request(id, method: .get, headers: ["X-Hdrezka-Ios-App": "1", "X-Hdrezka-Ios-App-Version": remoteVersion])
                        .responseString { response in
                            Task { @MainActor in
                                if let html = response.value {
                                    let details = try detailsNetwork.parseMovieDetails(html: html, movieId: id)
                                    voiceActing = details[0].voiceActing
                                    seasons = details[0].seasons
                                }
                            }
                        }
                }
        } else {
            NavigationStack {
                VStack {
                    Form {
                        // Section.init(footer:content:) at 0x1000a3bbc: the reminder is the pickers' footer, not a Form row.
                        Section(footer: useInfuse ? Text("key_infuse_reminder").font(.footnote).foregroundStyle(.secondary) : nil) {
                            Picker("voice acting", selection: $selectedActing) {
                                if let premiumActings {
                                    Section(header: Text(verbatim: "Premium")) {
                                        ForEach(premiumActings, id: \.name) { acting in
                                            Text(acting.name).tag(acting)
                                        }
                                    }
                                }
                                if let nonPremiumActings {
                                    Section {
                                        ForEach(nonPremiumActings, id: \.name) { acting in
                                            Text(acting.name).tag(acting)
                                        }
                                    }
                                }
                            }
                            if seasons != nil {
                                Picker("season", selection: $selectedSeason) {
                                    ForEach(seasons!, id: \.name) { season in
                                        Text(season.name).tag(season)
                                    }
                                }
                                Picker("episode", selection: $selectedEpisode) {
                                    ForEach(selectedSeason.episodes, id: \.self) { episode in
                                        Text(episode.name).tag(episode)
                                    }
                                }
                            }
                        }
                        NavigationLink {
                            if selectedActing.isPremium && hasPremium.isEmpty {
                                PremiumUnavailableView()
                            } else if seasons != nil {
                                QualitySelectionSheet(id: id, selectedActing: selectedActing, selectedSeason: selectedSeason,
                                                      selectedEpisode: selectedEpisode, video: $video, dismiss: dismiss, coverData: $coverData)
                            } else {
                                QualitySelectionSheet(id: id, selectedActing: selectedActing, selectedSeason: nil,
                                                      selectedEpisode: nil, video: $video, dismiss: dismiss, coverData: $coverData)
                            }
                        } label: {
                            Text("key_watch")
                                .foregroundStyle(Color(.accent))
                                .font(.headline)
                                .frame(maxWidth: UIScreen.main.bounds.width / 1.2, maxHeight: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationBarTitle("key_watch", displayMode: .inline)
                .onAppear {
                    nonPremiumActings = voiceActing?.getNonPremiumActingList(actingList: voiceActing!)
                    premiumActings = voiceActing?.getPremiumActingList(actingList: voiceActing!)
                    if let acting = voiceActing!.first(where: { $0.isSelected }) {
                        selectedActing = acting
                    }
                    if seasons != nil {
                        if let season = seasons!.first(where: { $0.isSelected }) {
                            selectedSeason = season
                        }
                        if let episode = selectedSeason.episodes.first(where: { $0.isSelected }) {
                            selectedEpisode = episode
                        }
                    }
                    // The onChange handlers below must not react to this initial selection.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        canProceed = true
                    }
                }
                .onChange(of: selectedActing) { _ in
                    if canProceed {
                        Task { @MainActor in
                            seasons = try await detailService.getSeriesSeasons(movieId: id, voiceActing: selectedActing)
                        }
                    }
                }
                .onChange(of: selectedSeason) { _ in
                    if let episode = selectedSeason.episodes.first(where: { $0.isSelected }) {
                        selectedEpisode = episode
                    }
                }
            }
        }
    }
}

extension Array where Element == MovieVoiceActing {
    /// The receiver is unused, as in the binary (0x100076b24): callers pass the list explicitly.
    func getPremiumActingList(actingList: [MovieVoiceActing]) -> [MovieVoiceActing]? {
        actingList.filter { $0.isPremium }
    }

    /// 0x100076c64.
    func getNonPremiumActingList(actingList: [MovieVoiceActing]) -> [MovieVoiceActing]? {
        actingList.filter { !$0.isPremium }
    }
}
