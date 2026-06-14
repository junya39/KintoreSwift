import Foundation

struct WorkoutAnalysisDataBuilder {
    enum JSONStyle {
        case compact
        case debugPrettyPrinted
    }

    private struct ExerciseGroupKey: Hashable {
        let bodyPart: String
        let exerciseName: String
    }

    private let fetchEntries: (Date) -> [SetEntry]

    init(fetchEntries: @escaping (Date) -> [SetEntry] = { date in
        DatabaseManager.shared.fetchSets(by: date)
    }) {
        self.fetchEntries = fetchEntries
    }

    func makeRequest(
        for date: Date = Date(),
        timeZone: TimeZone = .current,
        generatedAt: Date = Date()
    ) -> WorkoutAnalysisRequest {
        buildRequest(
            entries: fetchEntries(date),
            analysisDate: date,
            timeZone: timeZone,
            generatedAt: generatedAt
        )
    }

    func buildRequest(
        entries: [SetEntry],
        analysisDate: Date,
        timeZone: TimeZone = .current,
        generatedAt: Date = Date()
    ) -> WorkoutAnalysisRequest {
        let sortedEntries = sortedSets(entries)
        let exercises = groupedExercises(from: sortedEntries, timeZone: timeZone)

        return WorkoutAnalysisRequest(
            analysisDate: formatAnalysisDate(analysisDate, timeZone: timeZone),
            generatedAt: formatDateTime(generatedAt, timeZone: timeZone),
            timezone: timeZone.identifier,
            totalSets: sortedEntries.count,
            totalReps: sortedEntries.reduce(0) { $0 + $1.reps },
            totalVolumeKg: sortedEntries.reduce(0) { $0 + volume(for: $1) },
            bodyParts: orderedBodyParts(from: sortedEntries),
            exercises: exercises
        )
    }

    func encodeJSON(
        _ request: WorkoutAnalysisRequest,
        style: JSONStyle = .compact
    ) throws -> Data {
        let encoder = JSONEncoder()
        switch style {
        case .compact:
            encoder.outputFormatting = []
        case .debugPrettyPrinted:
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(request)
    }

    func encodeJSONString(
        _ request: WorkoutAnalysisRequest,
        style: JSONStyle = .debugPrettyPrinted
    ) throws -> String {
        let data = try encodeJSON(request, style: style)
        return String(decoding: data, as: UTF8.self)
    }

    #if DEBUG
    func debugJSONStringForToday(
        timeZone: TimeZone = .current,
        generatedAt: Date = Date()
    ) throws -> String {
        let today = Date()
        let request = makeRequest(
            for: today,
            timeZone: timeZone,
            generatedAt: generatedAt
        )
        return try encodeJSONString(request, style: .debugPrettyPrinted)
    }
    #endif

    private func groupedExercises(
        from sortedEntries: [SetEntry],
        timeZone: TimeZone
    ) -> [WorkoutAnalysisExercise] {
        let grouped = Dictionary(grouping: sortedEntries) {
            ExerciseGroupKey(bodyPart: $0.bodyPart, exerciseName: $0.exercise)
        }

        return grouped
            .map { key, entries in
                let sets = sortedSets(entries)
                return WorkoutAnalysisExercise(
                    exerciseName: key.exerciseName,
                    bodyPart: key.bodyPart,
                    setCount: sets.count,
                    totalReps: sets.reduce(0) { $0 + $1.reps },
                    totalVolumeKg: sets.reduce(0) { $0 + volume(for: $1) },
                    sets: sets.map { entry in
                        WorkoutAnalysisSet(
                            id: entry.id,
                            performedAt: formatDateTime(entry.date, timeZone: timeZone),
                            weightKg: entry.weight,
                            reps: entry.reps,
                            note: normalizedOptionalText(entry.note),
                            side: normalizedOptionalText(entry.side),
                            isBodyweight: false
                        )
                    }
                )
            }
            .sorted { lhs, rhs in
                guard
                    let lhsFirst = lhs.sets.first,
                    let rhsFirst = rhs.sets.first,
                    let lhsDate = parseDateTime(lhsFirst.performedAt),
                    let rhsDate = parseDateTime(rhsFirst.performedAt)
                else {
                    return lhs.exerciseName < rhs.exerciseName
                }

                if lhsDate == rhsDate {
                    return lhsFirst.id < rhsFirst.id
                }
                return lhsDate < rhsDate
            }
    }

    private func sortedSets(_ entries: [SetEntry]) -> [SetEntry] {
        entries.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id < rhs.id
            }
            return lhs.date < rhs.date
        }
    }

    private func orderedBodyParts(from sortedEntries: [SetEntry]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for entry in sortedEntries where seen.contains(entry.bodyPart) == false {
            seen.insert(entry.bodyPart)
            result.append(entry.bodyPart)
        }

        return result
    }

    private func volume(for entry: SetEntry) -> Double {
        entry.weight * Double(entry.reps)
    }

    private func normalizedOptionalText(_ text: String?) -> String? {
        guard let text, text.isEmpty == false else { return nil }
        return text
    }

    private func formatAnalysisDate(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    private func parseDateTime(_ text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }
}
