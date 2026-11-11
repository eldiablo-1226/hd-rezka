import SwiftUI

/// Login form (body 0x100067114, content 0x100065440, login 0x100066dc8…).
struct LogInView: View {
    enum Field: Hashable { case username, password }

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @State var username: String = ""
    @State var password: String = ""
    @State var isShowingError: Bool = false
    /// improvement: the site could not be reached (1.6.0 dropped the error, so the button seemed to do nothing).
    @State var isShowingNetworkError: Bool = false
    @FocusState var focused: Field?
    var accountService: AccountService
    @Environment(\.dismiss) var dismiss

    // improvement: a native form (and password AutoFill); 1.6.0 drew its own grey field and button backgrounds.
    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .focused($focused, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .focused($focused, equals: .password)
                    .submitLabel(.done)
                    .onSubmit { login() }
            } footer: {
                if isShowingError {
                    Text("key_wrong_login_or_password")
                        .foregroundStyle(Color.red)
                } else if isShowingNetworkError {
                    Text("key_login_network_error")
                        .foregroundStyle(Color.red)
                }
            }
            Section {
                Button("login", action: login)
                    .frame(maxWidth: .infinity)
            }
        }
        // improvement: titled wherever it opens (the Profile push had an empty bar).
        .navigationTitle("login")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The session is the cookie Alamofire keeps; only the flag is stored.
    private func login() {
        isShowingNetworkError = false
        Task {
            do {
                if try await accountService.login(username: username, password: password) {
                    isLoggedIn = true
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 1, blendDuration: 0)) {
                        isShowingError = true
                    }
                }
            } catch {
                withAnimation(.spring(response: 0.5, dampingFraction: 1, blendDuration: 0)) {
                    isShowingError = false
                    isShowingNetworkError = true
                }
            }
        }
    }
}
