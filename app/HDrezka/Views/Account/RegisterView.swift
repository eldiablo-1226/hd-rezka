import SwiftUI

/// Sign-up form (body 0x1000f1374, content 0x1000edbec, register 0x1000f012c…, checkout 0x1000f09b4…).
struct RegisterView: View {
    enum Field: Hashable { case email, username, password, confirmPassword }

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @Environment(\.dismiss) var dismiss
    @State var email: String = ""
    @State var username: String = ""
    @State var password: String = ""
    @State var confirm_password: String = ""
    @State var errorText: String = ""
    @State var error: Bool = false
    @FocusState var focused: Field?

    var body: some View {
        VStack {
            TextField("key_email", text: $email)
                .padding(10)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                .focused($focused, equals: .email)
                .onSubmit { focused = .username }
                .background(fieldBackground)
            TextField("Username", text: $username)
                .padding(10)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($focused, equals: .username)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .background(fieldBackground)
            SecureField("Password", text: $password)
                .padding(10)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                .focused($focused, equals: .password)
                .onSubmit { focused = .confirmPassword }
                .background(fieldBackground)
            SecureField("key_confirm+password", text: $confirm_password)
                .padding(10)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .focused($focused, equals: .confirmPassword)
                .onSubmit { register() }
                .background(fieldBackground)
                .padding(.bottom, 12)
            if error {
                Text(errorText)
                    .foregroundStyle(Color.red)
                    .bold(true)
                    .padding(.bottom, 8)
                    .multilineTextAlignment(.center)
            }
            Button {
                register()
            } label: {
                Text("key_register")
                    .padding(10)
                    .foregroundStyle(Color(.accent))
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).foregroundStyle(.quinary))
            }
        }
        .padding(8)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous).foregroundStyle(.quaternary)
    }

    /// Validates, then signs up; the session is the cookie Alamofire keeps. Network errors are dropped.
    private func register() {
        Task {
            if let message = try await checkout(email: email, name: username, pass: password, conf_pass: confirm_password) {
                error = true
                errorText = message
            } else if try await AccountService().signUp(email: email, username: username, password: password) {
                isLoggedIn = true
                dismiss()
            } else {
                errorText = String(localized: "key_something+went+wrong")
                error = true
            }
        }
    }

    /// The localized error to show, or nil when the form is valid and the site accepts both the e-mail and the
    /// name. Checks run in this order; an empty password passes the length check (`1...5` only fails), as in the
    /// binary. Internal for tests; private in the binary.
    func checkout(email: String, name: String, pass: String, conf_pass: String) async throws -> String? {
        error = false
        if !isValidEmail(email) { return String(localized: "key_mail+not+valid") }
        if name.count < 3 || name.count > 30 { return String(localized: "key_wrong+username+lenght") }
        if pass.count > 0 && pass.count < 6 { return String(localized: "key_wrong+password+length") }
        if pass != conf_pass { return String(localized: "key_passwords+does+not+match") }
        if try await !AccountService().checkEmail(email: email) { return String(localized: "key_email+already+taken") }
        if try await !AccountService().checkUsername(username: name) {
            return String(localized: "key_username+already+taken")
        }
        return nil
    }

    /// The regex literal of the binary (97 characters, app-strings line 255) matched with NSPredicate (0x1000f10f4).
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = #"[a-zA-Z0-9\+\.\_\%\-\+]{1,256}\@[a-zA-Z0-9][a-zA-Z0-9\-]{0,64}(\.[a-zA-Z0-9][a-zA-Z0-9\-]{0,25})+"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluate(with: email)
    }
}
