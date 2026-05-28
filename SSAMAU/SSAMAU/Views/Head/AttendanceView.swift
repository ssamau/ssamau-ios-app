import SwiftUI

/// Head-mode attendance tab — spec §9.6. Two modes (project + meeting)
/// share the head.attendance.record endpoint server-side, distinguished
/// by which set of fields is sent.
struct AttendanceView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = AttendanceViewModel()
    @State private var recording: Bool = false
    @State private var deleteTarget: AttendanceRow?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .navigationTitle(LocalizedStringKey("hp.tabs.attendance"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load(committeeId: session.currentUser?.committeeId) }
                .task         { await vm.load(committeeId: session.currentUser?.committeeId) }
                .ssToast($vm.toast)
                .sheet(isPresented: $recording) {
                    RecordAttendanceSheet(vm: vm, isPresented: $recording) {
                        await vm.load(committeeId: session.currentUser?.committeeId)
                    }
                    .iPadSheet(.xlarge)
                }
                .confirmationDialog(
                    LocalizedStringKey("hp.attendance.delete_confirm"),
                    isPresented: Binding(
                        get: { deleteTarget != nil },
                        set: { if !$0 { deleteTarget = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    if let row = deleteTarget {
                        Button(LocalizedStringKey("common.delete"), role: .destructive) {
                            Task { await vm.deleteRow(row); deleteTarget = nil }
                        }
                    }
                    Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
                }
            Button { recording = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text(LocalizedStringKey("hp.attendance.record_btn"))
                }
                .font(.ssBodyBold)
                .foregroundStyle(Color.ssCream)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Color.ssGreen)
                .clipShape(Capsule())
                .shadow(radius: 4)
            }
            .padding(20)
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
                        Text(LocalizedStringKey("hp.attendance.empty"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.rows) { row in
                                rowCard(row)
                            }
                        }
                    }
                }
                // Force full-width so the empty-state Text doesn't
                // collapse the VStack to its intrinsic width — which
                // also shifts the FAB inward via the bottomTrailing
                // alignment of the parent ZStack.
                .frame(maxWidth: .infinity)
                .ipadContentWidth()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 80)
            }
        }
    }

    private func rowCard(_ row: AttendanceRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: row.isMeeting ? "person.3" : "calendar")
                    .font(.caption).foregroundStyle(Color.ssGold)
                Text(row.displayName)
                    .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                Spacer()
                statusBadge(row.attendanceStatus ?? "Present")
            }
            if let title = row.meetingTitle, !title.isEmpty {
                Text(title).font(.ssCaption).foregroundStyle(Color.ssCharcoal)
            } else if let project = row.projectName {
                Text(project).font(.ssCaption).foregroundStyle(Color.ssCharcoal)
            }
            HStack(spacing: 12) {
                if let d = MemberFieldMaps.displayDate(row.meetingDate ?? row.projectEventDate) {
                    Label(d, systemImage: "calendar")
                        .font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
                if let h = row.meetingHours, h > 0 {
                    Label(String(format: "%.1f h", h), systemImage: "clock")
                        .font(.ssTiny).foregroundStyle(Color.ssGrey)
                }
                if let loc = row.meetingLocation, !loc.isEmpty {
                    Label(loc, systemImage: "mappin.and.ellipse")
                        .font(.ssTiny).foregroundStyle(Color.ssGrey)
                        .lineLimit(1)
                }
            }
            // Only show delete for rows this head recorded
            if row.recordedBy == session.currentUser?.id {
                HStack {
                    Spacer()
                    Button(role: .destructive) { deleteTarget = row } label: {
                        Label(LocalizedStringKey("common.delete"), systemImage: "trash")
                            .font(.ssTiny.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.ssCream)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.red.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.inFlightId != nil)
                }
            }
        }
        .padding(12)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusBadge(_ status: String) -> some View {
        let (color, label): (Color, String) = {
            switch status {
            case "Present", "Attended": return (.ssGreen, NSLocalizedString("hp.opps.att_attended", comment: ""))
            case "Absent":              return (.red,     NSLocalizedString("hp.opps.att_absent", comment: ""))
            case "Excused":             return (.ssGold,  NSLocalizedString("hp.opps.att_excused", comment: ""))
            default:                    return (.ssGrey,  status)
            }
        }()
        return Text(label)
            .font(.ssTiny.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Record sheet

private struct RecordAttendanceSheet: View {
    @ObservedObject var vm: AttendanceViewModel
    @Binding var isPresented: Bool
    /// Parent-supplied refresh callback (carries the parent's committee scope).
    let onSubmitted: () async -> Void

    @State private var mode: Mode = .project
    @State private var selectedProjectId: String = ""
    @State private var selectedMemberId: String = ""
    @State private var status: String = "Present"
    @State private var notes: String = ""
    @State private var hoursText: String = ""

    // Meeting fields
    @State private var meetingTitle: String = ""
    @State private var meetingType: String = "online"
    @State private var meetingDate: Date = Date()
    @State private var meetingStart: String = "18:00"
    @State private var meetingLocation: String = ""

    enum Mode: String, CaseIterable, Identifiable {
        case project, meeting
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Mode", selection: $mode) {
                        Text(LocalizedStringKey("hp.attendance.mode_project")).tag(Mode.project)
                        Text(LocalizedStringKey("hp.attendance.mode_meeting")).tag(Mode.meeting)
                    }
                    .pickerStyle(.segmented)

                    if mode == .project {
                        projectFields
                    } else {
                        meetingFields
                    }

                    field("hp.attendance.pick_member") {
                        Menu {
                            Button("—") { selectedMemberId = "" }
                            ForEach(activeMembers) { m in
                                if let mid = m.memberId {
                                    Button(m.displayName) { selectedMemberId = mid }
                                }
                            }
                        } label: {
                            pickerLabel(selectedMember?.displayName ?? "—")
                        }
                    }

                    field("hp.attendance.status") {
                        Picker(selection: $status) {
                            Text(LocalizedStringKey("hp.opps.att_attended")).tag("Present")
                            Text(LocalizedStringKey("hp.opps.att_absent")).tag("Absent")
                            Text(LocalizedStringKey("hp.opps.att_excused")).tag("Excused")
                        } label: { EmptyView() }
                        .pickerStyle(.segmented)
                    }

                    field("hp.attendance.meeting_hours") {
                        TextField("0.0 (optional)", text: $hoursText)
                            .keyboardType(.decimalPad)
                            .padding(10)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    field("common.notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                            .padding(6)
                            .background(Color.ssPale)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .scrollContentBackground(.hidden)
                    }

                    submitButton
                }
                .padding(20)
            }
            .background(Color.ssCream.ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("hp.attendance.sheet_title"))
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
            if selectedProjectId.isEmpty,
               let first = vm.projects.first {
                selectedProjectId = first.id
            }
        }
    }

    @ViewBuilder
    private var projectFields: some View {
        if vm.projects.isEmpty {
            Text(LocalizedStringKey("hp.attendance.no_projects"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .padding(.vertical, 12)
        } else {
            field("hp.attendance.pick_project") {
                Menu {
                    ForEach(vm.projects) { p in
                        Button(p.name) { selectedProjectId = p.id }
                    }
                } label: {
                    pickerLabel(selectedProject?.name ?? "—")
                }
            }
        }
    }

    @ViewBuilder
    private var meetingFields: some View {
        field("hp.attendance.meeting_title") {
            TextField("", text: $meetingTitle)
                .padding(10)
                .background(Color.ssPale)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        field("hp.attendance.meeting_type") {
            Picker(selection: $meetingType) {
                Text(LocalizedStringKey("hp.attendance.meeting_type_online")).tag("online")
                Text(LocalizedStringKey("hp.attendance.meeting_type_in_person")).tag("in_person")
            } label: { EmptyView() }
            .pickerStyle(.segmented)
        }
        field("hp.attendance.meeting_date") {
            DatePicker("", selection: $meetingDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        field("hp.attendance.meeting_start") {
            TextField("18:00", text: $meetingStart)
                .keyboardType(.numbersAndPunctuation)
                .padding(10)
                .background(Color.ssPale)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        field("hp.attendance.meeting_location") {
            TextField("", text: $meetingLocation)
                .padding(10)
                .background(Color.ssPale)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var submitButton: some View {
        Button {
            Task {
                let hours = Double(hoursText)
                let memberId: String? = selectedMemberId.isEmpty ? nil : selectedMemberId
                let ok: Bool
                if mode == .project {
                    guard !selectedProjectId.isEmpty else { return }
                    ok = await vm.recordProjectAttendance(
                        projectId: selectedProjectId,
                        memberId: memberId, status: status,
                        notes: notes.trimmingCharacters(in: .whitespaces),
                        hours: hours
                    )
                } else {
                    let title = meetingTitle.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    ok = await vm.recordMeetingAttendance(
                        title: title, type: meetingType, date: meetingDate,
                        startTime: meetingStart.trimmingCharacters(in: .whitespaces),
                        location: meetingLocation.trimmingCharacters(in: .whitespaces),
                        memberId: memberId, status: status,
                        notes: notes.trimmingCharacters(in: .whitespaces),
                        hours: hours
                    )
                }
                if ok {
                    await onSubmitted()
                    isPresented = false
                }
            }
        } label: {
            HStack {
                if vm.inFlightId != nil { ProgressView().tint(Color.ssCream) }
                Text(LocalizedStringKey("hp.attendance.record_btn"))
                    .font(.ssBodyBold)
            }
            .foregroundStyle(Color.ssCream)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(canSubmit ? Color.ssGreen : Color.ssGrey)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(vm.inFlightId != nil || !canSubmit)
    }

    private var canSubmit: Bool {
        if mode == .project { return !selectedProjectId.isEmpty }
        return !meetingTitle.trimmingCharacters(in: .whitespaces).isEmpty
            && !meetingStart.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var activeMembers: [MemberAccountRow] {
        // Only members with a real member_id are recordable as attendees;
        // member-less admin/dev rows are excluded from the picker.
        vm.members
            .filter { $0.memberId != nil }
            .sorted { $0.displayName < $1.displayName }
    }
    private var selectedMember: MemberAccountRow? {
        vm.members.first { $0.memberId == selectedMemberId }
    }
    private var selectedProject: Project? {
        vm.projects.first { $0.id == selectedProjectId }
    }

    private func field<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(key))
                .font(.ssCaption).foregroundStyle(Color.ssGrey)
            content()
        }
    }
    private func pickerLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(.ssBody).foregroundStyle(Color.ssCharcoal)
            Spacer()
            Image(systemName: "chevron.down").font(.caption).foregroundStyle(Color.ssGrey)
        }
        .padding(10)
        .background(Color.ssPale)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
