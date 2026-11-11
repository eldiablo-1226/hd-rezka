import SwiftUI

/// Appearance page: votes count toggle with a live preview of the rating block, original titles (0x100105ee4).
struct AppearanceSettingsView: View {
    @Binding var showVotesCount: Bool
    @Binding var preferOriginalTitle: Bool

    var body: some View {
        // improvement: no NavigationStack of its own; the screen is pushed onto Profile's stack.
        Group {
            VStack {
                Form {
                    Section {
                        Toggle(isOn: $showVotesCount) {
                            Text("key_show+votes+count")
                        }
                        InfoTabDemoView(showVotesCount: $showVotesCount)
                    }
                    Section(footer: Text("key_prefer_original_title_footer")) {
                        Toggle(isOn: $preferOriginalTitle) {
                            Text("key_prefer_original_title")
                        }
                    }
                }
            }
            .navigationTitle("key_appearance")
        }
    }
}

/// Sample IMDb / KinoPoisk ratings as the info tab shows them (0x1001067cc).
private struct InfoTabDemoView: View {
    @Binding var showVotesCount: Bool

    var body: some View {
        HStack {
            Group {
                Spacer()
                VStack(spacing: 2) {
                    Text("IMDb")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    rating(9.1, format: "%.1f", votes: "(214K)")
                }
            }
            Spacer()
            Group {
                VStack(spacing: 2) {
                    Text("КиноПоиск")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    rating(2.8, format: "%.2f", votes: "(840K)")
                }
            }
            Spacer()
        }
        .animation(.default)
    }

    // The binary merged both rating rows into one function (0x1001077e8) that takes these values.
    private func rating(_ value: Double, format: String, votes: String) -> some View {
        HStack {
            Text(String(format: format, value))
                .font(.system(.title2, design: .rounded))
                .fontWeight(.medium)
            if showVotesCount {
                Text(verbatim: votes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
