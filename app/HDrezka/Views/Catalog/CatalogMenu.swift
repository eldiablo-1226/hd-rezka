import SwiftUI

/// improvement: the site's header menu over the collections, in the site's order: the four sections, Новинки, Анонсы.
/// Rows like Music's library: an ember symbol, the name in title3, a chevron, dividers under the names.
struct CatalogMenu: View {
    @ScaledMetric(relativeTo: .title3) private var symbolWidth: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            ForEach(SiteMenu.sections) { section in
                row(section.titleKey, symbol: section.symbol) {
                    CatalogSectionView(section: section)
                }
                divider
            }
            row("key_new", symbol: "flame") {
                CatalogListingView(title: NSLocalizedString("key_new", comment: ""), path: SiteMenu.new)
            }
            divider
            row("key_announce", symbol: "calendar") {
                CatalogListingView(title: NSLocalizedString("key_announce", comment: ""), path: SiteMenu.announce)
            }
        }
    }

    private var divider: some View {
        Divider().padding(.leading, symbolWidth + DesignTokens.space16)
    }

    private func row<Destination: View>(_ titleKey: String, symbol: String,
                                        @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: DesignTokens.space16) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: symbolWidth)
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(titleKey))
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: DesignTokens.space8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DesignTokens.space8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // As the iPad sidebar's links: a pointer highlights the row.
        .hoverEffect(.highlight)
    }
}

/// «Подборки», the menu's last item, heads the tab's grid of collections, in the weight of Home's listing name.
struct CollectionsHeader: View {
    var body: some View {
        Text("key_collections")
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignTokens.space24)
            .accessibilityAddTraits(.isHeader)
    }
}
