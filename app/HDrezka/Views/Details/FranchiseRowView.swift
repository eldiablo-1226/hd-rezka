import SwiftUI
import UIKit

struct FranchiseRowView: View {
    var item: MovieFranchisePart

    // The other parts open their page; the current one is plain and its name is not limited to 2 lines (0x10007afc4).
    var body: some View {
        if !item.current {
            NavigationLink(destination: DetailsView(id: item.id)) {
                VStack(alignment: .leading) {
                    HStack(spacing: 10) {
                        position
                        VStack(alignment: .leading, spacing: 4) {
                            name
                                .lineLimit(2)
                        }
                        Spacer()
                        yearAndRating
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading) {
                HStack(spacing: 10) {
                    position
                    VStack(alignment: .leading, spacing: 4) {
                        name
                    }
                    Spacer()
                    yearAndRating
                }
            }
        }
        if item.position != 1 {
            Divider()
                .padding(.horizontal)
        }
    }

    private var position: some View {
        Text(verbatim: item.position.description)
            .bold()
    }

    private var name: some View {
        Text(item.name)
            .foregroundStyle(item.current ? .primary : .secondary)
            .fontWeight(.medium)
            .multilineTextAlignment(.leading)
    }

    // closure #2 in closure #1 in closure #1 in closure #1 (0x10007bf40), shared by both branches.
    private var yearAndRating: some View {
        VStack {
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
