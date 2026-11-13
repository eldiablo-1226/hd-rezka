import SwiftUI

/// iPad root (0x10010cbac): sidebar tabs on iOS 18+, a NavigationSplitView before.
/// The Home destinations get their own fresh Network, as in the binary.
struct ContentViewIpad: View {
    @Binding var tab: AppTab
    @Binding var links: TabLinks
    /// Home's own Network, kept for the tab's life: a tab switch redraws this view now, and a Network made in the body
    /// came up empty each time.
    @StateObject private var homeNetwork = Network()

    var body: some View {
        if #available(iOS 18, *) {
            AnyView(TabView(selection: $tab) {
                Tab("Home", systemImage: "house", value: AppTab.home) {
                    HomeViewIpad(isPresented: $links.home.isPresented, id: $links.home.id)
                        .environmentObject(homeNetwork)
                }
                Tab("key_catalog", systemImage: "square.grid.2x2.fill", value: AppTab.catalog) {
                    CollectionsViewIpad(isPresented: $links.catalog.isPresented, id: $links.catalog.id)
                }
                Tab("key_profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                    ProfileView(isPresentedDetail: $links.profile.isPresented, id: $links.profile.id)
                }
                Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                    SearchView(isPresented: $links.search.isPresented, id: $links.search.id)
                }
                .tabPlacement(.pinned)
            })
        } else {
            // A split view shows one section at a time and has no tab selection: its sections share Home's link, so a
            // link opens in whichever section is on screen.
            NavigationSplitView {
                HStack {
                    VStack {
                        List {
                            NavigationLink {
                                HomeViewIpad(isPresented: $links.home.isPresented, id: $links.home.id)
                                    .environmentObject(Network())
                            } label: {
                                Label("Home", systemImage: "house")
                            }
                            .hoverEffect(.highlight)
                            NavigationLink {
                                CollectionsViewIpad(isPresented: $links.home.isPresented, id: $links.home.id)
                            } label: {
                                Label("key_catalog", systemImage: "square.grid.2x2.fill")
                            }
                            .hoverEffect(.highlight)
                            NavigationLink {
                                SearchView(isPresented: $links.home.isPresented, id: $links.home.id)
                            } label: {
                                Label("Search", systemImage: "magnifyingglass")
                            }
                            .hoverEffect(.highlight)
                            NavigationLink {
                                ProfileView(isPresentedDetail: $links.home.isPresented, id: $links.home.id)
                            } label: {
                                Label("key_profile", systemImage: "person.crop.circle")
                            }
                            .hoverEffect(.highlight)
                        }
                    }
                }
                // Verbatim Text at 0x10010da44 (no LocalizedStringKey is built).
                .navigationTitle(Text(verbatim: "HDRezka"))
            } detail: {
                HomeViewIpad(isPresented: $links.home.isPresented, id: $links.home.id)
            }
            .navigationSplitViewStyle(.automatic)
        }
    }
}
