import SwiftUI

/// Advisors CRUD — superadmin-only on the server side, but the admin
/// can browse via the admin More menu. Mutations gated by server's
/// SUPERADMIN_ACTIONS allowlist.
struct AdvisorsView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = AdvisorsViewModel()
    @State private var editTarget: Advisor?
    @State private var creatingNew: Bool = false
    @State private var deleteTarget: Advisor?

    /// All advisor mutations are SUPERADMIN-only on the server. Hide the
    /// create FAB + tap-to-edit + delete buttons for non-superadmins
    /// (admin/presidency) so they don't hit 403s.
    private var canMutate: Bool {
        session.currentUser?.isSuperadmin == true
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .navigationTitle(LocalizedStringKey("ap.tabs.advisors"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .ssToast($vm.toast)
                .sheet(isPresented: $creatingNew) {
                    AdvisorFormSheet(existing: nil, vm: vm, isPresented: $creatingNew)
                        .iPadSheet(.large)
                }
                .sheet(item: $editTarget) { advisor in
                    AdvisorFormSheet(
                        existing: advisor, vm: vm,
                        isPresented: Binding(
                            get: { editTarget != nil },
                            set: { if !$0 { editTarget = nil } }
                        )
                    )
                    .iPadSheet(.large)
                }
                .confirmationDialog(
                    LocalizedStringKey("ap.advisors.delete_confirm"),
                    isPresented: Binding(
                        get: { deleteTarget != nil },
                        set: { if !$0 { deleteTarget = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    if let a = deleteTarget {
                        Button(LocalizedStringKey("common.delete"), role: .destructive) {
                            Task { await vm.delete(a); deleteTarget = nil }
                        }
                    }
                    Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
                }

            if canMutate {
                Button { creatingNew = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(LocalizedStringKey("ap.advisors.add_btn"))
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
                        Text(LocalizedStringKey("ap.advisors.empty"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.rows) { a in
                                rowCard(a)
                            }
                        }
                    }
                }
                // Force full-width — same fix as AttendanceView; without
                // it the empty Text collapses the VStack and shifts the
                // FAB inward.
                .frame(maxWidth: .infinity)
                .ipadContentWidth()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 80)
            }
        }
    }

    private func rowCard(_ a: Advisor) -> some View {
        Button {
            if canMutate { editTarget = a }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(a.fullName)
                        .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                    Spacer()
                    if let s = a.status {
                        Text(LocalizedStringKey(
                            s == "Active" ? "common.status.active" : "common.status.inactive"
                        ))
                        .font(.ssTiny.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(s == "Active" ? Color.ssGreen : Color.ssGrey)
                        .clipShape(Capsule())
                    }
                }
                if let r = a.advisoryRole {
                    Text(r).font(.ssCaption).foregroundStyle(Color.ssCharcoal)
                }
                if let e = a.email {
                    Text(e).font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
                if a.totalHours > 0 {
                    Label(String(format: "%.1f h", a.totalHours), systemImage: "clock")
                        .font(.ssTiny.weight(.semibold))
                        .foregroundStyle(Color.ssGold)
                }
                if canMutate {
                    HStack {
                        Spacer()
                        Button(role: .destructive) { deleteTarget = a } label: {
                            Label(LocalizedStringKey("common.delete"), systemImage: "trash")
                                .font(.ssTiny.weight(.semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.ssCream).clipShape(Capsule())
                                .overlay(Capsule().stroke(.red.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.inFlightId != nil)
                    }
                }
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

private struct AdvisorFormSheet: View {
    let existing: Advisor?
    @ObservedObject var vm: AdvisorsViewModel
    @Binding var isPresented: Bool

    @State private var fullName: String = ""
    @State private var advisoryRole: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var status: String = "Active"
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("ap.advisors.field_name") {
                        TextField("", text: $fullName)
                            .textInputAutocapitalization(.words)
                            .padding(10).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    field("ap.advisors.field_role") {
                        TextField("", text: $advisoryRole)
                            .padding(10).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    field("ap.advisors.field_email") {
                        TextField("", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(10).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    field("ap.advisors.field_phone") {
                        TextField("", text: $phone)
                            .keyboardType(.phonePad)
                            .padding(10).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    field("ap.advisors.field_status") {
                        Picker(selection: $status) {
                            Text(LocalizedStringKey("common.status.active")).tag("Active")
                            Text(LocalizedStringKey("common.status.inactive")).tag("Inactive")
                        } label: { EmptyView() }
                        .pickerStyle(.segmented)
                    }
                    field("ap.advisors.field_notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                            .padding(6).background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .scrollContentBackground(.hidden)
                    }
                    Button {
                        Task {
                            let ok = await vm.save(
                                existing: existing,
                                fullName: fullName.trimmingCharacters(in: .whitespaces),
                                advisoryRole: advisoryRole.trimmingCharacters(in: .whitespaces),
                                email: email.trimmingCharacters(in: .whitespaces),
                                phone: phone.trimmingCharacters(in: .whitespaces),
                                status: status,
                                notes: notes.trimmingCharacters(in: .whitespaces)
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
                        .background(fullName.isEmpty ? Color.ssGrey : Color.ssGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.inFlightId != nil || fullName.isEmpty)
                }
                .padding(20)
                .ipadContentWidth(520)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey(existing == nil
                ? "ap.advisors.sheet_create_title"
                : "ap.advisors.sheet_edit_title"))
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
            guard let a = existing else { return }
            fullName     = a.fullName
            advisoryRole = a.advisoryRole ?? ""
            email        = a.email ?? ""
            phone        = a.phone ?? ""
            status       = a.status ?? "Active"
            notes        = a.notes ?? ""
        }
    }

    private func field<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(key)).font(.ssCaption).foregroundStyle(Color.ssGrey)
            content()
        }
    }
}
