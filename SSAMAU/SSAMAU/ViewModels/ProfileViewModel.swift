import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    /// Server state — what was last loaded or saved.
    @Published var member: Member?

    /// Mutable copy while editing. nil when viewing.
    @Published var draft: Member?

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    var isEditing: Bool { draft != nil }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await APIClient.shared.call(
                "members.getOwn",
                as: Member.self
            )
            self.member = loaded
            self.errorMessage = nil
        } catch let apiError as APIError {
            self.errorMessage = apiError.localizedMessage
        } catch {
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    func startEditing() {
        draft = member
        toastMessage = nil
    }

    func cancelEditing() {
        draft = nil
    }

    func save() async {
        guard let draft else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await APIClient.shared.call(
                "members.updateOwn",
                params: ["data": payload(from: draft)],
                as: EmptyResponse.self
            )
            self.member = draft
            self.draft = nil
            self.toastMessage = ErrorLocalization.localize("mp.profile.save_success")
        } catch let apiError as APIError {
            self.toastMessage = apiError.localizedMessage
        } catch {
            self.toastMessage = ErrorLocalization.localize("mp.profile.save_failed")
        }
    }

    /// Build the `data` dict for members.updateOwn. We send every
    /// editable field on each save — the server's COALESCE keeps the
    /// existing value when null, and sends a value (incl. "") when set.
    private func payload(from m: Member) -> [String: Any] {
        var d: [String: Any] = [:]
        d["preferred_name"]     = m.preferredName     ?? NSNull()
        d["email"]              = m.email             ?? NSNull()
        d["phone"]              = m.phone             ?? NSNull()
        d["whatsapp"]           = m.whatsapp          ?? NSNull()
        d["date_of_birth"]      = m.dateOfBirth       ?? NSNull()
        d["address_melbourne"]  = m.addressMelbourne  ?? NSNull()
        d["linkedin_url"]       = m.linkedinUrl       ?? NSNull()
        d["scholarship_entity"] = m.scholarshipEntity ?? NSNull()
        d["study_level"]        = m.studyLevel        ?? NSNull()
        d["degree_field"]       = m.degreeField       ?? NSNull()
        d["university"]         = m.university        ?? NSNull()
        d["skills_hobbies"]     = m.skillsHobbies     ?? NSNull()
        d["about_self"]         = m.aboutSelf         ?? NSNull()
        return d
    }
}
