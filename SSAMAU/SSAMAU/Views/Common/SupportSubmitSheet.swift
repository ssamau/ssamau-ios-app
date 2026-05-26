import SwiftUI
import UIKit

/// Member-facing "report an issue" sheet. Reachable from the More menu
/// in every role's tab bar. Submits to support.submit which:
///   - inserts a row in support_tickets
///   - fires an email to the dev's inbox
///
/// Attachments are deferred for now (would need a UIImagePicker + PNG
/// base64 encode; not needed for v1 of the in-product support flow).
struct SupportSubmitSheet: View {
    @Binding var isPresented: Bool

    @State private var category: String = "Bug"
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var reproSteps: String = ""

    @State private var inFlight: Bool = false
    @State private var toast: Toast?

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
