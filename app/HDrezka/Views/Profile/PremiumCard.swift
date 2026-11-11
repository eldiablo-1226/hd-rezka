import SwiftUI

/// Premium subscription card at the top of the logged-in profile (0x1000fb7e4). improvement: a row of the profile's
/// system list, without its own grey card.
struct PremiumCard: View {
    var status: PremiumStatus

    // The list row's own label and value; it stacks them at accessibility sizes, where «Премиум» used to break
    // mid-word next to the days.
    var body: some View {
        LabeledContent {
            Text(status.displayText)
                .monospacedDigit()
                .foregroundStyle(daysColor)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("key_premium")
                    Text(status.daysLeft == nil ? "key_premium_active" as LocalizedStringKey : "key_premium_days_left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                // improvement: the system star; 1.6.0 drew it in a tinted circle with three endlessly twinkling sparkles.
                Image(systemName: "star.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // improvement: one accent, and only when the subscription is about to run out (1.6.0: orange / gold).
    private var daysColor: Color {
        if let days = status.daysLeft, days <= 3 { return .accentColor }
        return .primary
    }
}


/// The `.b-tophead-premuser b` text of the site header (stored in `@AppStorage("hasPremium")`).
struct PremiumStatus {
    let daysLeft: Int?
    let rawText: String

    /// nil when the text is blank; `daysLeft` is every digit of the text joined (0x1000fcfcc).
    init?(raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        daysLeft = Int(trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
        rawText = trimmed
    }

    /// Russian plural form of "day" (0x1000fd940). Private in the binary; internal because the shared
    /// HDrezkaTests/ProfileAccountViewTests.swift calls it.
    static func dayWord(for days: Int) -> String {
        String(localized: String.LocalizationValue(dayWordKey(for: days)))
    }

    /// 11–14 → many, then the last digit: 1 → one, 2–4 → few, anything else → many.
    static func dayWordKey(for days: Int) -> String {
        if (11...14).contains(days % 100) { return "key_days_many" }
        switch days % 10 {
        case 1: return "key_days_one"
        case 2...4: return "key_days_few"
        default: return "key_days_many"
        }
    }
}

extension PremiumStatus {
    // shortcut: name guessed, the binary inlined this into PremiumCard's body (0x1000fbef8); verify only if a symbol turns up.
    /// "<days> <day word>", or the site text when it has no number.
    var displayText: String {
        if let daysLeft {
            return "\(daysLeft) \(Self.dayWord(for: daysLeft))"
        }
        return rawText
    }
}
