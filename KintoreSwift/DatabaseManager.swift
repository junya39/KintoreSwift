//
//  DatabaseManager.swift

import Foundation
import SQLite3

struct SetEntry: Identifiable {
    let id: Int
    let date: Date
    let bodyPart: String
    let exercise: String
    let weight: Double
    let reps: Int
    let note: String?
    let side: String? // "R" or "L"
}

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTables()
    }

    // MARK: - DBを開く
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("kintore.db")

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("❌ データベースを開けません")
        } else {
            print("✅ データベースを開きました: \(fileURL.path)")
        }
    }

    // MARK: - テーブル作成 & マイグレーション
    private func createTables() {
        // 基本のsetsテーブル（新規インストール時用）
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS sets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            bodyPart TEXT,
            exercise TEXT,
            weight REAL,
            reps INTEGER,
            note TEXT,
            side TEXT
        );
        """
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
            print("❌ sets テーブル作成失敗")
        } else {
            print("✅ sets テーブル確認完了")
        }

        // 既存DBに side カラムがなければ追加
        migrateSideColumnIfNeeded()

        createExerciseTableIfNeeded()
    }

    /// 既存の sets テーブルに side カラムが無い場合は追加する
    private func migrateSideColumnIfNeeded() {
        let pragmaQuery = "PRAGMA table_info(sets);"
        var stmt: OpaquePointer?

        var hasSideColumn = false

        if sqlite3_prepare_v2(db, pragmaQuery, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: namePtr)
                    if name == "side" {
                        hasSideColumn = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(stmt)

        if !hasSideColumn {
            let alterQuery = "ALTER TABLE sets ADD COLUMN side TEXT;"
            if sqlite3_exec(db, alterQuery, nil, nil, nil) == SQLITE_OK {
                print("✅ sets テーブルに side カラムを追加しました")
            } else {
                print("❌ side カラム追加に失敗しました")
            }
        }
    }

    // MARK: - 種目テーブル
    func createExerciseTableIfNeeded() {
        let query = """
        CREATE TABLE IF NOT EXISTS exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            bodyPart TEXT NOT NULL
        );
        """
        if sqlite3_exec(db, query, nil, nil, nil) != SQLITE_OK {
            print("❌ exercises テーブル作成失敗")
        } else {
            print("✅ exercises テーブル確認完了")
        }
    }

    // MARK: - 種目追加
    func insertExercise(name: String, bodyPart: String) {
        let query = "INSERT INTO exercises (name, bodyPart) VALUES (?, ?);"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (bodyPart as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) == SQLITE_DONE {
                print("✅ 新しい種目を追加: \(bodyPart) - \(name)")
            } else {
                print("❌ 種目の追加失敗")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - 部位ごとの種目リスト取得
    func fetchExercisesByBodyPart() -> [String: [String]] {
        var result: [String: [String]] = [:]
        let query = "SELECT name, bodyPart FROM exercises ORDER BY id ASC;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(stmt, 0),
                   let bodyPartPtr = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: namePtr)
                    let bodyPart = String(cString: bodyPartPtr)
                    result[bodyPart, default: []].append(name)
                }
            }
        }
        sqlite3_finalize(stmt)

        // 初期値（デフォルト種目）
        let defaults: [String: [String]] = [
            "胸": ["ベンチプレス", "インクラインベンチプレス", "ケーブルだっちゅーの"],
            "背中": ["チンニング", "ワンハンドロー", "Tバーロウ", "ラットプルダウン（ナロー）"],
            "脚": ["スクワット", "ブルガリアンスクワット", "レッグプレス", "アダクター"],
            "肩": ["ショルダープレス", "サイドレイズ", "リアレイズ"],
            "腕": ["インクラインアームカール", "ハンマーカール", "ディップス", "ワンハンドオーバーエクステンション"],
            "腹筋": ["クランチ", "レッグレイズ", "アブローラー"]
        ]

        for (part, items) in defaults {
            if result[part] == nil || result[part]!.isEmpty {
                result[part] = items
            }
        }

        return result
    }

    // MARK: - セットを追加（side対応版）
    func insert(
        date: Date,
        bodyPart: String,
        exercise: String,
        weight: Double,
        reps: Int,
        note: String?,
        side: String? = nil
    ) {
        let query = "INSERT INTO sets (date, bodyPart, exercise, weight, reps, note, side) VALUES (?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
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

            if let side = side {
                sqlite3_bind_text(stmt, 7, (side as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 7)
            }

            if sqlite3_step(stmt) == SQLITE_DONE {
                print("✅ セット追加完了 (\(exercise), side: \(side ?? "nil"))")
            } else {
                print("❌ セット追加失敗")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - 全データ取得
    func fetchAll() -> [SetEntry] {
        var result: [SetEntry] = []
        let query = "SELECT * FROM sets ORDER BY date DESC;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let dateString = String(cString: sqlite3_column_text(stmt, 1))
                let date = ISO8601DateFormatter().date(from: dateString) ?? Date()
                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let exercise = String(cString: sqlite3_column_text(stmt, 3))
                let weight = sqlite3_column_double(stmt, 4)
                let reps = Int(sqlite3_column_int(stmt, 5))
                let note = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) }

                var side: String? = nil
                if sqlite3_column_count(stmt) > 7 && sqlite3_column_type(stmt, 7) != SQLITE_NULL {
                    side = String(cString: sqlite3_column_text(stmt, 7))
                }

                result.append(SetEntry(
                    id: id,
                    date: date,
                    bodyPart: bodyPart,
                    exercise: exercise,
                    weight: weight,
                    reps: reps,
                    note: note,
                    side: side
                ))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - 直近2件取得
    func fetchLastTwoRecords(for exercise: String) -> [SetEntry] {
        var result: [SetEntry] = []
        let query = "SELECT * FROM sets WHERE exercise = ? ORDER BY id DESC LIMIT 2;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (exercise as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let dateString = String(cString: sqlite3_column_text(stmt, 1))
                let date = ISO8601DateFormatter().date(from: dateString) ?? Date()
                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let exercise = String(cString: sqlite3_column_text(stmt, 3))
                let weight = sqlite3_column_double(stmt, 4)
                let reps = Int(sqlite3_column_int(stmt, 5))
                let note = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) }

                var side: String? = nil
                if sqlite3_column_count(stmt) > 7 && sqlite3_column_type(stmt, 7) != SQLITE_NULL {
                    side = String(cString: sqlite3_column_text(stmt, 7))
                }

                result.append(SetEntry(
                    id: id,
                    date: date,
                    bodyPart: bodyPart,
                    exercise: exercise,
                    weight: weight,
                    reps: reps,
                    note: note,
                    side: side
                ))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
}
