import SwiftUI

/// Premium subscription card at the top of the logged-in profile (0x1000fb7e4).
struct PremiumCard: View {
    var status: PremiumStatus
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Side by side at accessibility sizes «Премиум» broke mid-word next to the days: they stack instead.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.space8))
            : AnyLayout(HStackLayout(spacing: 14))
        layout {
            // improvement: the system star; 1.6.0 drew it in a tinted circle with three endlessly twinkling sparkles.
            Image(systemName: "star.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("key_premium")
                    .bold()
                Text(status.daysLeft == nil ? "key_premium_active" as LocalizedStringKey : "key_premium_days_left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status.displayText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(daysColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.radiusButton, style: .continuous)
                .foregroundStyle(.quinary)
        }
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
