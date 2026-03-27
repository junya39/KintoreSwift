
//  DatabaseManager.swift

import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTables()
    }

    // MARK: - Formatters
    /// DBに保存している日付フォーマット（insert / select で必ず統一）
    private lazy var isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        // insert() でこれを使って保存している前提（あなたの現状に合わせる）
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// 旧データ（小数秒なし）も混在している可能性があるためのフォールバック
    private lazy var isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseISODate(_ text: String) -> Date {
        if let d = isoFormatter.date(from: text) { return d }
        if let d = isoFormatterNoFraction.date(from: text) { return d }
        return Date()
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
        guard db != nil else {
            print("❌ DBがnilのためテーブル作成できません")
            return
        }

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
        createDeletedExerciseTableIfNeeded()
        createUserStatusTableIfNeeded()
    }

    /// 既存の sets テーブルに side カラムが無い場合は追加する
    private func migrateSideColumnIfNeeded() {
        guard db != nil else { return }

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
        guard db != nil else { return }

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

    func createDeletedExerciseTableIfNeeded() {
        guard db != nil else { return }

        let query = """
        CREATE TABLE IF NOT EXISTS deleted_exercises (
            name TEXT PRIMARY KEY
        );
        """
        if sqlite3_exec(db, query, nil, nil, nil) != SQLITE_OK {
            print("❌ deleted_exercises テーブル作成失敗")
        } else {
            print("✅ deleted_exercises テーブル確認完了")
        }
    }

    func createUserStatusTableIfNeeded() {
        guard db != nil else { return }

        let query = """
        CREATE TABLE IF NOT EXISTS user_status (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            level INTEGER NOT NULL DEFAULT 1,
            current_xp INTEGER NOT NULL DEFAULT 0,
            power INTEGER NOT NULL DEFAULT 0,
            endurance INTEGER NOT NULL DEFAULT 0,
            baselines TEXT NOT NULL DEFAULT '{}'
        );
        """

        if sqlite3_exec(db, query, nil, nil, nil) != SQLITE_OK {
            print("❌ user_status テーブル作成失敗")
            return
        }

        let seedQuery = """
        INSERT OR IGNORE INTO user_status (id, level, current_xp, power, endurance, baselines)
        VALUES (1, 1, 0, 0, 0, '{}');
        """

        if sqlite3_exec(db, seedQuery, nil, nil, nil) != SQLITE_OK {
            print("❌ user_status 初期データ作成失敗")
        } else {
            print("✅ user_status テーブル確認完了")
        }
    }

    func fetchUserStatus() -> (
        level: Int,
        currentXP: Int,
        power: Int,
        endurance: Int,
        baselinesJSON: String
    )? {
        guard db != nil else { return nil }

        let query = """
        SELECT level, current_xp, power, endurance, baselines
        FROM user_status
        WHERE id = 1
        LIMIT 1;
        """
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return nil
        }

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let level = Int(sqlite3_column_int(stmt, 0))
        let currentXP = Int(sqlite3_column_int(stmt, 1))
        let power = Int(sqlite3_column_int(stmt, 2))
        let endurance = Int(sqlite3_column_int(stmt, 3))
        let baselinesJSON = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) } ?? "{}"

        return (level, currentXP, power, endurance, baselinesJSON)
    }

    func saveUserStatus(
        level: Int,
        currentXP: Int,
        power: Int,
        endurance: Int,
        baselinesJSON: String
    ) {
        guard db != nil else { return }

        let query = """
        INSERT INTO user_status (id, level, current_xp, power, endurance, baselines)
        VALUES (1, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            level = excluded.level,
            current_xp = excluded.current_xp,
            power = excluded.power,
            endurance = excluded.endurance,
            baselines = excluded.baselines;
        """
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return
        }

        sqlite3_bind_int(stmt, 1, Int32(level))
        sqlite3_bind_int(stmt, 2, Int32(currentXP))
        sqlite3_bind_int(stmt, 3, Int32(power))
        sqlite3_bind_int(stmt, 4, Int32(endurance))
        sqlite3_bind_text(stmt, 5, (baselinesJSON as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("❌ user_status 保存失敗")
        }

        sqlite3_finalize(stmt)
    }

    // MARK: - 種目追加
    func insertExercise(name: String, bodyPart: String) {
        guard db != nil else { return }

        // 同名の削除済みマークがあれば解除
        let restoreQuery = "DELETE FROM deleted_exercises WHERE name = ?;"
        var restoreStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, restoreQuery, -1, &restoreStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(restoreStmt, 1, (name as NSString).utf8String, -1, nil)
            _ = sqlite3_step(restoreStmt)
        }
        sqlite3_finalize(restoreStmt)

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
        guard db != nil else { return [:] }

        var result: [String: [String]] = [:]
        let deletedNames = fetchDeletedExerciseNames()
        let query = "SELECT name, bodyPart FROM exercises ORDER BY id ASC;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(stmt, 0),
                   let bodyPartPtr = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: namePtr)
                    let bodyPart = String(cString: bodyPartPtr)
                    if deletedNames.contains(name) { continue }
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
            var merged = result[part] ?? []
            for item in items where !merged.contains(item) && !deletedNames.contains(item) {
                merged.append(item)
            }
            result[part] = merged
        }

        return result
    }

    func fetchDeletedExerciseNames() -> Set<String> {
        guard db != nil else { return [] }

        var names = Set<String>()
        let query = "SELECT name FROM deleted_exercises;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(stmt, 0) {
                    names.insert(String(cString: namePtr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return names
    }

    func deleteExercise(name: String) {
        guard db != nil else { return }

        let markQuery = "INSERT OR IGNORE INTO deleted_exercises (name) VALUES (?);"
        var markStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, markQuery, -1, &markStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(markStmt, 1, (name as NSString).utf8String, -1, nil)
            _ = sqlite3_step(markStmt)
        }
        sqlite3_finalize(markStmt)

        let deleteQuery = "DELETE FROM exercises WHERE name = ?;"
        var deleteStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStmt, 1, (name as NSString).utf8String, -1, nil)
            _ = sqlite3_step(deleteStmt)
        }
        sqlite3_finalize(deleteStmt)
    }

    // MARK: - 種目名から部位取得
    func fetchBodyPart(for exerciseName: String) -> String? {
        guard db != nil else { return nil }

        let query = "SELECT bodyPart FROM exercises WHERE name = ? ORDER BY id DESC LIMIT 1;"
        var stmt: OpaquePointer?
        var bodyPart: String?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (exerciseName as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW,
               let bodyPartPtr = sqlite3_column_text(stmt, 0) {
                bodyPart = String(cString: bodyPartPtr)
            }
        }
        sqlite3_finalize(stmt)

        return bodyPart
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
        guard db != nil else { return }

        let query = "INSERT INTO sets (date, bodyPart, exercise, weight, reps, note, side) VALUES (?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            // ✅ 保存は必ず isoFormatter に統一
            let dateString = isoFormatter.string(from: date)

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

            if let side = side, !side.isEmpty {
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
        guard db != nil else { return [] }

        var result: [SetEntry] = []
        let query = "SELECT * FROM sets ORDER BY date DESC;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let dateString = String(cString: sqlite3_column_text(stmt, 1))
                let date = parseISODate(dateString)

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
        guard db != nil else { return [] }

        var result: [SetEntry] = []
        let query = "SELECT * FROM sets WHERE exercise = ? ORDER BY id DESC LIMIT 2;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (exercise as NSString).utf8String, -1, nil)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let dateString = String(cString: sqlite3_column_text(stmt, 1))
                let date = parseISODate(dateString)

                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let ex = String(cString: sqlite3_column_text(stmt, 3))
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
                    exercise: ex,
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

    // MARK: - 記録を削除
    func delete(id: Int) {
        guard db != nil else { return }

        let query = "DELETE FROM sets WHERE id = ?;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))

            if sqlite3_step(stmt) == SQLITE_DONE {
                print("🗑️ 削除完了 id=\(id)")
            } else {
                print("❌ 削除失敗")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - 記録を更新
    func updateSet(_ entry: SetEntry) {
        guard db != nil else { return }

        let query = """
        UPDATE sets
        SET date = ?, bodyPart = ?, exercise = ?, weight = ?, reps = ?, note = ?, side = ?
        WHERE id = ?;
        """
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {

            let dateString = isoFormatter.string(from: entry.date)
            sqlite3_bind_text(stmt, 1, (dateString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (entry.bodyPart as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (entry.exercise as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, entry.weight)
            sqlite3_bind_int(stmt, 5, Int32(entry.reps))

            if let note = entry.note {
                sqlite3_bind_text(stmt, 6, (note as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 6)
            }

            if let side = entry.side, !side.isEmpty {
                sqlite3_bind_text(stmt, 7, (side as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 7)
            }

            sqlite3_bind_int(stmt, 8, Int32(entry.id))

            if sqlite3_step(stmt) == SQLITE_DONE {
                print("✏️ 更新完了 id=\(entry.id)")
            } else {
                print("❌ 更新失敗")
            }
        }
        sqlite3_finalize(stmt)
    }

    func updateExercise(name: String, newName: String, newBodyPart: String) {
        guard db != nil else { return }

        let query = "UPDATE exercises SET name = ?, bodyPart = ? WHERE name = ?;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (newName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (newBodyPart as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) == SQLITE_DONE {
                print("✏️ 種目更新: \(name) → \(newName) (\(newBodyPart))")
            } else {
                print("❌ 種目更新失敗")
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - 種目別 全履歴取得
    func fetchSetsByExercise(_ exercise: String) -> [SetEntry] {
        guard db != nil else { return [] }

        var result: [SetEntry] = []
        let query = """
            SELECT * FROM sets
            WHERE exercise = ?
            ORDER BY date DESC;
        """
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (exercise as NSString).utf8String, -1, nil)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let dateString = String(cString: sqlite3_column_text(stmt, 1))
                let date = parseISODate(dateString)

                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let ex = String(cString: sqlite3_column_text(stmt, 3))
                let weight = sqlite3_column_double(stmt, 4)
                let reps = Int(sqlite3_column_int(stmt, 5))
                let note = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) }

                var side: String? = nil
                if sqlite3_column_count(stmt) > 7 &&
                    sqlite3_column_type(stmt, 7) != SQLITE_NULL {
                    side = String(cString: sqlite3_column_text(stmt, 7))
                }

                result.append(SetEntry(
                    id: id,
                    date: date,
                    bodyPart: bodyPart,
                    exercise: ex,
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

    // MARK: - 日付別 取得（HistoryView 用）
    /// 「指定日の 00:00:00 〜 翌日 00:00:00」を ISO8601文字列で範囲検索
    func fetchSets(by date: Date) -> [SetEntry] {
        guard db != nil else { return [] }

        var result: [SetEntry] = []

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        let startText = isoFormatter.string(from: startOfDay)
        let endText = isoFormatter.string(from: endOfDay)

        let query = """
        SELECT * FROM sets
        WHERE date >= ? AND date < ?
        ORDER BY date ASC;
        """

        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {

            sqlite3_bind_text(stmt, 1, (startText as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (endText as NSString).utf8String, -1, nil)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let dateString = String(cString: sqlite3_column_text(stmt, 1))
                let d = parseISODate(dateString)

                let bodyPart = String(cString: sqlite3_column_text(stmt, 2))
                let exercise = String(cString: sqlite3_column_text(stmt, 3))
                let weight = sqlite3_column_double(stmt, 4)
                let reps = Int(sqlite3_column_int(stmt, 5))
                let note = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) }

                var side: String? = nil
                if sqlite3_column_count(stmt) > 7 &&
                    sqlite3_column_type(stmt, 7) != SQLITE_NULL {
                    side = String(cString: sqlite3_column_text(stmt, 7))
                }

                result.append(
                    SetEntry(
                        id: id,
                        date: d,
                        bodyPart: bodyPart,
                        exercise: exercise,
                        weight: weight,
                        reps: reps,
                        note: note,
                        side: side
                    )
                )
            }
        }

        sqlite3_finalize(stmt)
        return result
    }
}
