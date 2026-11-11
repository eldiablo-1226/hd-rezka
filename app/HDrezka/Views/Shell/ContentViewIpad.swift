import SwiftUI

/// iPad root (0x10010cbac): sidebar tabs on iOS 18+, a NavigationSplitView before.
/// The Home destinations get their own fresh Network, as in the binary.
struct ContentViewIpad: View {
    @Binding var isPresented: Bool
    @Binding var id: String

    var body: some View {
        if #available(iOS 18, *) {
            AnyView(TabView {
                Tab("Home", systemImage: "house") {
                    HomeViewIpad(isPresented: $isPresented, id: $id)
                        .environmentObject(Network())
                }
                Tab("key_catalog", systemImage: "square.grid.2x2.fill") {
                    CollectionsViewIpad(isPresented: $isPresented, id: $id)
                }
                Tab("key_profile", systemImage: "person.crop.circle") {
                    ProfileView(isPresentedDetail: $isPresented, id: $id)
                }
                Tab("Search", systemImage: "magnifyingglass") {
                    SearchView(isPresented: $isPresented, id: $id)
                }
                .tabPlacement(.pinned)
            })
        } else {
            NavigationSplitView {
                HStack {
                    VStack {
                        List {
                            NavigationLink {
                                HomeViewIpad(isPresented: $isPresented, id: $id)
                                    .environmentObject(Network())
                            } label: {
                                Label("Home", systemImage: "house")
                            }
                            .hoverEffect(.highlight)
                            NavigationLink {
                                CollectionsViewIpad(isPresented: $isPresented, id: $id)
                            } label: {
                                Label("key_catalog", systemImage: "square.grid.2x2.fill")
                            }
                            .hoverEffect(.highlight)
                            NavigationLink {
                                SearchView(isPresented: $isPresented, id: $id)
                            } label: {
                                Label("Search", systemImage: "magnifyingglass")
                            }
                            .hoverEffect(.highlight)
                            NavigationLink {
                                ProfileView(isPresentedDetail: $isPresented, id: $id)
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
                HomeViewIpad(isPresented: $isPresented, id: $id)
            }
            .navigationSplitViewStyle(.automatic)
        }
    }
}
