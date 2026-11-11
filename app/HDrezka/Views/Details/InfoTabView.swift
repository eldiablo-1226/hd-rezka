import SwiftUI

/// The ratings strip under the page's title: IMDb, КиноПоиск (tap opens the rating page), duration and age.
/// improvement (Details redesign): one cell shape for all four, caption over value, so the row lines up (1.6.0 centred
/// two-line ratings against three-line duration and age, about 5 pt apart); two columns at accessibility sizes.
struct InfoTabView: View {
    @AppStorage("showVotesCount") var showVotesCount: Bool = false
    @Environment(\.openURL) var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    var detail: MovieDetailed

    var body: some View {
        let cells = 2 + (detail.imdbRating == nil ? 0 : 1) + (detail.kpRating == nil ? 0 : 1)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.space16, alignment: .topLeading),
                                 count: typeSize.isAccessibilitySize ? 2 : cells),
                  alignment: .leading, spacing: DesignTokens.space16) {
            if let imdb = detail.imdbRating {
                rating(imdb, title: "IMDb", format: "%.1f")
            }
            if let kp = detail.kpRating {
                rating(kp, title: "КиноПоиск", format: "%.2f")
            }
            cell(caption: Text("Duration"), value: duration)
            cell(caption: Text("Age"), value: Text(verbatim: detail.ageRestriction))
        }
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
    private var duration: Text {
        guard let minutes = Self.durationNumber(detail.duration) else { return Text(verbatim: detail.duration) }
        return Text(verbatim: minutes + " ") + Text("Minutes").font(.subheadline.weight(.medium))
    }

    private func cell(caption: Text, value: Text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            caption
                .font(.caption)
                .foregroundStyle(.secondary)
                // «Длительность» broke into «Длитель-ность» in a four-column row; it shrinks a little instead.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            value
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
