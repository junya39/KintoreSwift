import Foundation
import SQLite

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: Connection?

    private let workouts = Table("workouts")
    private let id = Expression<Int64>("id")
    private let date = Expression<Date>("date")
    private let bodyPart = Expression<String>("bodyPart")
    private let exercise = Expression<String>("exercise")
    private let weight = Expression<Double>("weight")
    private let reps = Expression<Int>("reps")

    private init() {
        connect()
        createTableIfNeeded()
    }

    private func connect() {
        do {
            let documentDirectory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbPath = documentDirectory.appendingPathComponent("workout.sqlite3").path
            db = try Connection(dbPath)
            print("✅ DB接続成功: \(dbPath)")
        } catch {
            print("❌ DB接続エラー: \(error)")
        }
    }

    private func createTableIfNeeded() {
        guard let db = db else { return }
        do {
            try db.run(workouts.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(date)
                t.column(bodyPart)
                t.column(exercise)
                t.column(weight)
                t.column(reps)
            })
            print("✅ workoutsテーブルを作成または確認しました")
        } catch {
            print("❌ テーブル作成エラー: \(error)")
        }
    }

    func insertWorkout(date: Date, bodyPart: String, exercise: String, weight: Double, reps: Int) {
        guard let db = db else { return }
        do {
            let insert = workouts.insert(
                self.date <- date,
                self.bodyPart <- bodyPart,
                self.exercise <- exercise,
                self.weight <- weight,
                self.reps <- reps
            )
            try db.run(insert)
            print("✅ データを追加しました: \(exercise) \(weight)kg × \(reps)回")
        } catch {
            print("❌ データ追加エラー: \(error)")
        }
    }

    func fetchAll() -> [SetEntry] {
        guard let db = db else { return [] }
        var result: [SetEntry] = []
        do {
            for row in try db.prepare(workouts) {
                let entry = SetEntry(
                    id: row[id], // ← 追加！
                    date: row[date],
                    bodyPart: row[bodyPart],
                    exercise: row[exercise],
                    weight: row[weight],
                    reps: row[reps]
                )
                result.append(entry)
            }
            print("📦 DBからデータを読み込みました（\(result.count)件）")
        } catch {
            print("❌ データ読み込みエラー: \(error)")
        }
        return result
    }

    
    func deleteWorkout(entry: SetEntry) {
        guard let db = db else { return }

        do {
            let target = workouts.filter(self.id == entry.id)
            try db.run(target.delete())
            print("🗑️ Workout削除成功: id=\(entry.id)")
        } catch {
            print("❌ Workout削除エラー: \(error)")
        }
    }
}
