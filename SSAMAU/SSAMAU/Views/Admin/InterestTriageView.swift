import SwiftUI
import Combine

/// Admin-only interest triage. Lists every interest_request (joined
/// to member + project + opportunity role) with a "mark reviewed"
/// toggle. Admin uses this to surface NEW interest the head hasn't
/// acted on yet across the whole club.
struct InterestTriageView: View {
    @StateObject private var vm = InterestTriageViewModel()

    var body: some View {
        content
            .navigationTitle(LocalizedStringKey("ap.tabs.interest"))
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.ssCream)
            .refreshable { await vm.load() }
            .task { await vm.load() }
            .ssToast($vm.toast)
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
                    HStack(spacing: 8) {
                        ForEach(InterestTriageViewModel.Filter.allCases) { f in
                            let selected = vm.filter == f
                            Button { vm.filter = f } label: {
                                Text(LocalizedStringKey(f.labelKey))
                                    .font(.ssCaption.weight(.semibold))
                                    .foregroundStyle(selected ? Color.ssCream : Color.ssGreen)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(selected ? Color.ssGreen : Color.ssPale)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    if vm.filteredRows.isEmpty {
                        Text(LocalizedStringKey("ap.interest.empty"))
                            .font(.ssCaption).foregroundStyle(Color.ssGrey)
                            .padding(.vertical, 60)
                    } else {
                        LazyVGrid(columns: SSAdaptiveColumns.cards, spacing: 8) {
                            ForEach(vm.filteredRows) { row in
                                rowCard(row)
                            }
                        }
                    }
                }
                .ipadContentWidth()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }

    private func rowCard(_ row: InterestRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.displayName)
                    .font(.ssBodyBold).foregroundStyle(Color.ssGreen)
                Spacer()
                if row.reviewedAt != nil {
                    Text(LocalizedStringKey("common.status.reviewed"))
                        .font(.ssTiny.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.ssGrey)
                        .clipShape(Capsule())
                }
            }
            if let project = row.projectName {
                Label(project, systemImage: "folder")
                    .font(.ssCaption).foregroundStyle(Color.ssCharcoal)
            }
            if let picked = row.pickedRoleName {
                Text(picked).font(.ssTiny).foregroundStyle(Color.ssGrey)
            } else if row.isAnyRole && row.opportunityId != nil {
                Text(LocalizedStringKey("hp.opps.any_role_chip"))
                    .font(.ssTiny.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.ssGold)
                    .clipShape(Capsule())
            }
            if let comment = row.comment, !comment.isEmpty {
                Text(comment).font(.ssTiny).foregroundStyle(Color.ssCharcoal)
                    .padding(6).background(Color.ssCream)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            HStack {
                Spacer()
                Button {
                    Task { await vm.markReviewed(row, reviewed: row.reviewedAt == nil) }
                } label: {
                    Text(LocalizedStringKey(row.reviewedAt == nil
                        ? "ap.interest.mark_reviewed"
                        : "ap.interest.mark_unreviewed"))
                    .font(.ssTiny.weight(.semibold))
                    .foregroundStyle(Color.ssGreen)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.ssCream).clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.ssGreen.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(vm.inFlightId != nil)
            }
        }
        .padding(12)
        .background(Color.ssPale)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.ssGold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
final class InterestTriageViewModel: ObservableObject {
    @Published var rows: [InterestRow] = []
    @Published var isLoading: Bool = false
    @Published var toast: Toast?
    @Published var filter: Filter = .unreviewed
    @Published var inFlightId: Int64?

    enum Filter: String, CaseIterable, Identifiable {
        case unreviewed, all
        var id: String { rawValue }
        var labelKey: String {
            switch self {
            case .unreviewed: return "ap.interest.filter_unreviewed"
            case .all:        return "ap.interest.filter_all"
            }
        }
    }

    var filteredRows: [InterestRow] {
        rows.filter { r in
            switch filter {
            case .unreviewed: return r.reviewedAt == nil
            case .all:        return true
            }
        }
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            rows = try await APIClient.shared.call("interest.listAll", as: [InterestRow].self)
        } catch let apiError as APIError where !apiError.isCancellation {
            toast = .error(apiError.localizedMessage)
        } catch { }
    }

    func markReviewed(_ row: InterestRow, reviewed: Bool) async {
        guard inFlightId == nil else { return }
        inFlightId = row.id
        defer { inFlightId = nil }
        do {
            _ = try await APIClient.shared.call(
                "interest.markReviewed",
                params: ["id": row.id, "reviewed": reviewed],
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("ap.interest.reviewed_ok"))
            await load()
        } catch let apiError as APIError where !apiError.isCancellation {
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }
}
