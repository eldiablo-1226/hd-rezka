import AlertKit
import SwiftUI
import UIKit

/// About page: thanks, developer cards (5 taps on the first unlock the debug page), known iOS issues,
/// disclaimer and the version line (0x1000e703c).
struct AboutUsView: View {
    @Binding var allowDebug: Bool
    var appVersion: String?
    var buildVerison: String?

    var body: some View {
        VStack {
            VStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        Label {
                            Text("Thank you!")
                        } icon: {
                            Image(systemName: isXmas() ? "snowflake" : "heart")
                                .foregroundStyle(Color.red)
                        }
                        .font(.system(size: 34, weight: .bold))
                        .padding(.bottom)
                        Text("thanks_special_info")
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Divider()
                        .padding(.horizontal)
                    VStack {
                        HStack {
                            Text("key_information")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.system(size: 22, weight: .bold))
                                .padding()
                        }
                        PersonCardComponent(url: "https://i.imgur.com/kJChmNQ.jpeg", job: "Code", name: "Keet",
                                            description: "Ведущий разработчик")
                            .onTapGesture(count: 5) {
                                allowDebug = true
                                AlertKitAPI.present(title: ":з", style: .iOS17AppleMusic)
                            }
                        PersonCardComponent(url: "https://i.imgur.com/YyKUZSZ.jpeg", job: "Code", name: "voidboost",
                                            description: "Помощь в разработке")
                        PersonCardComponent(url: "https://i.imgur.com/XrNIAEe.jpeg", job: "Code", name: "4nk1r",
                                            description: "Android dev")
                    }
                    if SystemVersion().os.majorVersion >= 16 && SystemVersion().os.majorVersion <= 17
                        && SystemVersion().os.minorVersion <= 4 {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("key_problems")
                                    .font(.title)
                                    .bold()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom)
                            }
                            if SystemVersion().os.majorVersion == 16 {
                                problem(image: "gear", text: "key_ios16+problem+options")
                                    .padding(.bottom)
                            }
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                if SystemVersion().os.majorVersion == 17 && SystemVersion().os.minorVersion <= 4 {
                                    problem(image: "arrow.backward", text: "key_ios17+problem+swipe")
                                }
                            }
                        }
                        .padding()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("key_disclaimer", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .bold()
                        Text("key_disclaimer_description")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding()
                    Text(verbatim: versionText)
                        .padding()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // The binary merged both issue rows into one function (0x1000e9f8c) that takes these values.
    private func problem(image: String, text: LocalizedStringKey) -> some View {
        HStack {
            Image(systemName: image)
                .font(.title)
            VStack(alignment: .leading) {
                Text(SystemVersion().osString)
                    .font(.headline)
                Text(text)
                    .font(.caption)
            }
        }
    }

    /// Christmas week: from Dec 25 00:00 up to "Dec 32" (Jan 1 00:00) of the current year (0x1000ead04).
    func isXmas() -> Bool {
        Self.isXmas(on: Date(), calendar: .current)
    }

    static func isXmas(on now: Date, calendar: Calendar) -> Bool {
        guard let year = calendar.dateComponents([.year], from: now).year,
              let start = calendar.date(from: DateComponents(year: year, month: 12, day: 25)),
              let end = calendar.date(from: DateComponents(year: year, month: 12, day: 32))
        else { return false }
        return now >= start && now <= end
    }

    /// "v<version>, build <build>, OS <os>" at the bottom of the page.
    var versionText: String {
        "v\(appVersion ?? "UNKNOWN VERSION"), build \(buildVerison ?? "UNKNOWN BUILD"), OS \(SystemVersion().osString)"
    }
}

extension AboutUsView {
    /// Reads the version and build from the main bundle (0x1000ea778); in an extension so the memberwise init stays.
    init(allowDebug: Binding<Bool>) {
        self.init(
            allowDebug: allowDebug,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildVerison: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    }
}
