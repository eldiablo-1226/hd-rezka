import SwiftUI
import UIKit

/// One part of a franchise, as an artist's albums in Music's library: another part is a row that opens its page (the
/// name in `.primary`, a tertiary chevron, all of the row a 44 pt target); the part on screen opens nothing and is
/// `.secondary` with a checkmark. critique r4: 1.6.0 greyed the links, with nothing to say they open a page, and set
/// the current part, which goes nowhere, in the darkest text of the section (0x10007afc4).
struct FranchiseRowView: View {
    var item: MovieFranchisePart
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if !item.current {
            NavigationLink(destination: DetailsView(id: item.id)) {
                row
            }
            .buttonStyle(.plain)
            // As the iPad sidebar's links: a pointer highlights the row.
            .hoverEffect(.highlight)
        } else {
            row
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isSelected)
        }
        if item.position != 1 {
            Divider()
        }
    }

    private var row: some View {
        HStack(spacing: DesignTokens.space16) {
            Text(verbatim: item.position.description)
                .bold()
                .monospacedDigit()
                .foregroundStyle(item.current ? .secondary : .primary)
            // At accessibility sizes the year and rating go under the name, which keeps the width and every line it
            // needs: beside them each «Голодные игры: …» ended as «Голод-ные игр…» (DESIGN.md, The Text Style Rule).
            let stacks = typeSize.isAccessibilitySize
            let layout = stacks ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.space4))
                : AnyLayout(HStackLayout(spacing: DesignTokens.space16))
            layout {
                // The current part's name is not limited to 2 lines (0x10007afc4).
                Text(item.name)
                    .foregroundStyle(item.current ? .secondary : .primary)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                    .lineLimit(item.current || stacks ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                yearAndRating(alignment: stacks ? .leading : .center)
            }
            // Both symbols hold their place, so every row's year stands in one column.
            ZStack {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .opacity(item.current ? 0 : 1)
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                    .opacity(item.current ? 1 : 0)
            }
            .font(.subheadline.weight(.semibold))
            .accessibilityHidden(true)
        }
        .padding(.vertical, DesignTokens.space8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // closure #2 in closure #1 in closure #1 in closure #1 (0x10007bf40), shared by both branches.
    private func yearAndRating(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment) {
            Text(item.year)
                .foregroundStyle(.secondary)
                .font(.footnote)
            if let rating = item.rating {
                // improvement: the page's rating numerals (secondary, monospaced); 1.6.0 blended the accent towards
                // green by the rating, a second colour under 3:1 on white.
                Text(String(format: "%.2f", rating))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
