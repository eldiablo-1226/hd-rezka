import SwiftUI

/// Tab bar on iPhone, ContentViewIpad otherwise (0x1000891a8; tabs 0x100089784, legacy tabs 0x10008a6b8).
struct ContentView: View {
    @Binding var isPresented: Bool
    @Binding var id: String

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            if #available(iOS 26, *) {
                AnyView(TabView {
                    Tab("Home", systemImage: "house") {
                        HomeView(isPresented: $isPresented, id: $id)
                    }
                    Tab("key_catalog", systemImage: "square.grid.2x2.fill") {
                        CollectionsView(isPresented: $isPresented, id: $id)
                    }
                    Tab("key_profile", systemImage: "person.circle.fill") {
                        ProfileView(isPresentedDetail: $isPresented, id: $id)
                    }
                    Tab(role: .search) {
                        SearchView(isPresented: $isPresented, id: $id)
                    }
                    .tabPlacement(.sidebarOnly)
                })
            } else {
                TabView {
                    HomeView(isPresented: $isPresented, id: $id)
                        .tabItem { Label("Home", systemImage: "house") }
                    CollectionsView(isPresented: $isPresented, id: $id)
                        .tabItem { Label("key_catalog", systemImage: "square.grid.2x2.fill") }
                    SearchView(isPresented: $isPresented, id: $id)
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    ProfileView(isPresentedDetail: $isPresented, id: $id)
                        .tabItem { Label("key_profile", systemImage: "person.circle.fill") }
                }
            }
        } else {
            ContentViewIpad(isPresented: $isPresented, id: $id)
        }
    }
}
