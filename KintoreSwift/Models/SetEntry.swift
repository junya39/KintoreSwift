//  SetEntry.swift


import Foundation

struct SetEntry: Identifiable {
    let id: Int
    let date: Date
    let bodyPart: String
    let exercise: String
    let weight: Double
    let reps: Int
    let note: String?
    let side: String?
}
