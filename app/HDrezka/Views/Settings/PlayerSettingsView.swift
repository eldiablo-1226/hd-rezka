import SwiftUI

/// Player page: safe area (notch) toggle with its animation, autoplay, preferred quality, Infuse (0x1000e5adc).
struct PlayerSettingsView: View {
    @Binding var hideNotch: Bool
    @Binding var useInfuse: Bool
    @Binding var autoplayNextEpisode: Bool
    @Binding var preferredQuality: PlayerQualityPreference

    var body: some View {
        // improvement: no NavigationStack of its own; the screen is pushed onto Profile's stack.
        Group {
            VStack {
                Form {
                    Section(header: Label("key_safe_area_header", systemImage: "iphone"),
                            footer: Text("key_safe_area_footer")) {
                        Toggle(isOn: $hideNotch) {
                            Text("key_toggle+safe+areas")
                        }
                        HStack {
                            Spacer()
                            HideNotchAnimatedViewComponent(isAnimated: $hideNotch)
                                .padding()
                            Spacer()
                        }
                    }
                    Section(footer: Text("key_autoplay_next+description")) {
                        Toggle(isOn: $autoplayNextEpisode) {
                            Text("key_autoplay_next")
                        }
                    }
                    Section(footer: Text("key_preferred_quality+description")) {
                        Picker("key_preferred_quality", selection: $preferredQuality) {
                            ForEach(PlayerQualityPreference.allCases) { quality in
                                Text(quality.displayName)
                                    .tag(quality)
                            }
                        }
                    }
                    Section(footer: Text("key_unfise_description")) {
                        Toggle(isOn: $useInfuse) {
                            Text("key_use_unfuse")
                        }
                    }
                }
            }
            .navigationTitle("key_player")
        }
    }
}
