import SwiftUI

/// The ratings strip under the page's title: IMDb, КиноПоиск (tap opens the rating page), duration and age.
/// improvement (Details redesign): one cell shape for all four, caption over value, so the row lines up (1.6.0 centred
/// two-line ratings against three-line duration and age, about 5 pt apart). One row of equal cells while every cell
/// fits whole, else two columns, else one: the cells used to shrink one by one, so at xxLarge the four values came out
/// in four sizes. Each cell is as wide as the widest one needs, from the leading edge: across an iPad's header column
/// four cells stretched to about 280 pt each.
struct InfoTabView: View {
    @AppStorage("showVotesCount") var showVotesCount: Bool = false
    @Environment(\.openURL) var openURL
    var detail: MovieDetailed

    var body: some View {
        let cells = 1 + (MovieDetailed.shown(detail.duration) == nil ? 0 : 1) + (detail.imdbRating == nil ? 0 : 1)
            + (detail.kpRating == nil ? 0 : 1)
        ViewThatFits(in: .horizontal) {
            EqualColumns(columns: cells, spacing: DesignTokens.space16) { facts }
                .fixedSize(horizontal: true, vertical: false)
            EqualColumns(columns: 2, spacing: DesignTokens.space16) { facts }
                .fixedSize(horizontal: true, vertical: false)
            EqualColumns(columns: 1, spacing: DesignTokens.space16) { facts }
        }
    }

    @ViewBuilder
    private var facts: some View {
        if let imdb = detail.imdbRating {
            rating(imdb, title: "IMDb", format: "%.1f")
        }
        if let kp = detail.kpRating {
            rating(kp, title: "КиноПоиск", format: "%.2f")
        }
        // improvement: a page without «Время» has no duration cell; it showed the parser's placeholder «nil».
        if let duration = MovieDetailed.shown(detail.duration) {
            cell(caption: Text("Duration"), value: durationText(duration))
        }
        cell(caption: Text("Age"), value: Text(verbatim: detail.ageRestriction))
    }

    // closure #1 in closure #1 in closure #1 / closure #1 in closure #2 in closure #1 (0x10010a5c0, 0x10010ab34)
    private func rating(_ rating: MovieRating, title: String, format: String) -> some View {
        // improvement: a button (VoiceOver, whole-block hit area) that skips a malformed link instead of
        // onTapGesture with a force-unwrapped URL.
        Button {
            if let url = URL(string: rating.link) { openURL(url) }
        } label: {
            // 0x10010ae54, shared by both ratings; only the format differs
            let value = Text(verbatim: String(format: format, rating.value))
            cell(caption: Text(verbatim: title),
                 value: showVotesCount ? value + Text(verbatim: " (" + rating.votesCount + ")").font(.caption2) : value)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }

    /// "172" + "мин" when the site writes minutes, else the site's text as is.
    private func durationText(_ duration: String) -> Text {
        guard let minutes = Self.durationNumber(duration) else { return Text(verbatim: duration) }
        return Text(verbatim: minutes + " ") + Text("Minutes").font(.subheadline.weight(.medium))
    }

    private func cell(caption: Text, value: Text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // One line each, at full size: «Длительность» broke into «Длитель-ность» in a four-column row, and now the
            // row gives way to two columns instead.
            caption
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            value
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// improvement: "172 мин." / "172 мин" -> "172" (the caption below says "Minutes"); any other text gives nil,
    /// so the view shows it as is and hides the caption.
    static func durationNumber(_ duration: String) -> String? {
        let digits = duration.prefix(while: { $0.isASCII && $0.isNumber })
        let unit = duration.dropFirst(digits.count)
        return !digits.isEmpty && (unit == " мин." || unit == " мин") ? String(digits) : nil
    }
}

/// Rows of `columns` equal cells. Unproposed, it is as wide as its widest cell needs, which is what ViewThatFits
/// compares; given a width, it fills it.
private struct EqualColumns: Layout {
    var columns: Int
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let count = columnCount(subviews)
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = proposal.width ?? widest * CGFloat(count) + spacing * CGFloat(count - 1)
        let heights = rowHeights(subviews, count: count, width: width)
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = columnCount(subviews)
        let cell = ProposedViewSize(width: columnWidth(bounds.width, count: count), height: nil)
        var y = bounds.minY
        for (row, height) in zip(rows(subviews, count: count), rowHeights(subviews, count: count, width: bounds.width)) {
            for (column, subview) in row.enumerated() {
                let x = bounds.minX + CGFloat(column) * ((cell.width ?? 0) + spacing)
                subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: cell)
            }
            y += height + spacing
        }
    }

    private func columnCount(_ subviews: Subviews) -> Int { max(1, min(columns, subviews.count)) }

    private func columnWidth(_ width: CGFloat, count: Int) -> CGFloat {
        (width - spacing * CGFloat(count - 1)) / CGFloat(count)
    }

    private func rows(_ subviews: Subviews, count: Int) -> [Subviews.SubSequence] {
        stride(from: 0, to: subviews.count, by: count).map { subviews[$0..<min($0 + count, subviews.count)] }
    }

    private func rowHeights(_ subviews: Subviews, count: Int, width: CGFloat) -> [CGFloat] {
        let cell = ProposedViewSize(width: columnWidth(width, count: count), height: nil)
        return rows(subviews, count: count).map { row in row.map { $0.sizeThatFits(cell).height }.max() ?? 0 }
    }
}
