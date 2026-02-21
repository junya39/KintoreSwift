import Foundation
import Combine
import UIKit

final class IntervalTimerViewModel: ObservableObject {
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var duration: Int

    private var timer: AnyCancellable?

    init(duration: Int = 120) {
        self.duration = duration
        self.remainingSeconds = duration
    }

    func start() {
        stop()
        isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.remainingSeconds > 0 else {
                    self.stop()
                    return
                }

                self.remainingSeconds -= 1

                if self.remainingSeconds == 0 {
                    self.stop()
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.warning)
                }
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    func reset() {
        stop()
        remainingSeconds = duration
    }
}
