import SwiftUI

/// Sign-in screen — spec §8.1, styled per SSAM Brand Identity Guide.
struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @FocusState private var focusedField: Field?
    @State private var showSettingsFallback = false
    @State private var showResetPassword = false
    @State private var showSignupComplete = false
    @State private var signupToken: String?

    private enum Field: Hashable { case identifier, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    card
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if focusedField != nil {
                    Color.clear.frame(height: 8)
                }
            }
            .alert(
                LocalizedStringKey("settings.cant_open.title"),
                isPresented: $showSettingsFallback
            ) {
                Button(LocalizedStringKey("common.ok")) {}
            } message: {
                Text(LocalizedStringKey("settings.cant_open.message"))
            }
            .navigationDestination(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
            .navigationDestination(isPresented: $showSignupComplete) {
                SignupCompleteView(
                    prefilledToken: signupToken,
                    initialMode: signupToken == nil ? .pin : .token
                )
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }

    /// Universal Link / custom-scheme handler. Today only signup.html?token=
    /// is wired — cert verify + reset-password redirects come later.
    private func handleIncomingURL(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let path = comps.path
        if path == "/signup.html" || path == "/signup" {
            signupToken = comps.queryItems?.first(where: { $0.name == "token" })?.value
            showSignupComplete = true
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            Image("SSAMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            Text(LocalizedStringKey("brand.ssam_full"))
                .font(.ssH1)
                .foregroundStyle(Color.ssGreen)
                .multilineTextAlignment(.center)
            GoldRule(width: 48)
            Text(LocalizedStringKey("login.welcome"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 18) {
            identifierField
            passwordField

            if let error = vm.errorMessage {
                Text(error)
                    .font(.ssCaption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            submitButton

            VStack(spacing: 14) {
                Button {
                    showResetPassword = true
                } label: {
                    Text(LocalizedStringKey("login.forgot"))
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssGreen)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    signupToken = nil
                    showSignupComplete = true
                } label: {
                    Text(LocalizedStringKey("login.activate_cta"))
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssGreen)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    openAppSettings { showSettingsFallback = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text(LocalizedStringKey("lang.toggle_title"))
                    }
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssGreen)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Fields

    private var identifierField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("login.identifier_label"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            TextField(
                LocalizedStringKey("login.identifier_placeholder"),
                text: $vm.identifier
            )
            .font(.ssBody)
            .foregroundStyle(Color.ssCharcoal)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .keyboardType(.emailAddress)
            .submitLabel(.next)
            .focused($focusedField, equals: .identifier)
            .onSubmit { focusedField = .password }
            .padding(12)
            .background(Color.ssCream)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.ssLight, lineWidth: 1)
            )
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("login.password_label"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            HStack(spacing: 8) {
                Group {
                    if vm.isPasswordVisible {
                        TextField(
                            LocalizedStringKey("login.password_placeholder"),
                            text: $vm.password
                        )
                    } else {
                        SecureField(
                            LocalizedStringKey("login.password_placeholder"),
                            text: $vm.password
                        )
                    }
                }
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                // Auto-submit only — gated in the VM against
                // same-credentials loops (AutoFill rapid-fire).
                .onSubmit { Task { await vm.signIn(trigger: .fieldSubmit) } }

                Button {
                    vm.isPasswordVisible.toggle()
                } label: {
                    Image(systemName: vm.isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(Color.ssGrey)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.ssCream)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.ssLight, lineWidth: 1)
            )
        }
    }

    private var submitButton: some View {
        Button {
            // Explicit user tap — bypasses the same-credentials guard.
            Task { await vm.signIn(trigger: .button) }
        } label: {
            ZStack {
                Text(LocalizedStringKey("login.submit"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCream)
                    .opacity(vm.isLoading ? 0 : 1)
                if vm.isLoading {
                    ProgressView()
                        .tint(Color.ssCream)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(vm.canSubmit ? Color.ssGreen : Color.ssGrey)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!vm.canSubmit)
    }
}

/// Try to open iOS Settings → SSAMAU. On iOS 26 beta + personal dev
/// cert, the OS rewrites the URL and refuses with an LSApplicationWorkspace
/// sandbox-extension error, so we surface a fallback callback the caller
/// can use to show manual instructions.
@MainActor
private func openAppSettings(onFailure: @escaping @MainActor () -> Void) {
    let raw = UIApplication.openSettingsURLString
    guard let url = URL(string: raw) else {
        onFailure()
        return
    }
    UIApplication.shared.open(url, options: [:]) { success in
        Task { @MainActor in
            if !success { onFailure() }
        }
    }
}

#Preview {
    LoginView()
}
