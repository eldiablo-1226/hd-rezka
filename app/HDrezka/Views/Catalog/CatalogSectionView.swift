import SwiftUI

/// improvement: a dropdown of the site's header as a list: the whole section and its «Лучшие новинки», «Найти лучшие»
/// with the site's genre and year pickers, the studios, then every genre, in the site's order.
struct CatalogSectionView: View {
    let section: SiteSection
    @State private var bestGenre: SiteLink?
    @State private var bestYear = 0

    var body: some View {
        let year = SiteMenu.currentYear()
        List {
            Section {
                NavigationLink {
                    CatalogListingView(title: NSLocalizedString(section.titleKey, comment: ""), path: section.path)
                } label: {
                    Label(LocalizedStringKey(section.allKey), systemImage: section.symbol)
                }
                NavigationLink {
                    CatalogListingView(title: NSLocalizedString(section.bestKey, comment: ""), subtitle: String(year),
                                       path: section.bestPath(genre: nil, year: year))
                } label: {
                    LabeledContent {
                        Text(verbatim: String(year))
                    } label: {
                        Label("key_best_new", systemImage: "flame")
                    }
                }
            }
            Section(LocalizedStringKey(section.findBestKey)) {
                Picker("key_genre", selection: $bestGenre) {
                    Text("key_any_genre").tag(SiteLink?.none)
                    // By value: Фильмы lists «Мюзиклы» and «Музыкальные» under one path.
                    ForEach(section.genres, id: \.self) { genre in
                        Text(genre.name).tag(Optional(genre))
                    }
                }
                Picker("key_year", selection: $bestYear) {
                    Text("key_all_time").tag(0)
                    ForEach(SiteMenu.years(), id: \.self) { year in
                        Text(verbatim: String(year)).tag(year)
                    }
                }
                NavigationLink("key_show") {
                    CatalogListingView(title: NSLocalizedString(section.bestKey, comment: ""), subtitle: bestSubtitle,
                                       path: section.bestPath(genre: bestGenre, year: bestYear))
                }
                // «Показать» alone says nothing from the rotor or Voice Control.
                .accessibilityHint(Text(LocalizedStringKey(section.findBestKey)))
            }
            .pickerStyle(.menu)
            Section("key_studios") {
                ForEach(section.studios, id: \.self) { studio in
                    NavigationLink(studio.name) {
                        CatalogListingView(title: studio.title ?? studio.name, path: studio.path)
                    }
                }
            }
            Section("key_genres") {
                ForEach(section.genres, id: \.self) { genre in
                    NavigationLink(genre.name) {
                        CatalogListingView(title: genre.name, path: genre.path)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey(section.titleKey))
    }

    /// «Драмы · 2026»; nil for any genre of all time.
    private var bestSubtitle: String? {
        let parts = [bestGenre?.name, bestYear > 0 ? String(bestYear) : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
