import SwiftUI
import QuickLook

/// Wraps a URL so it can be used with `.sheet(item:)`. URL doesn't
/// conform to Identifiable by default; the absolute string is a stable
/// id good enough for sheet presentation.
struct IdentifiableURL: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
    init(_ url: URL) { self.url = url }
}

/// In-app file viewer for remote URLs (CV PDFs, attachments, etc).
/// Downloads the file to a temp location on appear, then hands it to
/// QLPreviewController for native rendering. Apple's HIG flags PDFs
/// that bounce the user out to Safari as a downgrade — this keeps the
/// flow inside the app, matches the CertificatesView verify-link UX
/// vibe, and works with the Supabase Storage signed URLs.
struct RemoteFileViewer: View {
    let url: URL
    let suggestedName: String

    @Environment(\.dismiss) private var dismiss
    @State private var localURL: URL?
    @State private var errorMessage: String?
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ssCream.ignoresSafeArea()
                if let local = localURL {
                    QuickLookPreview(url: local)
                        .ignoresSafeArea(.container, edges: .bottom)
                } else if let err = errorMessage {
                    errorState(err)
                } else if isLoading {
                    VStack(spacing: 14) {
                        ProgressView().tint(Color.ssGreen)
                        Text(LocalizedStringKey("common.loading"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                    }
                }
            }
            .navigationTitle(suggestedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.close")) { dismiss() }
                        .foregroundStyle(Color.ssGrey)
                }
                if let local = localURL {
                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: local) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.ssGreen)
                        }
                    }
                }
            }
            .task { await download() }
        }
    }

    private func download() async {
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            // QuickLook keys preview off the file extension. The
            // downloaded temp file has no extension by default; rename
            // it to the suggested name (which carries a sensible
            // extension) so the preview renders correctly.
            let fallback = response.suggestedFilename ?? suggestedName
            let nsExt = (fallback as NSString).pathExtension
            let ext = nsExt.isEmpty ? "pdf" : nsExt
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: tempURL, to: destination)
            localURL = destination
            isLoading = false
        } catch let urlError as URLError where urlError.code == .cancelled {
            // User dismissed; ignore.
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36)).foregroundStyle(Color.ssGold)
            Text(message).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Thin UIViewControllerRepresentable wrapper around QLPreviewController.
/// One-shot preview of a local file URL (the parent downloads first).
private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return c
    }
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // Refresh in case the bound url changes.
        context.coordinator.url = url
        uiViewController.reloadData()
    }
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
