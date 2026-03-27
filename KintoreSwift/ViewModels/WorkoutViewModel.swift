import Foundation
import Combine

final class WorkoutViewModel: ContentViewModel {
    @Published var currentLevel: Int

    override init() {
        self.currentLevel = 1
        super.init()
    }

    var todaySets: [SetEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.filter { $0.date >= today }
    }

    var todayTotalWeight: Double {
        todaySets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    var todayTotalReps: Int {
        todaySets.reduce(0) { $0 + $1.reps }
    }

    private func sortedSets(for exerciseId: String) -> [SetEntry] {
        entries
            .filter { $0.exercise == exerciseId }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.id < rhs.id
                }
                return lhs.date < rhs.date
            }
    }

    private func previousSet(for exerciseId: String) -> SetEntry? {
        guard !exerciseId.isEmpty else { return nil }
        return sortedSets(for: exerciseId).last
    }

    override func getLastSet(for exerciseId: String) -> String {
        guard let last = previousSet(for: exerciseId) else { return "前セットなし" }

        let weightText = last.weight > 0
            ? String(format: "%.1fkg", last.weight)
            : "自重"

        if let side = last.side, !side.isEmpty {
            return "\(weightText) × \(last.reps)回（\(side)）"
        }
        return "\(weightText) × \(last.reps)回"
    }
}
