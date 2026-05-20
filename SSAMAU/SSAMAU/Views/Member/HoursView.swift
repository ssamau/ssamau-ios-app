import SwiftUI

/// Member-mode hours screen — spec §8.6.
struct HoursView: View {
    @StateObject private var vm = HoursViewModel()
    @State private var showLogSheet = false
    @State private var detailRow: HoursRow?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("mp.tabs.hours"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .overlay(alignment: .bottomTrailing) { fab }
                .overlay(alignment: .bottom) { toast }
                .sheet(isPresented: $showLogSheet) {
                    LogHoursSheet(viewModel: vm, isPresented: $showLogSheet)
                }
                .sheet(item: $detailRow) { row in
                    HoursDetailSheet(row: row) { detailRow = nil }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.rows.isEmpty, vm.isLoading {
            ProgressView()
                .tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let error = vm.errorMessage, vm.rows.isEmpty {
            errorState(error)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 18) {
                totalPill
                if vm.rows.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.rows) { row in
                            rowView(row)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 80)   // clear the FAB
        }
    }

    private var totalPill: some View {
        VStack(spacing: 6) {
            Text(String(format: "%.1f", vm.totalFinalApprovedHours))
                .font(.ssDisplay)
                .foregroundStyle(Color.ssGreen)
            Text(LocalizedStringKey("mp.hours.total_label"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rowView(_ row: HoursRow) -> some View {
        Button {
            detailRow = row
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        if row.isAutoMeetingRow {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.ssGold)
                                .font(.caption)
                        }
                        Text(row.displayTitle)
                            .font(.ssBodyBold)
                            .foregroundStyle(Color.ssCharcoal)
                            .lineLimit(2)
                    }
                    Spacer()
                    statusBadge(row.approvalStatus)
                }
                HStack(spacing: 10) {
                    if let role = row.opportunityRoleName {
                        Label(role, systemImage: "person.text.rectangle")
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                    }
                    if let date = MemberFieldMaps.displayDate(row.displayDate) {
                        Label(date, systemImage: "calendar")
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                    }
                    Spacer()
                    Text(String(format: "%.1fh", row.totalHours))
                        .font(.ssBodyBold)
                        .foregroundStyle(Color.ssGreen)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ssPale)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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

    private var fab: some View {
        Button {
            showLogSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text(LocalizedStringKey("mp.hours.log_btn"))
            }
            .font(.ssBodyBold)
            .foregroundStyle(Color.ssCream)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.ssGreen)
            .clipShape(Capsule())
            .shadow(color: Color.ssCharcoal.opacity(0.2), radius: 6, y: 3)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .disabled(vm.loggableAssignments.isEmpty)
        .opacity(vm.loggableAssignments.isEmpty ? 0.6 : 1)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey("mp.hours.empty"))
                .font(.ssBody)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(message)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await vm.load() }
            } label: {
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

    @ViewBuilder
    private var toast: some View {
        if let msg = vm.toastMessage {
            Text(msg)
                .font(.ssCaption)
                .foregroundStyle(Color.ssCream)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.ssGreen)
                .clipShape(Capsule())
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    vm.toastMessage = nil
                }
        }
    }
}

// MARK: - Detail sheet

private struct HoursDetailSheet: View {
    let row: HoursRow
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    breakdown
                    if let n = row.notes, !n.isEmpty, !row.isAutoMeetingRow {
                        notesBlock(n)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("mp.hours.detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.cancel")) { onDismiss() }
                        .foregroundStyle(Color.ssGrey)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if row.isAutoMeetingRow {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.ssGold)
                }
                Text(row.displayTitle)
                    .font(.ssH2)
                    .foregroundStyle(Color.ssGreen)
            }
            if let role = row.opportunityRoleName {
                Text(role)
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssGrey)
            }
        }
    }

    private var breakdown: some View {
        VStack(spacing: 0) {
            metaRow("mp.hours.row_status",
                    value: NSLocalizedString(statusKey, comment: ""))
            metaRow("mp.hours.row_date",
                    value: MemberFieldMaps.displayDate(row.displayDate))
            metaRow("mp.hours.before",  value: String(format: "%.1f", row.hoursBefore))
            metaRow("mp.hours.during",  value: String(format: "%.1f", row.hoursDuring))
            metaRow("mp.hours.after",   value: String(format: "%.1f", row.hoursAfter))
            metaRow("mp.hours.total",   value: String(format: "%.1f", row.totalHours))
            metaRow("mp.hours.row_recorded",
                    value: MemberFieldMaps.displayDate(row.recordedAt))
        }
        .background(Color.ssPale)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
    }

    private var statusKey: String {
        switch row.approvalStatus {
        case "Draft":           return "mp.hours.status_draft"
        case "PrimaryApproved": return "mp.hours.status_primary"
        case "FinalApproved":   return "mp.hours.status_final"
        case "Rejected":        return "mp.hours.status_rejected"
        default:                return "mp.hours.status_draft"
        }
    }

    private func notesBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("mp.hours.notes_label"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
            Text(text)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ssPale)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.ssLight, lineWidth: 1)
                )
        }
    }

    private func metaRow(_ labelKey: LocalizedStringKey, value: String?) -> some View {
        HStack(alignment: .top) {
            Text(labelKey)
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .frame(width: 130, alignment: .leading)
            Text(value?.isEmpty == false ? value! : "—")
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.ssLight.opacity(0.6))
                .frame(height: 0.5)
                .padding(.horizontal, 14),
            alignment: .bottom
        )
    }
}
