import SwiftUI

/// Head's primary-review queue OR admin's final-approval queue —
/// spec §9.7 / §10.9. Mode passed at construction time.
struct HoursApprovalView: View {
    let mode: HoursApprovalViewModel.Mode
    @StateObject private var vm: HoursApprovalViewModel
    @State private var rejectTarget: HoursAdminRow?
    @State private var rejectReason: String = ""

    init(mode: HoursApprovalViewModel.Mode = .headQueue) {
        self.mode = mode
        _vm = StateObject(wrappedValue: HoursApprovalViewModel(mode: mode))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey(
                    mode == .headQueue ? "hp.tabs.hours" : "ap.hours.final_title"
                ))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .ssToast($vm.toast)
                .sheet(item: $rejectTarget) { row in
                    rejectSheet(for: row)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.rows.isEmpty, vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let err = vm.errorMessage, vm.rows.isEmpty {
            errorState(err)
        } else if vm.rows.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.rows) { row in
                    rowCard(row)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func rowCard(_ row: HoursAdminRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.displayMember)
                        .font(.ssBodyBold)
                        .foregroundStyle(Color.ssGreen)
                    HStack(spacing: 6) {
                        if row.isAutoMeetingRow {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundStyle(Color.ssGold)
                        }
                        Text(row.displayTitle)
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssCharcoal)
                            .lineLimit(2)
                    }
                    if let role = row.opportunityRoleName {
                        Text(role)
                            .font(.ssTiny)
                            .foregroundStyle(Color.ssGrey)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1fh", row.totalHours))
                        .font(.ssDisplay.weight(.semibold))
                        .foregroundStyle(Color.ssCharcoal)
                    statusBadge(row.approvalStatus)
                }
            }
            if let date = MemberFieldMaps.displayDate(row.displayDate) {
                Text(date)
                    .font(.ssTiny)
                    .foregroundStyle(Color.ssGrey)
            }
            HStack(spacing: 10) {
                approveButton(row)
                rejectButton(row)
            }
        }
        .padding(14)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func approveButton(_ row: HoursAdminRow) -> some View {
        let label: String = {
            switch (mode, row.approvalStatus) {
            case (.headQueue, "Draft"):           return "hp.hours.btn_primary_approve"
            case (.headQueue, "PrimaryApproved"): return "hp.hours.btn_final_approve"
            case (.adminFinalApproval, _):        return "hp.hours.btn_final_approve"
            default:                               return "hp.hours.btn_approve"
            }
        }()
        let busy = vm.rowInFlight == row.id
        return Button {
            Task { await vm.approve(row) }
        } label: {
            HStack(spacing: 6) {
                if busy {
                    ProgressView().tint(Color.ssCream)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(LocalizedStringKey(label))
            }
            .font(.ssCaption.weight(.semibold))
            .foregroundStyle(Color.ssCream)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.ssGreen)
            .clipShape(Capsule())
        }
        .disabled(busy || vm.rowInFlight != nil)
    }

    private func rejectButton(_ row: HoursAdminRow) -> some View {
        Button {
            rejectReason = ""
            rejectTarget = row
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                Text(LocalizedStringKey("hp.hours.btn_reject"))
            }
            .font(.ssCaption.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.ssCream)
            .overlay(Capsule().stroke(.red.opacity(0.4), lineWidth: 1))
            .clipShape(Capsule())
        }
        .disabled(vm.rowInFlight != nil)
    }

    private func rejectSheet(for row: HoursAdminRow) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.displayMember)
                            .font(.ssH2)
                            .foregroundStyle(Color.ssGreen)
                        Text(row.displayTitle)
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey("hp.hours.reject_reason_label"))
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                        TextField(
                            LocalizedStringKey("hp.hours.reject_reason_placeholder"),
                            text: $rejectReason,
                            axis: .vertical
                        )
                        .font(.ssBody)
                        .foregroundStyle(Color.ssCharcoal)
                        .lineLimit(4, reservesSpace: true)
                        .padding(12)
                        .background(Color.ssPale)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.ssLight, lineWidth: 1)
                        )
                    }
                    Button(role: .destructive) {
                        Task {
                            await vm.reject(row, reason: rejectReason)
                            rejectTarget = nil
                        }
                    } label: {
                        ZStack {
                            Text(LocalizedStringKey("hp.hours.confirm_reject"))
                                .font(.ssBodyBold)
                                .foregroundStyle(.white)
                                .opacity(vm.rowInFlight == row.id ? 0 : 1)
                            if vm.rowInFlight == row.id {
                                ProgressView().tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.rowInFlight != nil)
                }
                .padding(20)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .ssToast(Binding(
                get: { vm.toast },
                set: { vm.toast = $0 }
            ))
            .navigationTitle(LocalizedStringKey("hp.hours.reject_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) {
                        rejectTarget = nil
                    }
                    .foregroundStyle(Color.ssGrey)
                    .disabled(vm.rowInFlight != nil)
                }
            }
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Draft":           return (.ssGrey,  "mp.hours.status_draft")
            case "PrimaryApproved": return (.ssGold,  "mp.hours.status_primary")
            case "FinalApproved":   return (.ssGreen, "mp.hours.status_final")
            case "Rejected":        return (.red,     "mp.hours.status_rejected")
            default:                return (.ssGrey,  "")
            }
        }()
        return Text(key.isEmpty ? status : NSLocalizedString(key, comment: ""))
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGreen)
            Text(LocalizedStringKey("hp.hours.empty"))
                .font(.ssBody)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }

    private func errorState(_ message: String) -> some View {
        let display = message.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "err.unknown")
            : message
        return VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(display)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { Task { await vm.load() } } label: {
                Text(LocalizedStringKey("common.retry"))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCream)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.ssGreen)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }
}
