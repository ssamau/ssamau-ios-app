import SwiftUI

/// Head-mode dashboard — spec §9.1.
///
/// Server returns: committee meta, 4 KPI counts (members, pending
/// applications, hours pending head action, open opportunities), top
/// 5 pending applications, top 5 hours rows awaiting primary review.
struct DashboardView: View {
    @StateObject private var vm = HeadDashboardViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(LocalizedStringKey("hp.tabs.dashboard"))
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.ssCream)
                .refreshable { await vm.load() }
                .task { await vm.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let summary = vm.summary {
            loaded(summary)
        } else if vm.isLoading {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ssCream)
        } else if let err = vm.errorMessage {
            errorState(err)
        } else {
            ProgressView().tint(Color.ssGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loaded(_ summary: HeadDashboardSummary) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                header(summary.committee)
                kpiGrid(summary.counts)
                section(latin: "Hours awaiting review",
                        arabic: "hp.dash.hours_pending_title") {
                    if summary.hoursPending.isEmpty {
                        emptyInline(LocalizedStringKey("hp.dash.no_pending_hours"))
                    } else {
                        ForEach(Array(summary.hoursPending.enumerated()), id: \.element.id) { idx, h in
                            pendingHoursRow(h, isLast: idx == summary.hoursPending.count - 1)
                        }
                    }
                }
                section(latin: "Pending applications",
                        arabic: "hp.dash.pending_applications_title") {
                    if summary.pendingApplications.isEmpty {
                        emptyInline(LocalizedStringKey("hp.dash.no_pending_apps"))
                    } else {
                        ForEach(Array(summary.pendingApplications.enumerated()), id: \.element.id) { idx, a in
                            pendingApplicationRow(a, isLast: idx == summary.pendingApplications.count - 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Header

    private func header(_ committee: HeadCommitteeMeta) -> some View {
        VStack(spacing: 8) {
            Text(LocalizedStringKey("hp.dash.welcome"))
                .font(.ssLatinLabel)
                .tracking(2)
                .foregroundStyle(Color.ssGold)
            Text(committee.committeeName)
                .font(.ssH1)
                .foregroundStyle(Color.ssGreen)
                .multilineTextAlignment(.center)
            GoldRule(width: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - KPI grid

    private func kpiGrid(_ counts: HeadDashboardCounts) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            kpiCard(value: counts.membersCount,
                    labelKey: "hp.dash.kpi_members",
                    systemImage: "person.2.fill")
            kpiCard(value: counts.openOpportunitiesCount,
                    labelKey: "hp.dash.kpi_opportunities",
                    systemImage: "list.bullet.rectangle.fill")
            kpiCard(value: counts.hoursPendingCount,
                    labelKey: "hp.dash.kpi_hours_pending",
                    systemImage: "clock.badge.exclamationmark",
                    accent: counts.hoursPendingCount > 0 ? .ssGold : .ssGrey)
            kpiCard(value: counts.pendingApplicationsCount,
                    labelKey: "hp.dash.kpi_applications",
                    systemImage: "doc.text.fill",
                    accent: counts.pendingApplicationsCount > 0 ? .ssGold : .ssGrey)
        }
    }

    private func kpiCard(value: Int,
                         labelKey: LocalizedStringKey,
                         systemImage: String,
                         accent: Color = .ssGreen) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(accent)
            Text("\(value)")
                .font(.ssDisplay)
                .foregroundStyle(Color.ssCharcoal)
            Text(labelKey)
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sections + rows

    private func section<Content: View>(
        latin: String,
        arabic: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(latin)
                .font(.ssLatinLabel)
                .tracking(2)
                .foregroundStyle(Color.ssGold)
            Text(arabic)
                .font(.ssH2)
                .foregroundStyle(Color.ssGreen)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(Color.ssPale)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func pendingHoursRow(_ h: PendingHoursRow, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(h.displayMember)
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssCharcoal)
                Spacer()
                Text(String(format: "%.1fh", h.totalHours))
                    .font(.ssBodyBold)
                    .foregroundStyle(Color.ssGreen)
            }
            HStack(spacing: 8) {
                if let project = h.projectName {
                    Text(project)
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssGrey)
                        .lineLimit(1)
                }
                if let status = h.approvalStatus {
                    statusBadge(status)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle()
                .fill(Color.ssLight.opacity(0.6))
                .frame(height: isLast ? 0 : 0.5)
                .padding(.horizontal, 14),
            alignment: .bottom
        )
    }

    private func pendingApplicationRow(_ a: PendingApplicationRow, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(a.displayName)
                .font(.ssBodyBold)
                .foregroundStyle(Color.ssCharcoal)
            HStack(spacing: 8) {
                if let email = a.email {
                    Text(email)
                        .font(.ssCaption)
                        .foregroundStyle(Color.ssGrey)
                        .lineLimit(1)
                }
                if let date = MemberFieldMaps.displayDate(a.createdAt) {
                    Text(date)
                        .font(.ssTiny)
                        .foregroundStyle(Color.ssGrey)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle()
                .fill(Color.ssLight.opacity(0.6))
                .frame(height: isLast ? 0 : 0.5)
                .padding(.horizontal, 14),
            alignment: .bottom
        )
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
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }

    private func emptyInline(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.ssCaption)
            .foregroundStyle(Color.ssGrey)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(20)
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
