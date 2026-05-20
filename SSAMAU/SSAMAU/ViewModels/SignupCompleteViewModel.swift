import Foundation
import Combine

@MainActor
final class SignupCompleteViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case token
        case pin
        var id: String { rawValue }
    }

    @Published var mode: Mode

    // Token mode
    @Published var token: String = ""

    // PIN mode
    @Published var nationalId: String = ""
    @Published var pin: String = ""

    // Both
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var didActivate: Bool = false

    init(initialMode: Mode = .pin, prefilledToken: String? = nil) {
        if let prefilledToken, !prefilledToken.isEmpty {
            self.mode = .token
            self.token = prefilledToken
        } else {
            self.mode = initialMode
        }
    }

    func switchMode() {
        mode = (mode == .token) ? .pin : .token
        errorMessage = nil
        successMessage = nil
    }

    var canSubmit: Bool {
        guard !isLoading else { return false }
        guard password.count >= 8, password == confirmPassword else { return false }
        switch mode {
        case .token:
            return !token.trimmingCharacters(in: .whitespaces).isEmpty
        case .pin:
            return nationalId.count == 10 && pin.count == 6
        }
    }

    func submit() async {
        guard !isLoading else { return }
        errorMessage = nil
        successMessage = nil

        // Local validation — match the web's su.err_* messaging.
        if password.isEmpty || confirmPassword.isEmpty {
            errorMessage = ErrorLocalization.localize("su.err_need_passwords")
            return
        }
        if password.count < 8 {
            errorMessage = ErrorLocalization.localize("su.err_password_short")
            return
        }
        if password != confirmPassword {
            errorMessage = ErrorLocalization.localize("su.err_password_mismatch")
            return
        }
        switch mode {
        case .token:
            let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty {
                errorMessage = ErrorLocalization.localize("err.auth.invite_invalid")
                return
            }
        case .pin:
            let nid = nationalId.trimmingCharacters(in: .whitespaces)
            let p   = pin.trimmingCharacters(in: .whitespaces)
            if nid.isEmpty { errorMessage = ErrorLocalization.localize("su.err_need_nid");  return }
            if nid.count != 10 || !nid.allSatisfy(\.isNumber) {
                errorMessage = ErrorLocalization.localize("su.err_nid_format"); return
            }
            if p.isEmpty { errorMessage = ErrorLocalization.localize("su.err_need_pin"); return }
            if p.count != 6 || !p.allSatisfy(\.isNumber) {
                errorMessage = ErrorLocalization.localize("su.err_pin_format"); return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .token:
                _ = try await APIClient.shared.call(
                    "auth.signup.completeByToken",
                    params: [
                        "token": token.trimmingCharacters(in: .whitespacesAndNewlines),
                        "password": password,
                    ],
                    as: ActivateResponse.self
                )
            case .pin:
                _ = try await APIClient.shared.call(
                    "auth.signup.completeByPin",
                    params: [
                        "national_id": nationalId.trimmingCharacters(in: .whitespaces),
                        "pin":         pin.trimmingCharacters(in: .whitespaces),
                        "password":    password,
                    ],
                    as: ActivateResponse.self
                )
            }
            successMessage = ErrorLocalization.localize("su.success_activated")
            didActivate = true
        } catch let apiError as APIError {
            errorMessage = apiError.localizedMessage
        } catch {
            errorMessage = ErrorLocalization.localize("su.err_unexpected")
        }
    }

    private struct ActivateResponse: Decodable {
        let email: String?
        let login_hint: String?
    }
}
