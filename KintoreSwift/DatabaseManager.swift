//  DatabaseManager.swift

import Foundation
import SQLite3

struct SetEntry: Identifiable {
    let id: Int64
    let date: Date
    let bodyPart: String
    let exercise: String
    let weight: Double
    let reps: Int
    let note: String?    // ← すでに追加済み前提
}

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {
        db = open()
        createTable()
        addNoteColumnIfNeeded()
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

    // MARK: - Create / Migrate
    private func createTable() {
        let sql = """
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
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            _ = sqlite3_step(stmt)
            print("✅ workouts table ready")
        }
        sqlite3_finalize(stmt)
    }

    private func addNoteColumnIfNeeded() {
        // 既にあるかチェック
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(workouts);", -1, &stmt, nil) == SQLITE_OK {
            var hasNote = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, 1))
                if name == "note" { hasNote = true; break }
            }
            sqlite3_finalize(stmt)

            if !hasNote {
                if sqlite3_exec(db, "ALTER TABLE workouts ADD COLUMN note TEXT;", nil, nil, nil) == SQLITE_OK {
                    print("🧱 Added missing column: note")
                }
            } else {
                print("✅ workouts table ready (includes note column in schema)")
            }
        }
    }

    // MARK: - Insert
    func insert(date: Date, bodyPart: String, exercise: String, weight: Double, reps: Int, note: String? = nil) {
        let sql = "INSERT INTO workouts (date, bodyPart, exercise, weight, reps, note) VALUES (?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let dateString = ISO8601DateFormatter().string(from: date)
            sqlite3_bind_text(stmt, 1, (dateString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (bodyPart as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (exercise as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, weight)
            sqlite3_bind_int(stmt, 5, Int32(reps))
            if let note = note {
                sqlite3_bind_text(stmt, 6, (note as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            if sqlite3_step(stmt) == SQLITE_DONE {
                print("💾 Inserted: \(exercise) \(weight)kg x \(reps)")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Fetch All
    func fetchAll() -> [SetEntry] {
        var result: [SetEntry] = []
        let sql = "SELECT id, date, bodyPart, exercise, weight, reps, note FROM workouts ORDER BY id ASC;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let dateStr = String(cString: sqlite3_column_text(stmt, 1))
                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let exercise = String(cString: sqlite3_column_text(stmt, 3))
                let weight = sqlite3_column_double(stmt, 4)
                let reps = Int(sqlite3_column_int(stmt, 5))
                let note = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 6))
                let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()

                result.append(.init(id: id, date: date, bodyPart: bodyPart, exercise: exercise, weight: weight, reps: reps, note: note))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - 直近2件を“idの降順”で取得（最新・一つ前）
    func fetchLastTwoRecords(for exercise: String) -> [SetEntry] {
        var items: [SetEntry] = []
        let sql = """
        SELECT id, date, bodyPart, exercise, weight, reps, note
        FROM workouts
        WHERE exercise = ?
        ORDER BY id DESC
        LIMIT 2;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (exercise as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let dateStr = String(cString: sqlite3_column_text(stmt, 1))
                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let exercise = String(cString: sqlite3_column_text(stmt, 3))
                let weight = sqlite3_column_double(stmt, 4)
                let reps = Int(sqlite3_column_int(stmt, 5))
                let note = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 6))
                let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
                items.append(.init(id: id, date: date, bodyPart: bodyPart, exercise: exercise, weight: weight, reps: reps, note: note))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    // （必要なら残す）1つ前だけ欲しいAPIもid基準に修正
    func fetchLastRecord(for exercise: String) -> SetEntry? {
        var result: SetEntry?
        let sql = """
        SELECT id, date, bodyPart, exercise, weight, reps, note
        FROM workouts
        WHERE exercise = ?
        ORDER BY id DESC
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
                let note = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 6))
                let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
                result = .init(id: id, date: date, bodyPart: bodyPart, exercise: exercise, weight: weight, reps: reps, note: note)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
}
