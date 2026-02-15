import Foundation

@MainActor
final class XPToastCenter: ObservableObject {
    static let shared = XPToastCenter()

    @Published var current: XPToastItem?

    private var queue: [XPToastItem] = []
    private var isShowing = false
    private var comboCount = 0
    private var lastShowAt: Date?

    private init() {}

    func show(xp: Int) {
        let now = Date()
        if let lastShowAt, now.timeIntervalSince(lastShowAt) <= 4.0 {
            comboCount += 1
        } else {
            comboCount = 1
        }
        self.lastShowAt = now

        let comboText: String?
        if comboCount >= 5 {
            comboText = "ULTRA COMBO 🔥🔥"
        } else if comboCount >= 3 {
            comboText = "COMBO x\(comboCount) 🔥"
        } else {
            comboText = nil
        }

        let item = XPToastItem(amount: xp, comboText: comboText)
        if comboText != nil {
            queue.removeAll()
            queue.append(item)
        } else {
            queue.append(item)
        }
        showNextIfNeeded()
    }

    private func showNextIfNeeded() {
        guard !isShowing, !queue.isEmpty else { return }

        isShowing = true
        current = queue.removeFirst()

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            current = nil
            isShowing = false
            showNextIfNeeded()
        }
    }
}

struct XPToastItem: Identifiable {
    let id = UUID()
    let amount: Int
    let comboText: String?
}
