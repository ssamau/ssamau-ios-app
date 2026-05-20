import Foundation
import Combine

@MainActor
final class MyTasksViewModel: ObservableObject {
    @Published var assignments: [Assignment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    enum Section: String, CaseIterable, Identifiable {
        case upcoming
        case completed
        case missed
        var id: String { rawValue }

        var localizationKey: String {
            switch self {
            case .upcoming:  return "mp.tasks.section_upcoming"
            case .completed: return "mp.tasks.section_completed"
            case .missed:    return "mp.tasks.section_missed"
            }
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await APIClient.shared.call(
                "assignments.listOwn",
                as: [Assignment].self
            )
            self.assignments = rows
            self.errorMessage = nil
        } catch let apiError as APIError {
            #if DEBUG
            print("⚠️ MyTasksViewModel.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("⚠️ MyTasksViewModel.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    /// Bucket each assignment into one of three sections per spec §8.5:
    ///   - Upcoming: pending OR no attendance recorded, with an event
    ///     date in the future (or unknown date)
    ///   - Completed: attendance_status == "Attended" or "Excused"
    ///   - Missed: attendance_status == "Absent"
    func assignments(in section: Section) -> [Assignment] {
        assignments.filter { matches(section, $0) }
    }

    private func matches(_ section: Section, _ a: Assignment) -> Bool {
        let status = a.attendanceStatus ?? "Pending"
        switch section {
        case .completed:
            return status == "Attended" || status == "Excused"
        case .missed:
            return status == "Absent"
        case .upcoming:
            // Anything that hasn't been resolved as Attended/Absent/Excused.
            return status == "Pending"
        }
    }
}
