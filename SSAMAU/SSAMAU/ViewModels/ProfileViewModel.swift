import Foundation
import Combine
import UIKit

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

    /// Signed URLs (1h expiry) for the member's photo and CV. Populated
    /// after `load()` via `getMemberFile`. `members.getOwn` only returns
    /// the storage path, which can't be rendered directly.
    @Published var photoSignedURL: URL?
    @Published var cvSignedURL: URL?

    @Published var isUploadingPhoto: Bool = false
    @Published var isUploadingCV: Bool = false

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
            await refreshFileURLs()
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

    // MARK: - File URLs

    /// Re-fetch signed URLs for whichever of photo/CV the member has set.
    private func refreshFileURLs() async {
        photoSignedURL = await fetchSignedURL(kind: "photo")
        cvSignedURL    = await fetchSignedURL(kind: "cv")
    }

    private func fetchSignedURL(kind: String) async -> URL? {
        do {
            let resp = try await APIClient.shared.call(
                "storage.getMemberFile",
                params: ["data": ["kind": kind]],
                as: SignedURLResponse.self
            )
            return resp.url.flatMap { URL(string: $0) }
        } catch {
            return nil
        }
    }

    private struct SignedURLResponse: Decodable {
        let url: String?
    }

    // MARK: - Photo upload

    /// Accepts raw image data (PNG/JPEG/HEIC/etc.), resizes to fit
    /// inside 512×512 keeping aspect, re-encodes as JPEG (~0.85 quality)
    /// so the upload stays under the server's 3 MB cap, and POSTs to
    /// `uploadMemberFile`.
    func uploadPhoto(_ data: Data, originalFilename: String) async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        guard let image = UIImage(data: data) else {
            toastMessage = ErrorLocalization.localize("mp.profile.upl_failed")
            return
        }
        let resized = image.ssResized(toFit: 512)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else {
            toastMessage = ErrorLocalization.localize("mp.profile.upl_failed")
            return
        }
        await upload(
            kind: "photo",
            filename: defaultPhotoFilename(originalFilename),
            contentType: "image/jpeg",
            bytes: jpeg
        )
    }

    func uploadCV(_ data: Data, originalFilename: String) async {
        isUploadingCV = true
        defer { isUploadingCV = false }
        // Client-side guard (server also enforces 5 MB).
        if data.count > 5 * 1024 * 1024 {
            toastMessage = ErrorLocalization.localize(
                "mp.profile.upl_too_large", params: ["megs": "5"]
            )
            return
        }
        await upload(
            kind: "cv",
            filename: originalFilename,
            contentType: "application/pdf",
            bytes: data
        )
    }

    private func upload(kind: String, filename: String, contentType: String, bytes: Data) async {
        do {
            _ = try await APIClient.shared.call(
                "storage.uploadMemberFile",
                params: ["data": [
                    "kind": kind,
                    "filename": filename,
                    "contentType": contentType,
                    "base64Data": bytes.base64EncodedString(),
                ]],
                as: UploadResponse.self
            )
            toastMessage = ErrorLocalization.localize("mp.profile.upl_success")
            await load()
        } catch let apiError as APIError {
            toastMessage = apiError.localizedMessage
        } catch {
            toastMessage = ErrorLocalization.localize("mp.profile.upl_failed")
        }
    }

    private struct UploadResponse: Decodable {
        let path: String
        let size: Int
    }

    // MARK: - Delete

    func deleteFile(kind: String) async {
        do {
            _ = try await APIClient.shared.call(
                "storage.deleteMemberFile",
                params: ["data": ["kind": kind]],
                as: DeleteResponse.self
            )
            toastMessage = ErrorLocalization.localize("mp.profile.upl_delete_success")
            await load()
        } catch let apiError as APIError {
            toastMessage = apiError.localizedMessage
        } catch {
            toastMessage = ErrorLocalization.localize("mp.profile.upl_delete_failed")
        }
    }

    private struct DeleteResponse: Decodable {
        let ok: Bool
        let deleted: Bool
    }

    // MARK: - Helpers

    private func defaultPhotoFilename(_ original: String) -> String {
        let base = (original as NSString).deletingPathExtension
        let safe = base.isEmpty ? "photo" : base
        return "\(safe).jpg"
    }
}

// MARK: - UIImage resize

private extension UIImage {
    /// Resize so the longest side <= `maxDim`, preserving aspect ratio.
    func ssResized(toFit maxDim: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDim else { return self }
        let scale = maxDim / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
