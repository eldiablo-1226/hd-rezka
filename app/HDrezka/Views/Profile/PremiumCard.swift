import SwiftUI

/// Premium subscription card at the top of the logged-in profile (0x1000fb7e4).
struct PremiumCard: View {
    var status: PremiumStatus

    var body: some View {
        HStack(spacing: 14) {
            PremiumStarIcon()
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(daysColor)
        }
        .padding(15)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .foregroundStyle(.quinary)
        }
    }

    private var daysColor: Color {
        if let days = status.daysLeft, days <= 3 { return .orange }
        return Color(red: 0.95, green: 0.62, blue: 0.11)
    }
}

/// Star in a tinted circle with three twinkling sparkles (0x1000fc4c8).
struct PremiumStarIcon: View {
    var gradient: LinearGradient

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient.opacity(0.16))
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(gradient)
            Sparkle(gradient: gradient, size: 6, x: 13, y: -11, duration: 1.3, delay: 0)
            Sparkle(gradient: gradient, size: 4, x: -14, y: -6, duration: 1.7, delay: 0.5)
            Sparkle(gradient: gradient, size: 3.5, x: 11, y: 12, duration: 1.1, delay: 0.9)
        }
    }
}

extension PremiumStarIcon {
    /// The binary's `PremiumStarIcon.init()` (0x1000fdaa0); in an extension so the memberwise init stays.
    init() {
        self.init(gradient: LinearGradient(
            colors: [
                Color(red: 0.38, green: 0.52, blue: 0.96),
                Color(red: 0.6, green: 0.38, blue: 0.93),
                Color(red: 0.91, green: 0.47, blue: 0.78),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing))
    }
}

private struct Sparkle: View {
    let gradient: LinearGradient
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let duration: Double
    let delay: Double
    @State var on: Bool = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(gradient)
            .opacity(on ? 0.95 : 0.25)
            .offset(x: x, y: y)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                    on = true
                }
            }
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
