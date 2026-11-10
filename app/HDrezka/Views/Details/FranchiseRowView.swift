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
                // From the accent color (rating 0) towards green (rating 10).
                let color = Color(UIColor(resource: .accent).blended(with: .green, weight: CGFloat(rating / 10)))
                HStack(spacing: 4) {
                    Text(String(format: "%.2f", rating))
                        .foregroundStyle(color)
                        .font(.caption)
                        .bold()
                    Image(systemName: "star.fill")
                        .foregroundStyle(color)
                        .font(.caption2)
                }
            }
        }
    }
}

fileprivate extension UIColor {
    /// Per-channel RGBA mix `(1 - weight) * self + weight * other`, resolved for the current traits (0x1000dfcc0).
    func blended(with other: UIColor, weight: CGFloat) -> UIColor {
        // blend #1 (0x1000dfba8)
        func blend(_ first: UIColor, with second: UIColor, weight: CGFloat) -> UIColor {
            var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return UIColor(red: (1 - weight) * r1 + weight * r2,
                           green: (1 - weight) * g1 + weight * g2,
                           blue: (1 - weight) * b1 + weight * b2,
                           alpha: (1 - weight) * a1 + weight * a2)
        }

        return UIColor { traits in
            var result = UIColor.white
            traits.performAsCurrent {
                result = blend(self, with: other, weight: weight)
            }
            return result
        }
    }
}
