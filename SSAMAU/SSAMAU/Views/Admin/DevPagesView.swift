import SwiftUI
import Combine

/// Superadmin-only dev tools. Currently focused on the support inbox —
/// listing tickets, viewing them, updating status. Mirrors what the
/// web's admin support tab does.
struct DevPagesView: View {
    @StateObject private var vm = DevPagesViewModel()
    @State private var selected: SupportTicket?

    var body: some View {
        content
            .navigationTitle(LocalizedStringKey("dev.tab_title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.ssCream)
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .ssToast($vm.toast)
            .sheet(item: $selected) { ticket in
                DevTicketSheet(
                    ticket: ticket, vm: vm,
                    isPresented: Binding(
                        get: { selected != nil },
                        set: { if !$0 { selected = nil } }
                    )
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("dev.support_inbox_title"))
                        .font(.ssH2).foregroundStyle(Color.ssGreen)
                    GoldRule(width: 32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    chip(.all, label: "dev.support_filter_all")
                    chip(.open, label: "dev.support_filter_open")
                    Spacer()
                }

                if vm.isLoading && vm.rows.isEmpty {
                    ProgressView().tint(Color.ssGreen).padding(.vertical, 40)
                } else if vm.filteredRows.isEmpty {
                    Text(LocalizedStringKey("dev.support_empty"))
                        .font(.ssCaption).foregroundStyle(Color.ssGrey)
                        .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.filteredRows) { t in
                            Button { selected = t } label: {
                                rowCard(t)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .ipadContentWidth()
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func chip(_ f: DevPagesViewModel.Filter, label: String) -> some View {
        let selected = vm.filter == f
        return Button { vm.filter = f } label: {
            Text(LocalizedStringKey(label))
                .font(.ssCaption.weight(.semibold))
                .foregroundStyle(selected ? Color.ssCream : Color.ssGreen)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? Color.ssGreen : Color.ssPale)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func rowCard(_ t: SupportTicket) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t.title)
                    .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                Spacer()
                statusBadge(t.status ?? "Open")
            }
            HStack(spacing: 8) {
                if let cat = t.category {
                    Text(cat).font(.ssTiny.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.ssGold)
                        .clipShape(Capsule())
                }
                if let reporter = t.reporterName {
                    Text(reporter).font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
            }
            if let desc = t.description {
                Text(desc).font(.ssCaption).foregroundStyle(Color.ssCharcoal).lineLimit(2)
            }
            if let d = MemberFieldMaps.displayDate(t.createdAt) {
                Label(d, systemImage: "calendar")
                    .font(.ssTiny).foregroundStyle(Color.ssGrey)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Open":       return (.ssGreen, "dev.support_open")
            case "InProgress": return (.ssGold,  "dev.support_in_progress")
            case "Resolved":   return (.ssGrey,  "dev.support_resolved")
            case "Closed":     return (.ssGrey,  "dev.support_closed")
            default:           return (.ssGrey,  "")
            }
        }()
        return Text(key.isEmpty ? status : NSLocalizedString(key, comment: ""))
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color).clipShape(Capsule())
    }
}

private struct DevTicketSheet: View {
    let ticket: SupportTicket
    @ObservedObject var vm: DevPagesViewModel
    @Binding var isPresented: Bool

    @State private var status: String = ""
    @State private var resolution: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(ticket.title)
                        .font(.ssH2).foregroundStyle(Color.ssGreen)
                    Text(ticket.ticketId).font(.ssTiny.monospaced())
                        .foregroundStyle(Color.ssGrey)
                    GoldRule(width: 32)

                    if let cat = ticket.category {
                        Text(cat).font(.ssCaption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.ssGold).clipShape(Capsule())
                    }
                    if let reporter = ticket.reporterName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reporter).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                            if let email = ticket.reporterEmail {
                                Text(email).font(.ssCaption).foregroundStyle(Color.ssGrey)
                            }
                            if let role = ticket.reporterAccess {
                                Text(role).font(.ssTiny).foregroundStyle(Color.ssGrey)
                            }
                        }
                    }
                    if let desc = ticket.description {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description").font(.ssCaption).foregroundStyle(Color.ssGrey)
                            Text(desc).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if let r = ticket.reproSteps, !r.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Steps to reproduce").font(.ssCaption).foregroundStyle(Color.ssGrey)
                            Text(r).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if let ua = ticket.userAgent {
                        Text("UA: \(ua)").font(.ssTiny.monospaced()).foregroundStyle(Color.ssGrey)
                    }

                    GoldRule(width: 32)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey("dev.support_set_status"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                        Picker(selection: $status) {
                            Text(LocalizedStringKey("dev.support_open")).tag("Open")
                            Text(LocalizedStringKey("dev.support_in_progress")).tag("InProgress")
                            Text(LocalizedStringKey("dev.support_resolved")).tag("Resolved")
                            Text(LocalizedStringKey("dev.support_closed")).tag("Closed")
                        } label: { EmptyView() }
                        .pickerStyle(.segmented)
                    }

                    if status == "Resolved" || status == "Closed" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("dev.support_resolution"))
                                .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            TextEditor(text: $resolution)
                                .frame(minHeight: 80)
                                .padding(6).background(Color.ssPale)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .scrollContentBackground(.hidden)
                        }
                    }

                    Button {
                        Task {
                            await vm.updateStatus(ticket: ticket, status: status, resolution: resolution)
                            isPresented = false
                        }
                    } label: {
                        HStack {
                            if vm.inFlightId != nil { ProgressView().tint(Color.ssCream) }
                            Text(LocalizedStringKey("common.save")).font(.ssBodyBold)
                        }
                        .foregroundStyle(Color.ssCream)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.ssGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.inFlightId != nil)
                }
                .padding(20)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("dev.support_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.close")) { isPresented = false }
                        .foregroundStyle(Color.ssGrey)
                }
            }
            .ssToast(Binding(get: { vm.toast }, set: { vm.toast = $0 }))
        }
        .onAppear {
            status = ticket.status ?? "Open"
            resolution = ticket.resolutionNote ?? ""
        }
    }
}

@MainActor
final class DevPagesViewModel: ObservableObject {
    @Published var rows: [SupportTicket] = []
    @Published var isLoading: Bool = false
    @Published var toast: Toast?
    @Published var filter: Filter = .open
    @Published var inFlightId: String?

    enum Filter: String, CaseIterable, Identifiable {
        case all, open
        var id: String { rawValue }
    }

    var filteredRows: [SupportTicket] {
        switch filter {
        case .all:  return rows
        case .open: return rows.filter { ($0.status ?? "") == "Open" || ($0.status ?? "") == "InProgress" }
        }
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            rows = try await APIClient.shared.call("support.list", as: [SupportTicket].self)
        } catch let apiError as APIError where !apiError.isCancellation {
            toast = .error(apiError.localizedMessage)
        } catch { }
    }

    func updateStatus(ticket: SupportTicket, status: String, resolution: String) async {
        inFlightId = ticket.ticketId
        defer { inFlightId = nil }
        var params: [String: Any] = ["ticket_id": ticket.ticketId, "status": status]
        if !resolution.isEmpty { params["resolution_note"] = resolution }
        do {
            _ = try await APIClient.shared.call(
                "support.updateStatus", params: params, as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("dev.support_updated_ok"))
            await load()
        } catch let apiError as APIError where !apiError.isCancellation {
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }
}
