import AlertKit
import SwiftUI

/// Hidden debug page: edits the site mirror (`@AppStorage("mirror")`) and revokes the debug unlock (0x10000e800).
struct DebugSettingsView: View {
    @Binding var mirror: String
    @Binding var allowDebug: Bool
    @State var title: String = ""
    @State var text: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    // Section/Button titles are plain strings in the binary (StringProtocol initializers, not localized).
                    Section(header: Label("mirror" as String, systemImage: "network"),
                            footer: Text("don't forget to restart the app afterwards!" as String)) {
                        HStack {
                            TextField(title, text: $text)
                                .onSubmit {
                                    mirror = text
                                    title = text
                                    text = ""
                                }
                                .disableAutocorrection(true)
                                .textInputAutocapitalization(.never)
                            Button {
                                // The literal, not DefaultSettings.mirror: the binary resets to "ijobs.app" inline.
                                mirror = "ijobs.app"
                                title = "default"
                                text = ""
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .onAppear {
                        title = mirror == "ijobs.app" ? "default" : mirror
                    }
                    Button("Revoke access" as String) {
                        allowDebug = false
                        AlertKitAPI.present(title: "Access revoked", icon: .done, style: .iOS17AppleMusic, haptic: .success)
                    }
                }
            }
            .navigationTitle("Debug" as String)
        }
    }
}
