import Foundation
import SwiftUI

final class LevelViewModel: ObservableObject {
    @ObservedObject var userStatus: UserStatusViewModel

    init(userStatus: UserStatusViewModel) {
        self.userStatus = userStatus
    }

    var requiredXP: Int {
        userStatus.requiredXP(for: userStatus.level)
    }

    var progress: Double {
        userStatus.getProgress()
    }

    var remainingXP: Int {
        max(0, requiredXP - userStatus.currentXP)
    }

    var displayLevel: Int {
        userStatus.level
    }

    var displayPower: Int {
        userStatus.power
    }

    var displayEndurance: Int {
        userStatus.endurance
    }

    var lastGainedXP: Int {
        userStatus.lastGainedXP
    }
}
