import SwiftUI

struct InfoTabView: View {
    @AppStorage("showVotesCount") var showVotesCount: Bool = false
    @Environment(\.openURL) var openURL
    var detail: MovieDetailed

    // Ratings (tap opens the rating page), duration and age; the dividers are shown off-phone only (0x1001094cc).
    var body: some View {
        HStack {
            if let imdb = detail.imdbRating {
                Group {
                    Spacer()
                    rating(imdb, title: "IMDb", format: "%.1f")
                }
                if UIDevice.current.userInterfaceIdiom != .phone {
                    Spacer()
                    Divider()
                }
            }
            if let kp = detail.kpRating {
                Spacer()
                Group {
                    rating(kp, title: "КиноПоиск", format: "%.2f")
                }
                if UIDevice.current.userInterfaceIdiom != .phone {
                    Spacer()
                    Divider()
                }
            }
            Spacer()
            Group {
                VStack {
                    caption("Duration")
                    value(detail.duration)
                    caption("Minutes")
                }
            }
            Spacer()
            if UIDevice.current.userInterfaceIdiom != .phone {
                Divider()
                Spacer()
            }
            Group {
                VStack {
                    caption("Age")
                    value(detail.ageRestriction)
                    caption("Years")
                }
                Spacer()
            }
        }
        .padding(.bottom, 8)
    }

    // closure #1 in closure #1 in closure #1 / closure #1 in closure #2 in closure #1 (0x10010a5c0, 0x10010ab34)
    private func rating(_ rating: MovieRating, title: LocalizedStringKey, format: String) -> some View {
        VStack {
            caption(title)
            // 0x10010ae54, shared by both ratings; only the format differs
            HStack {
                value(String(format: format, rating.value))
                if showVotesCount {
                    Text(verbatim: "(" + rating.votesCount + ")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            StarsView(rating: CGFloat(rating.value))
        }
        .onTapGesture {
            openURL(URL(string: rating.link)!)
        }
    }

    private func caption(_ key: LocalizedStringKey) -> Text {
        Text(key)
            .font(.caption2)
            .foregroundColor(.primary)
    }

    private func value(_ text: String) -> Text {
        Text(text)
            .font(.system(.title2, design: .rounded))
            .fontWeight(.medium)
    }
}
