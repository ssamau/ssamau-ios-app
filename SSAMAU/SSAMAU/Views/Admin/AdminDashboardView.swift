import SwiftUI

/// Admin landing — five KPIs + top volunteers + committee hours +
/// recent projects. Mirrors the web admin's dashboard tab.
struct AdminDashboardView: View {
    @StateObject private var vm = AdminDashboardViewModel()

    var body: some View {
        content
            .navigationTitle(LocalizedStringKey("ap.dash.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.ssCream)
            .refreshable { await vm.load() }
            .task { await vm.load() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.summary == nil, vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let err = vm.errorMessage, vm.summary == nil {
            errorState(err)
        } else if let s = vm.summary {
            ScrollView {
                VStack(spacing: 14) {
                    kpis(s.stats)
                    section(LocalizedStringKey("ap.dash.top_volunteers"), systemImage: "trophy") {
                        if s.topVolunteers.isEmpty {
                            Text("—").font(.ssCaption).foregroundStyle(Color.ssGrey)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(s.topVolunteers) { v in
                                    HStack {
                                        Text(v.name).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                                        Spacer()
                                        Text(String(format: "%.1f h", v.hours))
                                            .font(.ssBodyBold).foregroundStyle(Color.ssGold)
                                    }
                                }
                            }
                        }
                    }
                    section(LocalizedStringKey("ap.dash.committee_hours"), systemImage: "building.2") {
                        if s.committeeHours.isEmpty {
                            Text("—").font(.ssCaption).foregroundStyle(Color.ssGrey)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(s.committeeHours) { c in
                                    HStack {
                                        Text(c.committeeName).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                                        Spacer()
                                        Text(String(format: "%.1f h", c.hours))
                                            .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                                    }
                                }
                            }
                        }
                    }
                    section(LocalizedStringKey("ap.dash.recent_projects"), systemImage: "calendar") {
                        if s.recentProjects.isEmpty {
                            Text("—").font(.ssCaption).foregroundStyle(Color.ssGrey)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(s.recentProjects) { p in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.projectName)
                                                .font(.ssBody).foregroundStyle(Color.ssCharcoal)
                                            if let d = MemberFieldMaps.displayDate(p.eventDate) {
                                                Text(d).font(.ssTiny).foregroundStyle(Color.ssGrey)
                                            }
                                        }
                                        Spacer()
                                        Text(localizedProjectStatus(p.projectStatus))
                                            .font(.ssTiny.weight(.semibold))
                                            .foregroundStyle(Color.ssGreen)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        } else {
            Text("—").font(.ssCaption).foregroundStyle(Color.ssGrey)
        }
    }

    private func kpis(_ counts: DashboardStats.Counts) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ], spacing: 12) {
            kpi("ap.dash.active_members", value: "\(counts.activeMembers)", icon: "person.2.fill")
            kpi("ap.dash.total_members", value: "\(counts.totalMembers)", icon: "person.3")
            kpi("ap.dash.total_projects", value: "\(counts.totalProjects)", icon: "folder")
            kpi("ap.dash.total_hours", value: String(format: "%.0f", counts.totalHours), icon: "clock")
            kpi("ap.dash.total_committees", value: "\(counts.totalCommittees)", icon: "building.2")
        }
    }

    private func kpi(_ key: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.title3).foregroundStyle(Color.ssGold)
                Spacer()
                Text(value).font(.ssH1).foregroundStyle(Color.ssGreen)
            }
            Text(LocalizedStringKey(key))
                .font(.ssCaption).foregroundStyle(Color.ssGrey)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func section<Content: View>(_ title: LocalizedStringKey, systemImage: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).foregroundStyle(Color.ssGold)
                Text(title).font(.ssH2).foregroundStyle(Color.ssGreen)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Project-status enum from the server (raw English) → localized label.
    /// Falls through to the raw value for any unknown/legacy status.
    private func localizedProjectStatus(_ raw: String?) -> String {
        switch raw ?? "" {
        case "Planned":   return NSLocalizedString("hp.projects.status_planned", comment: "")
        case "Active":    return NSLocalizedString("hp.projects.status_active", comment: "")
        case "Done":      return NSLocalizedString("hp.projects.status_done", comment: "")
        case "Cancelled": return NSLocalizedString("hp.projects.status_cancelled", comment: "")
        default:          return raw ?? "—"
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36)).foregroundStyle(Color.ssGold)
            Text(message).font(.ssBody).foregroundStyle(Color.ssCharcoal)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { Task { await vm.load() } } label: {
                Text(LocalizedStringKey("common.retry"))
                    .font(.ssBodyBold).foregroundStyle(Color.ssCream)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.ssGreen).clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }
}
