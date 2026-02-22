// HomeView.swift

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = ContentViewModel()
    @EnvironmentObject private var userStatusVM: UserStatusViewModel
    @State private var selectedDate = Date()
    @State private var showDayHistory = false
    @State private var selectedBodyPart = "胸"
    @State private var selectedExercise = ""
    @State private var showAddExerciseSheet = false

    private let bodyPartOrder = ["胸", "背中", "脚", "肩", "腕", "腹筋"]
    private static let homeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter
    }()
    private var homeMetrics: ContentViewModel.HomeMetrics { viewModel.homeMetrics }
    private var todayText: String {
        Self.homeDateFormatter.string(from: Date())
    }

    private var selectedExerciseVolumeText: String {
        guard !selectedExercise.isEmpty else { return "--" }
        let total = Int(
            viewModel.entries
                .filter { $0.exercise == selectedExercise }
                .reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        )
        return "\(total.formatted()) kg"
    }

    private func normalizeSelection() {
        if selectedExercise.isEmpty || viewModel.exercises[selectedBodyPart, default: []].contains(selectedExercise) == false {
            selectedExercise = viewModel.exercises[selectedBodyPart]?.first ?? ""
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // タイトル
                    Text("KintoreSwift")
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.white)

                    Text(todayText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.72))
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CalendarSection(
                        selectedDate: $selectedDate,
                        entries: viewModel.entries,
                        onDateTap: {
                            showDayHistory = true
                        }
                    )

                    // レベルカード（仮）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("レベル \(userStatusVM.level)")
                            .font(.headline)
                            .foregroundColor(.white)

                        ProgressView(value: userStatusVM.getProgress())
                            .tint(.green)

                        Text("\(userStatusVM.currentXP.formatted()) / \(userStatusVM.requiredXP(for: userStatusVM.level).formatted()) XP")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.15))
                    .cornerRadius(14)

                    // 今日のワークアウト
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本日のトレーニング")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))

                        Menu {
                            Button {
                                showAddExerciseSheet = true
                            } label: {
                                Label("種目を追加", systemImage: "plus")
                            }

                            Divider()

                            ForEach(bodyPartOrder, id: \.self) { part in
                                let exercises = viewModel.exercises[part] ?? []
                                if !exercises.isEmpty {
                                    Section(part) {
                                        ForEach(exercises, id: \.self) { exercise in
                                            Button {
                                                selectedBodyPart = part
                                                selectedExercise = exercise
                                            } label: {
                                                Text(exercise)
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedBodyPart)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())

                                Text(selectedExercise.isEmpty ? "種目を選択" : selectedExercise)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.caption.bold())
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }

                        HStack {
                            Spacer()

                            Text(selectedExerciseVolumeText)
                                .foregroundColor(.green)
                        }

                        NavigationLink {
                            WorkoutView(
                                initialSelectedBodyPart: selectedBodyPart,
                                initialSelectedExercise: selectedExercise,
                                showInputOnAppear: true
                            )
                        } label: {
                            Text("スタート")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.15))
                    .cornerRadius(14)

                    // 全体進捗（仮）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("進捗")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))

                        HStack {
                            VStack(alignment: .leading) {
                                Text("総重量")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.78))
                                Text("\(homeMetrics.totalVolume.formatted()) kg")
                                    .bold()
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            VStack(alignment: .leading) {
                                Text("連続")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.78))
                                Text("\(homeMetrics.streakDays)日")
                                    .bold()
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                }
                .padding()
            }
            .background(Color.black) // ← ★ここが正解位置
            .navigationDestination(isPresented: $showDayHistory) {
                HistoryView(selectedDate: selectedDate)
                    .environmentObject(viewModel)
            }
            .onAppear {
                viewModel.loadInitialData()
                normalizeSelection()
            }
            .onChange(of: selectedBodyPart) { _, _ in
                normalizeSelection()
            }
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: {
                viewModel.loadInitialData()
                normalizeSelection()
            }) {
                HomeAddExerciseView(
                    initialBodyPart: selectedBodyPart,
                    bodyPartOrder: bodyPartOrder
                ) { bodyPart, name in
                    viewModel.addNewExercise(name: name, bodyPart: bodyPart)
                    selectedBodyPart = bodyPart
                    selectedExercise = name
                }
            }
        }
    }
}

private struct CalendarSection: View {
    @Binding var selectedDate: Date
    let entries: [SetEntry]
    let onDateTap: () -> Void

    var body: some View {
        CalendarView(
            selectedDate: $selectedDate,
            markedDates: entries.map { $0.date }
        )
        .frame(height: 220)
        .background(Color.card)
        .cornerRadius(16)
        .onChange(of: selectedDate) { _, _ in
            onDateTap()
        }
    }
}

private struct HomeAddExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    let initialBodyPart: String
    let bodyPartOrder: [String]
    let onAdd: (String, String) -> Void

    @State private var bodyPart: String = ""
    @State private var exerciseName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("部位", selection: $bodyPart) {
                    ForEach(bodyPartOrder, id: \.self) { part in
                        Text(part).tag(part)
                    }
                }

                TextField("種目名", text: $exerciseName)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .navigationTitle("種目を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(bodyPart, trimmed)
                        dismiss()
                    }
                }
            }
            .onAppear {
                bodyPart = bodyPartOrder.contains(initialBodyPart) ? initialBodyPart : (bodyPartOrder.first ?? "胸")
            }
        }
    }
}
