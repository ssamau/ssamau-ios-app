import SwiftUI
import UIKit
import PhotosUI

/// Member-facing "report an issue" sheet. Reachable from the More menu
/// in every role's tab bar. Submits to support.submit which:
///   - inserts a row in support_tickets
///   - fires an email to the dev's inbox
///   - (optionally) uploads a screenshot to the private support bucket
///
/// Attachment: single image picker (JPEG / PNG / WebP), 4 MiB cap (matches
/// the server's SUPPORT_SIZE_CAP), base64-encoded into the request body.
struct SupportSubmitSheet: View {
    @Binding var isPresented: Bool

    @State private var category: String = "Bug"
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var reproSteps: String = ""

    // Attachment picker state.
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var attachmentData: Data?
    @State private var attachmentMime: String?
    @State private var attachmentSizeError: Bool = false

    @State private var inFlight: Bool = false
    @State private var toast: Toast?

    /// Server cap (matches SUPPORT_SIZE_CAP in actions/support.ts).
    private static let attachmentSizeCap = 4 * 1024 * 1024
    private static let allowedMimes: [String] = ["image/jpeg", "image/png", "image/webp"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("support.category_label") {
                        Picker(selection: $category) {
                            Text(LocalizedStringKey("support.cat_bug")).tag("Bug")
                            Text(LocalizedStringKey("support.cat_feature")).tag("Feature")
                            Text(LocalizedStringKey("support.cat_question")).tag("Question")
                        } label: { EmptyView() }
                        .pickerStyle(.segmented)
                    }
                    field("support.title_label") {
                        TextField(LocalizedStringKey("support.title_placeholder"),
                                  text: $title)
                            .padding(10).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    field("support.description_label") {
                        TextEditor(text: $description)
                            .frame(minHeight: 120)
                            .padding(6).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .scrollContentBackground(.hidden)
                    }
                    if category == "Bug" {
                        field("support.repro_label") {
                            TextEditor(text: $reproSteps)
                                .frame(minHeight: 80)
                                .padding(6).background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .scrollContentBackground(.hidden)
                        }
                    }
                    attachmentSection
                    Button { submit() } label: {
                        HStack {
                            if inFlight { ProgressView().tint(Color.ssCream) }
                            Text(LocalizedStringKey("support.submit_btn"))
                                .font(.ssBodyBold)
                        }
                        .foregroundStyle(Color.ssCream)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(canSubmit ? Color.ssGreen : Color.ssGrey)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(inFlight || !canSubmit)
                }
                .padding(20)
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("support.sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { isPresented = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast($toast)
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !description.trimmingCharacters(in: .whitespaces).isEmpty
            && !attachmentSizeError
    }

    /// PhotosPicker + preview. Chosen images are PNG-encoded into
    /// `attachmentData`; the original UIImage data is checked against
    /// the 4 MiB cap before encoding so we surface the error
    /// up-front instead of letting the server reject it.
    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("support.attachment_label"))
                .font(.ssCaption).foregroundStyle(Color.ssGrey)
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoPickerItem,
                             matching: .images,
                             photoLibrary: .shared()) {
                    HStack(spacing: 6) {
                        Image(systemName: attachmentData == nil ? "photo.badge.plus" : "photo")
                        Text(LocalizedStringKey(attachmentData == nil
                            ? "support.attachment_pick"
                            : "support.attachment_change"))
                    }
                    .font(.ssCaption.weight(.semibold))
                    .foregroundStyle(Color.ssGreen)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.ssPale)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                }
                if attachmentData != nil {
                    Button {
                        photoPickerItem = nil
                        attachmentData = nil
                        attachmentMime = nil
                        attachmentSizeError = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.ssGrey)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey("support.attachment_clear")))
                }
            }
            if let data = attachmentData,
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.ssLight, lineWidth: 1))
            }
            if attachmentSizeError {
                Text(LocalizedStringKey("support.attachment_too_large"))
                    .font(.ssTiny).foregroundStyle(.red)
            } else {
                Text(LocalizedStringKey("support.attachment_hint"))
                    .font(.ssTiny).foregroundStyle(Color.ssGrey)
            }
        }
        .onChange(of: photoPickerItem) { newItem in
            Task { await loadPickerItem(newItem) }
        }
    }

    /// Decode the PhotosPicker item into raw bytes + MIME. Falls back
    /// to PNG when the data type is exotic (HEIC) — the server only
    /// accepts JPEG/PNG/WebP so we re-encode to PNG before upload.
    private func loadPickerItem(_ item: PhotosPickerItem?) async {
        attachmentSizeError = false
        guard let item else {
            attachmentData = nil
            attachmentMime = nil
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            attachmentData = nil
            attachmentMime = nil
            return
        }
        // Detect MIME from magic bytes; if not one of the accepted
        // server-side types, re-encode the UIImage to PNG.
        let detectedMime = Self.sniffMime(data)
        if let mime = detectedMime, Self.allowedMimes.contains(mime) {
            if data.count > Self.attachmentSizeCap {
                attachmentSizeError = true
                attachmentData = nil
                attachmentMime = nil
                return
            }
            attachmentData = data
            attachmentMime = mime
        } else if let ui = UIImage(data: data),
                  let png = ui.pngData() {
            if png.count > Self.attachmentSizeCap {
                attachmentSizeError = true
                attachmentData = nil
                attachmentMime = nil
                return
            }
            attachmentData = png
            attachmentMime = "image/png"
        } else {
            attachmentData = nil
            attachmentMime = nil
        }
    }

    /// Cheap MIME sniff for the three accepted formats — checks the
    /// first few magic bytes. Falls through to nil (re-encode path).
    private static func sniffMime(_ data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        let p = [UInt8](data.prefix(12))
        // JPEG: FF D8 FF
        if p[0] == 0xFF && p[1] == 0xD8 && p[2] == 0xFF { return "image/jpeg" }
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if p[0] == 0x89 && p[1] == 0x50 && p[2] == 0x4E && p[3] == 0x47 { return "image/png" }
        // WebP: "RIFF" .... "WEBP"
        if p[0] == 0x52 && p[1] == 0x49 && p[2] == 0x46 && p[3] == 0x46
            && p[8] == 0x57 && p[9] == 0x45 && p[10] == 0x42 && p[11] == 0x50 {
            return "image/webp"
        }
        return nil
    }

    private func submit() {
        Task {
            inFlight = true
            defer { inFlight = false }
            var data: [String: Any] = [
                "category":     category,
                "title":        title.trimmingCharacters(in: .whitespaces),
                "description":  description.trimmingCharacters(in: .whitespaces),
                "user_agent":   "SSAMAU iOS \(APIClient.appVersion)",
                "viewport":     viewportString,
            ]
            let r = reproSteps.trimmingCharacters(in: .whitespaces)
            if !r.isEmpty { data["repro_steps"] = r }

            // Attach the picked image if any. Server expects:
            //   { filename, contentType, base64Data }
            if let bytes = attachmentData, let mime = attachmentMime {
                let ext: String = {
                    switch mime {
                    case "image/jpeg": return "jpg"
                    case "image/webp": return "webp"
                    default:           return "png"
                    }
                }()
                data["attachment"] = [
                    "filename":    "screenshot.\(ext)",
                    "contentType": mime,
                    "base64Data":  bytes.base64EncodedString(),
                ]
            }

            do {
                _ = try await APIClient.shared.call(
                    "support.submit",
                    params: ["data": data],
                    as: AnyJSON.self
                )
                toast = .success(ErrorLocalization.localize("support.submitted_ok"))
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                isPresented = false
            } catch let apiError as APIError {
                if apiError.isCancellation { return }
                toast = .error(apiError.localizedMessage)
            } catch {
                toast = .error(ErrorLocalization.localize("err.unknown"))
            }
        }
    }

    private var viewportString: String {
        let screen = UIScreen.main.bounds
        return "\(Int(screen.width))x\(Int(screen.height))"
    }

    private func field<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(key)).font(.ssCaption).foregroundStyle(Color.ssGrey)
            content()
        }
    }
}
