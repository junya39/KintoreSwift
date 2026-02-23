import Foundation
import Combine

final class WorkoutViewModel: ContentViewModel {
    @Published var currentLevel: Int

    override init() {
        self.currentLevel = 1
        super.init()
    }
}
