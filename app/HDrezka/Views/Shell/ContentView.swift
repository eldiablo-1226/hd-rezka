import SwiftUI

/// The tabs, so an hdr:// link knows which one is on screen.
enum AppTab: Hashable {
    case home, catalog, profile, search

    /// Its link in TabLinks.
    var link: WritableKeyPath<TabLinks, TabLinks.Link> {
        switch self {
        case .home: \.home
        case .catalog: \.catalog
        case .profile: \.profile
        case .search: \.search
        }
    }
}

/// improvement (critique r1): one hdr:// link per tab. A link opens its title in the tab on screen only, as Music and
/// Podcasts open theirs, and Back closes it there; the other tabs keep their place. 1.6.0 shared one isPresented/id
/// across the app (0x1000fe7ac), so every tab pushed and loaded its own copy of the page. `id` stays after Back, so the
/// page being popped keeps it.
struct TabLinks {
    struct Link {
        var isPresented = false
        var id = ""
    }

    var home = Link(), catalog = Link(), profile = Link(), search = Link()

    mutating func open(_ id: String, in tab: AppTab) {
        self[keyPath: tab.link] = Link(isPresented: true, id: id)
    }
}

/// Tab bar on iPhone, ContentViewIpad otherwise (0x1000891a8; tabs 0x100089784, legacy tabs 0x10008a6b8).
struct ContentView: View {
    @State private var tab = AppTab.home
    @State private var links = TabLinks()

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                if #available(iOS 26, *) {
                    AnyView(TabView(selection: $tab) {
                        Tab("Home", systemImage: "house", value: AppTab.home) {
                            HomeView(isPresented: $links.home.isPresented, id: $links.home.id)
                        }
                        Tab("key_catalog", systemImage: "square.grid.2x2.fill", value: AppTab.catalog) {
                            CollectionsView(isPresented: $links.catalog.isPresented, id: $links.catalog.id)
                        }
                        Tab("key_profile", systemImage: "person.circle.fill", value: AppTab.profile) {
                            ProfileView(isPresentedDetail: $links.profile.isPresented, id: $links.profile.id)
                        }
                        Tab(value: AppTab.search, role: .search) {
                            SearchView(isPresented: $links.search.isPresented, id: $links.search.id)
                        }
                        .tabPlacement(.sidebarOnly)
                    })
                } else {
                    TabView(selection: $tab) {
                        HomeView(isPresented: $links.home.isPresented, id: $links.home.id)
                            .tabItem { Label("Home", systemImage: "house") }
                            .tag(AppTab.home)
                        CollectionsView(isPresented: $links.catalog.isPresented, id: $links.catalog.id)
                            .tabItem { Label("key_catalog", systemImage: "square.grid.2x2.fill") }
                            .tag(AppTab.catalog)
                        SearchView(isPresented: $links.search.isPresented, id: $links.search.id)
                            .tabItem { Label("Search", systemImage: "magnifyingglass") }
                            .tag(AppTab.search)
                        ProfileView(isPresentedDetail: $links.profile.isPresented, id: $links.profile.id)
                            .tabItem { Label("key_profile", systemImage: "person.circle.fill") }
                            .tag(AppTab.profile)
                    }
                }
            } else {
                ContentViewIpad(tab: $tab, links: $links)
            }
        }
        // 1.6.0's onOpenURL (0x1000feaa0) sat on the scene and set the app-wide pair.
        .onOpenURL { url in
            if let filmURL = HDRezkaApp.filmURL(fromDeepLink: url) {
                links.open(filmURL, in: tab)
            }
        }
    }
}
