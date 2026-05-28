import SwiftUI

/// Member-mode tasks list — spec §8.5.
struct MyTasksView: View {
    @StateObject private var vm = MyTasksViewModel()
    @State private var detail: Assignment?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("mp.tabs.tasks"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .sheet(item: $detail) { a in
                    AssignmentDetailSheet(assignment: a) {
                        detail = nil
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.assignments.isEmpty, vm.isLoading {
            ProgressView()
                .tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let error = vm.errorMessage, vm.assignments.isEmpty {
            errorState(error)
        } else if vm.assignments.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(MyTasksViewModel.Section.allCases) { section in
                    let rows = vm.assignments(in: section)
                    if !rows.isEmpty {
                        sectionView(section, rows: rows)
                    }
                }
            }
            .ipadContentWidth()
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func sectionView(_ section: MyTasksViewModel.Section,
                             rows: [Assignment]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(latin(for: section))
                .font(.ssLatinLabel)
                .tracking(2)
                .foregroundStyle(Color.ssGold)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(LocalizedStringKey(section.localizationKey))
                    .font(.ssH2)
                    .foregroundStyle(Color.ssGreen)
                Text("(\(rows.count))")
                    .font(.ssCaption)
                    .foregroundStyle(Color.ssGrey)
            }
            .padding(.bottom, 4)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, a in
                    row(a, isLast: idx == rows.count - 1)
                }
            }
            .background(Color.ssPale)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
            )
        }
    }

    private func latin(for section: MyTasksViewModel.Section) -> String {
        switch section {
        case .upcoming:  return "Upcoming"
        case .completed: return "Completed"
        case .missed:    return "Missed"
        }
    }

    private func row(_ a: Assignment, isLast: Bool) -> some View {
        Button {
            detail = a
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(a.displayProject)
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCharcoal)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    Label(a.displayRole, systemImage: "person.text.rectangle")
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssGrey)
                    if let date = MemberFieldMaps.displayDate(a.eventDate) {
                        Label(date, systemImage: "calendar")
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGrey)
                    }
                }
                HStack(spacing: 8) {
                    statusBadge(a.attendanceStatus ?? "Pending")
                    if let h = a.hoursLogged, h > 0 {
                        Label(String(format: "%.1fh", h),
                              systemImage: "clock.badge.checkmark")
                            .font(.ssCaption)
                            .foregroundStyle(Color.ssGreen)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .fill(Color.ssLight.opacity(0.6))
                    .frame(height: isLast ? 0 : 0.5)
                    .padding(.horizontal, 14),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, key): (Color, String) = {
            switch status {
            case "Attended":  return (.ssGreen, "mp.tasks.status_attended")
            case "Absent":    return (.red,     "mp.tasks.status_absent")
            case "Excused":   return (.ssGold,  "mp.tasks.status_excused")
            case "Pending":   return (.ssGrey,  "mp.tasks.status_pending")
            default:          return (.ssGrey,  "")
            }
        }()
        return Text(key.isEmpty ? status : NSLocalizedString(key, comment: ""))
            .font(.ssCaption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey("mp.tasks.empty"))
                .font(.ssBody)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
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
}

// MARK: - Detail sheet

private struct AssignmentDetailSheet: View {
    let assignment: Assignment
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    metaSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("mp.tasks.detail_title"))
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
            Text(assignment.displayProject)
                .font(.ssH2)
                .foregroundStyle(Color.ssGreen)
            HStack(spacing: 8) {
                if let committee = assignment.committeeName {
                    chip(committee, color: .ssGreen)
                }
                chip(assignment.displayRole, color: .ssGold)
            }
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.ssCaption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    private var metaSection: some View {
        VStack(spacing: 0) {
            metaRow("mp.tasks.row_date",
                    value: MemberFieldMaps.displayDate(assignment.eventDate))
            metaRow("mp.tasks.row_time",
                    value: timeRange)
            metaRow("mp.tasks.row_location", value: assignment.location)
            metaRow("mp.tasks.row_status",
                    value: NSLocalizedString(statusKey, comment: ""))
            if let h = assignment.hoursLogged, h > 0 {
                metaRow("mp.tasks.row_hours_recorded",
                        value: String(format: "%.1f", h))
            } else if (assignment.attendanceStatus ?? "") == "Attended" {
                metaRow("mp.tasks.row_hours_recorded",
                        value: NSLocalizedString("mp.tasks.no_hours_yet", comment: ""))
            }
        }
        .background(Color.ssPale)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
    }

    private var timeRange: String? {
        switch (assignment.startTime, assignment.endTime) {
        case (.some(let s), .some(let e)): return "\(s) – \(e)"
        case (.some(let s), nil):           return s
        case (nil, .some(let e)):           return e
        case (nil, nil):                    return nil
        }
    }

    private var statusKey: String {
        switch assignment.attendanceStatus ?? "Pending" {
        case "Attended": return "mp.tasks.status_attended"
        case "Absent":   return "mp.tasks.status_absent"
        case "Excused":  return "mp.tasks.status_excused"
        default:         return "mp.tasks.status_pending"
        }
    }

    private func metaRow(_ labelKey: LocalizedStringKey, value: String?) -> some View {
        HStack(alignment: .top) {
            Text(labelKey)
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .frame(width: 110, alignment: .leading)
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
