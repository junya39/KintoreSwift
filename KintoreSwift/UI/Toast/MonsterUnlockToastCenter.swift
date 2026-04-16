import Foundation

@MainActor
final class MonsterUnlockToastCenter: ObservableObject {
    static let shared = MonsterUnlockToastCenter()

    @Published var current: MonsterUnlockToastItem?

    private var queue: [MonsterUnlockToastItem] = []
    private var isShowing = false

    private init() {}

    func show(monsterName: String) {
        queue.append(MonsterUnlockToastItem(
            title: "新しいモンスターが解放された！",
            monsterName: monsterName
        ))
        showNextIfNeeded()
    }

    private func showNextIfNeeded() {
        guard !isShowing, !queue.isEmpty else { return }

        isShowing = true
        current = queue.removeFirst()

        Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            current = nil
            isShowing = false
            showNextIfNeeded()
        }
    }
}

struct MonsterUnlockToastItem: Identifiable {
    let id = UUID()
    let title: String
    let monsterName: String
}
