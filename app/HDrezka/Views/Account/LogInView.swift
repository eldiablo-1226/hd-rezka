import SwiftUI

/// Login form (body 0x100067114, content 0x100065440, login 0x100066dc8…).
struct LogInView: View {
    enum Field: Hashable { case username, password }

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @State var username: String = ""
    @State var password: String = ""
    @State var isShowingError: Bool = false
    @FocusState var focused: Field?
    var accountService: AccountService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            TextField("Username", text: $username)
                .padding(10)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($focused, equals: .username)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).foregroundStyle(.quaternary))
            SecureField("Password", text: $password)
                .padding(10)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($focused, equals: .password)
                .submitLabel(.done)
                .onSubmit { login() }
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).foregroundStyle(.quaternary))
                .padding(.bottom, 8)
            if isShowingError {
                Text("key_wrong_login_or_password")
                    .foregroundStyle(Color.red)
                    .bold(true)
                    .padding(.bottom, 8)
            }
            Button {
                login()
            } label: {
                Text("login")
                    .padding(10)
                    .foregroundStyle(Color(.accent))
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).foregroundStyle(.quinary))
            }
            .padding(.bottom, 12)
        }
        .padding(8)
    }

    /// The session is the cookie Alamofire keeps; only the flag is stored. Network errors are dropped.
    private func login() {
        Task {
            if try await accountService.login(username: username, password: password) {
                isLoggedIn = true
                dismiss()
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 1, blendDuration: 0)) {
                    isShowingError = true
                }
            }
        }
    }
}
