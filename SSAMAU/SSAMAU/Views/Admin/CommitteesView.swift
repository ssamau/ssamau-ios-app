import SwiftUI
import Combine

struct CommitteesView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = CommitteesViewModel()
    @State private var editTarget: Committee?
    @State private var creatingNew: Bool = false

    /// committees.create/update/delete are SUPERADMIN-only on the server,
    /// so admin (presidency) sees this view in read-only mode. Hiding
    /// the FAB + the row tap → edit gesture saves them from a 403 they
    /// can't act on.
    private var canMutate: Bool {
        session.currentUser?.isSuperadmin == true
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .navigationTitle(LocalizedStringKey("ap.tabs.committees"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .ssToast($vm.toast)
                .sheet(isPresented: $creatingNew) {
                    CommitteeFormSheet(existing: nil, vm: vm, isPresented: $creatingNew)
                }
                .sheet(item: $editTarget) { committee in
                    CommitteeFormSheet(
                        existing: committee, vm: vm,
                        isPresented: Binding(
                            get: { editTarget != nil },
                            set: { if !$0 { editTarget = nil } }
                        )
                    )
                }

            if canMutate {
                Button { creatingNew = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(LocalizedStringKey("ap.committees.add_btn"))
                    }
                    .font(.ssBodyBold).foregroundStyle(Color.ssCream)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.ssGreen).clipShape(Capsule()).shadow(radius: 4)
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.rows.isEmpty, vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    if vm.rows.isEmpty {
                        Text(LocalizedStringKey("ap.committees.empty"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.rows) { c in
                                Button {
                                    if canMutate { editTarget = c }
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(c.name)
                                                .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                                            Spacer()
                                            Text("\(c.memberCount)")
                                                .font(.ssCaption.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8).padding(.vertical, 3)
                                                .background(Color.ssGold)
                                                .clipShape(Capsule())
                                        }
                                        if let d = c.description {
                                            Text(d).font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                                                .lineLimit(2)
                                        }
                                        Text(c.id).font(.ssTiny.monospaced()).foregroundStyle(Color.ssGrey)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.ssPale)
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                // Force full-width — same fix as AttendanceView; without
                // it the empty Text collapses the VStack and shifts the
                // FAB inward.
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 80)
            }
        }
    }
}

private struct CommitteeFormSheet: View {
    let existing: Committee?
    @ObservedObject var vm: CommitteesViewModel
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var status: String = "Active"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("ap.committees.field_name") {
                        TextField("", text: $name)
                            .padding(10).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    field("ap.committees.field_description") {
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .padding(6).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .scrollContentBackground(.hidden)
                    }
                    field("ap.committees.field_status") {
                        Picker(selection: $status) {
                            Text(LocalizedStringKey("common.status.active")).tag("Active")
                            Text(LocalizedStringKey("common.status.inactive")).tag("Inactive")
                        } label: { EmptyView() }
                        .pickerStyle(.segmented)
                    }
                    Button {
                        Task {
                            let ok = await vm.save(
                                existing: existing,
                                name: name.trimmingCharacters(in: .whitespaces),
                                description: description.trimmingCharacters(in: .whitespaces),
                                status: status
                            )
                            if ok { isPresented = false }
                        }
                    } label: {
                        HStack {
                            if vm.inFlightId != nil { ProgressView().tint(Color.ssCream) }
                            Text(LocalizedStringKey("common.save")).font(.ssBodyBold)
                        }
                        .foregroundStyle(Color.ssCream)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(name.isEmpty ? Color.ssGrey : Color.ssGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.inFlightId != nil || name.isEmpty)
                }
                .padding(20)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey(existing == nil
                ? "ap.committees.sheet_create"
                : "ap.committees.sheet_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { isPresented = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        }
        .onAppear {
            guard let c = existing else { return }
            name = c.name
            description = c.description ?? ""
            status = c.status ?? "Active"
        }
    }

    private func field<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(key)).font(.ssCaption).foregroundStyle(Color.ssGrey)
            content()
        }
    }
}

@MainActor
final class CommitteesViewModel: ObservableObject {
    @Published var rows: [Committee] = []
    @Published var isLoading: Bool = false
    @Published var toast: Toast?
    @Published var inFlightId: String?

    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            rows = try await APIClient.shared.call("getCommittees", as: [Committee].self)
        } catch let apiError as APIError where !apiError.isCancellation {
            toast = .error(apiError.localizedMessage)
        } catch { }
    }

    func save(existing: Committee?, name: String, description: String, status: String) async -> Bool {
        inFlightId = existing?.id ?? "new"
        defer { inFlightId = nil }
        var data: [String: Any] = ["committee_name": name, "status": status]
        if !description.isEmpty { data["committee_description"] = description }
        var params: [String: Any] = ["data": data]
        let action: String
        if let e = existing { params["id"] = e.id; action = "updateCommittee" }
        else { action = "createCommittee" }
        do {
            _ = try await APIClient.shared.call(action, params: params, as: AnyJSON.self)
            toast = .success(ErrorLocalization.localize("ap.committees.saved_ok"))
            await load()
            return true
        } catch let apiError as APIError {
            if apiError.isCancellation { return false }
            toast = .error(apiError.localizedMessage)
            return false
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
            return false
        }
    }
}
