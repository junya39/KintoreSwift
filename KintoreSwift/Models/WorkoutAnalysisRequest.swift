import Foundation

struct WorkoutAnalysisRequest: Codable, Equatable, Sendable {
    let analysisDate: String
    let generatedAt: String
    let timezone: String
    let totalSets: Int
    let totalReps: Int
    let totalVolumeKg: Double
    let bodyParts: [String]
    let exercises: [WorkoutAnalysisExercise]
}

struct WorkoutAnalysisExercise: Codable, Equatable, Sendable {
    let exerciseName: String
    let bodyPart: String
    let setCount: Int
    let totalReps: Int
    let totalVolumeKg: Double
    let sets: [WorkoutAnalysisSet]
}

struct WorkoutAnalysisSet: Codable, Equatable, Sendable {
    let id: Int
    let performedAt: String
    let weightKg: Double
    let reps: Int
    let note: String?
    let side: String?
    let isBodyweight: Bool
}
