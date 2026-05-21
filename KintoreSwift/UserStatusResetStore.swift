import Foundation

enum UserStatusResetStore {
    static let statusResetDateKey = "userStatus.statusResetDate"

    static func statusResetDate(userDefaults: UserDefaults = .standard) -> Date? {
        let timestamp = userDefaults.double(forKey: statusResetDateKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func saveStatusResetDate(_ date: Date, userDefaults: UserDefaults = .standard) {
        userDefaults.set(date.timeIntervalSince1970, forKey: statusResetDateKey)
    }

    static func isStatusEligible(_ entry: SetEntry, resetDate: Date? = statusResetDate()) -> Bool {
        guard let resetDate else { return true }
        return entry.date >= resetDate
    }

    static func statusEligibleEntries(_ entries: [SetEntry], resetDate: Date? = statusResetDate()) -> [SetEntry] {
        entries.filter { isStatusEligible($0, resetDate: resetDate) }
    }
}
