//DatabaseManager.swift

import Foundation
import SQLite3

struct SetEntry: Identifiable {
    let id: Int64
    let date: Date
    let bodyPart: String
    let exercise: String
    let weight: Double
    let reps: Int
}

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {
        db = open()
        createTable()
    }

    // MARK: - Open DB
    private func open() -> OpaquePointer? {
        if db != nil { return db }

        var dbPointer: OpaquePointer?
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("workouts.sqlite")

        if sqlite3_open(fileURL.path, &dbPointer) == SQLITE_OK {
            print("✅ Database opened at: \(fileURL.path)")
            return dbPointer
        } else {
            print("❌ Failed to open database")
            return nil
        }
    }

    // MARK: - Create Table
    private func createTable() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS workouts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            bodyPart TEXT,
            exercise TEXT,
            weight REAL,
            reps INTEGER
        );
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_DONE {
                print("✅ workouts table ready")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Insert
    func insert(date: Date, bodyPart: String, exercise: String, weight: Double, reps: Int) {
        let insertString = "INSERT INTO workouts (date, bodyPart, exercise, weight, reps) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertString, -1, &stmt, nil) == SQLITE_OK {
            let dateString = ISO8601DateFormatter().string(from: date)
            sqlite3_bind_text(stmt, 1, (dateString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (bodyPart as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (exercise as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, weight)
            sqlite3_bind_int(stmt, 5, Int32(reps))
            if sqlite3_step(stmt) == SQLITE_DONE {
                print("💾 Inserted: \(exercise) \(weight)kg x \(reps)")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Fetch All
    func fetchAll() -> [SetEntry] {
        var entries: [SetEntry] = []
        let queryString = "SELECT id, date, bodyPart, exercise, weight, reps FROM workouts ORDER BY date ASC;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, queryString, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let dateStr = String(cString: sqlite3_column_text(stmt, 1))
                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let exercise = String(cString: sqlite3_column_text(stmt, 3))
                let weight = sqlite3_column_double(stmt, 4)
                let reps = Int(sqlite3_column_int(stmt, 5))

                let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()

                entries.append(SetEntry(id: id, date: date, bodyPart: bodyPart, exercise: exercise, weight: weight, reps: reps))
            }
        }
        sqlite3_finalize(stmt)
        return entries
    }

    // MARK: - Delete All (デバッグ用)
    func deleteAll() {
        let deleteSQL = "DELETE FROM workouts;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_DONE {
                print("🗑️ All records deleted")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - 前回の記録取得
    /// 指定した種目（exercise）の1つ前の記録を取得
    func fetchLastRecord(for exercise: String) -> SetEntry? {
        var result: SetEntry?
        let sql = """
        SELECT id, date, bodyPart, exercise, weight, reps
        FROM workouts
        WHERE exercise = ?
        ORDER BY date DESC
        LIMIT 1 OFFSET 1;
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (exercise as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let dateStr = String(cString: sqlite3_column_text(stmt, 1))
                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let exercise = String(cString: sqlite3_column_text(stmt, 3))
                let weight = sqlite3_column_double(stmt, 4)
                let reps = Int(sqlite3_column_int(stmt, 5))

                let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
                result = SetEntry(id: id, date: date, bodyPart: bodyPart, exercise: exercise, weight: weight, reps: reps)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
}
