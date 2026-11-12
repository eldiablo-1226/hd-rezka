import SwiftUI

/// improvement: the site mirror as a user setting (1.6.0 had it only on the debug page behind five taps in "About").
/// Every request reads `@AppStorage("mirror")` when it is sent, so a new mirror applies to the next request.
struct MirrorSettingsView: View {
    @AppStorage("mirror") var mirror: String = DefaultSettings.mirror
    /// Called after a valid mirror was saved; the error screen retries the page once the sheet has closed.
    var onSave: (() -> Void)? = nil
    @State private var text = ""
    @State private var isInvalid = false
    @Environment(\.dismiss) private var dismiss

    // improvement: the known mirrors as a selection list, then an address of one's own (1.6.0: one text field).
    var body: some View {
        Form {
            Section {
                ForEach(DefaultSettings.knownMirrors, id: \.host) { known in
                    Button {
                        choose(known.host)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: known.host)
                                    .foregroundStyle(Color.primary)
                                // Color.secondary: in a button `.secondary` is the tint's secondary level, an orange.
                                if known.host == DefaultSettings.mirror {
                                    Text("key_mirror_default")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                } else if known.needsLogin {
                                    Text("key_mirror_needs_login")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            Spacer()
                            if known.host == mirror {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(known.host == mirror ? [.isSelected] : [])
                }
            } header: {
                Text("key_mirrors_known")
            } footer: {
                Text("key_mirrors_known_footer")
            }
            Section {
                TextField("key_mirror_custom_placeholder", text: $text)
                    // Not .URL: that keyboard follows the Russian layout, and a host typed in it comes out Cyrillic.
                    .keyboardType(.asciiCapable)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .onChange(of: text) { isInvalid = false }
                Button("key_mirror_save", action: save)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("key_mirror_custom")
            } footer: {
                Text(isInvalid ? LocalizedStringKey("key_mirror_invalid") : "key_mirror_custom_footer")
                    .foregroundStyle(isInvalid ? Color.red : Color.secondary)
            }
        }
        .navigationTitle("key_mirror")
        .onAppear {
            // A mirror from the list is checked there; the field holds only an address of one's own.
            text = DefaultSettings.knownMirrors.contains { $0.host == mirror } ? "" : mirror
        }
    }

    /// A list choice applies at once; from the error screen's sheet it also closes it, so the page retries.
    private func choose(_ host: String) {
        mirror = host
        text = ""
        isInvalid = false
        guard let onSave else { return }
        onSave()
        dismiss()
    }

    private func save() {
        guard let host = Self.normalizedMirror(text) else {
            isInvalid = true
            return
        }
        mirror = host
        text = DefaultSettings.knownMirrors.contains { $0.host == host } ? "" : host
        onSave?()
        dismiss()
    }

    /// The bare host of what the user typed ("https://HDRezka.ag/films" -> "hdrezka.ag"), or nil when it is not one.
    /// Requests are built as "https://<mirror>/…", so a scheme, port, user, query or space must not get through.
    static func normalizedMirror(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // A Character is ASCII only as a single ASCII scalar, so "q\u{301}" or a zero-width joiner stops here.
        guard text.allSatisfy(\.isASCII) else { return nil }
        for scheme in ["https://", "http://"] where text.hasPrefix(scheme) {
            text.removeFirst(scheme.count)
        }
        if let slash = text.firstIndex(of: "/") {
            text = String(text[..<slash])
        }
        let labels = text.split(separator: ".", omittingEmptySubsequences: false)
        let isHostLabel: (Substring) -> Bool = { label in
            (1...63).contains(label.count) && label.first != "-" && label.last != "-"
                && label.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" }
        }
        guard labels.count >= 2, text.count <= 253, labels.allSatisfy(isHostLabel) else { return nil }
        return text
    }
}
