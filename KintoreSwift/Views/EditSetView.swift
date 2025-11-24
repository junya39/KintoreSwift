//EditSetView.swift

import SwiftUI

struct EditSetView: View {
    @Binding var entry: SetEntry
    var onSave: (SetEntry) -> Void
    @Environment(\.dismiss) var dismiss

    // 編集用の一時変数
    @State private var weight = ""
    @State private var reps = ""
    @State private var side = ""
    @State private var note = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("重量 (kg)", text: $weight)
                    .keyboardType(.decimalPad)

                TextField("回数", text: $reps)
                    .keyboardType(.numberPad)

                Picker("左右", selection: $side) {
                    Text("左").tag("L")
                    Text("右").tag("R")
                    Text("なし").tag("")
                }
                .pickerStyle(.segmented)

                TextField("メモ", text: $note)
            }
            .navigationTitle("記録を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                }
            }
        }
        .onAppear {
            // 既存データを State にコピー
            weight = String(Int(entry.weight))
            reps = String(entry.reps)
            side = entry.side ?? ""
            note = entry.note ?? ""
        }
    }

    private func saveChanges() {
        let updated = SetEntry(
            id: entry.id,
            date: entry.date,
            bodyPart: entry.bodyPart,
            exercise: entry.exercise,
            weight: Double(weight) ?? entry.weight,
            reps: Int(reps) ?? entry.reps,
            note: note,
            side: side
        )
        onSave(updated)
        dismiss()
    }
}
