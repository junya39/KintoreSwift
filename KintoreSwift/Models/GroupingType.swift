
//  GroupingType.swift

import Foundation

enum GroupingType: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
}
