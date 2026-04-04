// WorkoutView.swift

import SwiftUI
import Charts
import UIKit

private enum WorkoutSheet: String, Identifiable {
    case input
    case addExercise

    var id: String { rawValue }
}

private enum WorkoutInputField: Hashable {
    case reps
}

struct WorkoutView: View {
    private let xpHighlightDuration: TimeInterval = 2.8

    private let initialSelectedBodyPart: String?
    private let initialSelectedExercise: String?
    private let showInputOnAppear: Bool

    // MARK: - State
    @State private var selectedDate = Date()
    @State private var selectedBodyPart = "ALL"
    @State private var selectedExercise = "ベンチプレス"

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var note = ""
    @State private var isBodyweight = false
    @State private var selectedSide = ""

    @State private var newExerciseName = ""
    @State private var activeSheet: WorkoutSheet?
    @State private var didSetInitialSheetState = false
    @State private var isExerciseFilterEnabled: Bool
    @State private var isEditingTimer = false
    @State private var tempMinute = 2
    @State private var tempSecond = 0
    @FocusState private var focusedInputField: WorkoutInputField?

    @StateObject private var viewModel = WorkoutViewModel()
    @StateObject private var timerVM = IntervalTimerViewModel()
    @EnvironmentObject private var userStatusVM: UserStatusViewModel

    // ✅ 日付タップで履歴へ遷移するためのフラグ
    @State private var showHistory = false
    @State private var showExerciseDetail = false
    @State private var selectedExerciseNameForDetail: String?
    @State private var showDeleteExerciseAlert = false
    @State private var deleteTargetExercise = ""
    @State private var showLevelUpFlash = false

    private let bodyParts = ["ALL", "胸", "背中", "脚", "肩", "腕", "腹筋"]

    // MARK: - Computed
    private var filteredEntries: [SetEntry] {
        let bodyFiltered: [SetEntry]
        if selectedBodyPart == "ALL" {
            bodyFiltered = viewModel.entries
        } else {
            bodyFiltered = viewModel.entries.filter { $0.bodyPart == selectedBodyPart }
        }
        if isExerciseFilterEnabled && !selectedExercise.isEmpty {
            return bodyFiltered.filter { $0.exercise == selectedExercise }
        }
        return bodyFiltered
    }

    private var filteredDailyEntries: [SetEntry] {
        filteredEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
    }

    private var exerciseLastUpdatedAt: [String: Date] {
        Dictionary(grouping: viewModel.entries, by: { $0.exercise })
            .mapValues { entries in
                entries.map(\.date).max() ?? .distantPast
            }
    }

    private var allExercisesSortedByRecent: [String] {
        var all = Set(viewModel.exercises.values.flatMap { $0 })
        all.formUnion(viewModel.entries.map { $0.exercise })
        all.subtract(viewModel.deletedExerciseNames)
        return all.sorted { lhs, rhs in
            let lhsDate = exerciseLastUpdatedAt[lhs] ?? .distantPast
            let rhsDate = exerciseLastUpdatedAt[rhs] ?? .distantPast
            if lhsDate == rhsDate { return lhs < rhs }
            return lhsDate > rhsDate
        }
    }

    private func exercises(for bodyPart: String) -> [String] {
        if bodyPart == "ALL" {
            return allExercisesSortedByRecent
        }
        return viewModel.exercises[bodyPart] ?? []
    }

    private var displayedExercises: [String] {
        exercises(for: selectedBodyPart)
    }

    init(
        initialSelectedBodyPart: String? = nil,
        initialSelectedExercise: String? = nil,
        showInputOnAppear: Bool = false
    ) {
        self.initialSelectedBodyPart = initialSelectedBodyPart
        self.initialSelectedExercise = initialSelectedExercise
        self.showInputOnAppear = showInputOnAppear
        _selectedBodyPart = State(initialValue: initialSelectedBodyPart ?? "ALL")
        _selectedExercise = State(initialValue: initialSelectedExercise ?? "ベンチプレス")
        _isExerciseFilterEnabled = State(initialValue: initialSelectedExercise != nil)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                    HeaderSection()

                    TrainingDashboardSection(
                        remainingSeconds: timerVM.remainingTime(),
                        currentLevel: viewModel.currentLevel,
                        currentXP: userStatusVM.currentXP,
                        requiredXP: userStatusVM.requiredXP(for: userStatusVM.level),
                        xpProgress: userStatusVM.getProgress(),
                        lastSetText: viewModel.getLastSet(for: selectedExercise),
                        isRunning: timerVM.isRunning,
                        isEditingTimer: $isEditingTimer,
                        tempMinute: $tempMinute,
                        tempSecond: $tempSecond,
                        onTimeTap: {
                            timerVM.stop()
                            let total = min(timerVM.duration, 3600)
                            tempMinute = total / 60
                            tempSecond = total % 60
                            isEditingTimer = true
                        },
                        onDoneTap: {
                            let newValue = tempMinute * 60 + tempSecond
                            if newValue > 0 {
                                timerVM.duration = newValue
                                timerVM.reset()
                            }
                            isEditingTimer = false
                        },
                        onPrimaryTap: {
                            if timerVM.isRunning {
                                timerVM.stop()
                            } else {
                                if timerVM.remainingTime() == 0 {
                                    timerVM.reset()
                                }
                                timerVM.start()
                            }
                        },
                        onResetTap: {
                            timerVM.reset()
                        }
                    )

                    BodyPartSection(
                        selectedBodyPart: $selectedBodyPart,
                        bodyParts: bodyParts,
                        onSelectBodyPart: { part in
                            selectedBodyPart = part
                            isExerciseFilterEnabled = false
                            selectedExercise = exercises(for: part).first ?? ""
                        }
                    )

                    ExercisePickerSection(
                        selectedExercise: $selectedExercise,
                        exercises: displayedExercises,
                        onAdd: { activeSheet = .addExercise },
                        onDeleteExercise: { exercise in
                            requestExerciseDeletion(exercise)
                        },
                        onSelectExercise: {
                            isExerciseFilterEnabled = true
                            guard activeSheet != .addExercise else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeSheet = .input
                            }
                        }
                    )

                    DailyListSection(
                        dailyEntries: filteredDailyEntries,
                        selectedBodyPart: selectedBodyPart,
                        selectedExercise: selectedExercise,
                        isExerciseFilterEnabled: isExerciseFilterEnabled,
                        totalWeight: viewModel.todayTotalWeight,
                        totalReps: viewModel.todayTotalReps
                    )
                    }
                    .padding(.bottom, 32)
                }

                if showLevelUpFlash {
                    Color.yellow
                        .opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .zIndex(3)
                }

            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeSheet = (activeSheet == .input) ? nil : .input
                        }
                    } label: {
                        Image(systemName: activeSheet == .input ? "xmark" : "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.cardSub.opacity(0.95))
                            .clipShape(Circle())
                    }
                }
            }
            .onAppear {
                viewModel.loadInitialData()
                viewModel.currentLevel = userStatusVM.level
                timerVM.startTimerIfNeeded()
                if let bodyPart = initialSelectedBodyPart, bodyPart == "ALL" || viewModel.exercises.keys.contains(bodyPart) {
                    selectedBodyPart = bodyPart
                }
                let currentExercises = exercises(for: selectedBodyPart)
                if let exercise = initialSelectedExercise,
                   currentExercises.contains(exercise) {
                    selectedExercise = exercise
                } else if currentExercises.contains(selectedExercise) == false {
                    selectedExercise = currentExercises.first ?? ""
                }
                viewModel.updateDailyEntries(for: selectedDate)
                if !didSetInitialSheetState {
                    if showInputOnAppear {
                        activeSheet = .input
                    } else {
                        activeSheet = filteredDailyEntries.isEmpty ? .input : nil
                    }
                    didSetInitialSheetState = true
                }
            }
            .alert("種目を削除", isPresented: $showDeleteExerciseAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    confirmExerciseDeletion()
                }
            } message: {
                Text("「\(deleteTargetExercise)」を種目一覧から削除します。")
            }

            // ✅ カレンダーで日付が変わった瞬間に「その日」の一覧へ
            .onChange(of: selectedDate) { _, newValue in
                viewModel.updateDailyEntries(for: newValue)
                showHistory = true
            }
            .onChange(of: userStatusVM.level) { oldLevel, newLevel in
                viewModel.currentLevel = newLevel
                guard newLevel > oldLevel else { return }
                userStatusVM.levelUpEvent = newLevel
            }

            // ✅ iOS 16+ 推奨の遷移（deprecated回避）
            .navigationDestination(isPresented: $showHistory) {
                // HistoryView が「selectedDate だけ」を受け取る前提
                HistoryView(selectedDate: selectedDate)
                    .environmentObject(viewModel)
            }
            .navigationDestination(isPresented: $showExerciseDetail) {
                if let name = selectedExerciseNameForDetail {
                    ExerciseDetailView(
                        exerciseName: name,
                        contentViewModel: viewModel
                    )
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .input:
                    InputFormSection(
                        selectedBodyPart: selectedBodyPart,
                        selectedExercise: selectedExercise,
                        isBodyweight: $isBodyweight,
                        selectedSide: $selectedSide,
                        weightText: $weightText,
                        repsText: $repsText,
                        note: $note,
                        focusedField: $focusedInputField,
                        onTapExercise: {
                            openExerciseDetailFromInputForm()
                        },
                        onAdd: addSet
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
                    .preferredColorScheme(.dark)
                case .addExercise:
                    VStack(spacing: 16) {
                        Text("新しい種目を追加")
                            .font(.headline)

                        TextField("種目名", text: $newExerciseName)
                            .keyboardType(.default)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("キャンセル") {
                                activeSheet = nil
                            }

                            Button("追加") {
                                addNewExercise()
                                activeSheet = nil
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Actions
    private func addSet() {
        guard let reps = Int(repsText), !selectedExercise.isEmpty else { return }

        let currentSide = selectedSide
        let weight = isBodyweight ? 0 : (Double(weightText) ?? 0)
        let actualBodyPart = selectedBodyPart == "ALL"
            ? viewModel.bodyPart(for: selectedExercise)
            : selectedBodyPart

        viewModel.addSet(
            date: selectedDate,
            bodyPart: actualBodyPart,
            exercise: selectedExercise,
            weight: weight,
            isBodyweight: isBodyweight,
            reps: reps,
            note: note.isEmpty ? nil : note,
            side: selectedSide,
            userStatusVM: userStatusVM
        )

        let postSaveSideAction = viewModel.postSaveSideAction(for: currentSide)

        let gainedXP = userStatusVM.lastGainedXP
        if gainedXP > 0 {
            XPToastCenter.shared.show(xp: gainedXP)
            userStatusVM.lastGainedXP = 0
        }

        if postSaveSideAction != .none {
            let delay = gainedXP > 0 ? xpHighlightDuration : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                applySideTransition(postSaveSideAction)
            }
        } else {
            weightText = ""
            repsText = ""
            note = ""
            selectedSide = ""
            isBodyweight = false
        }

        timerVM.reset()
        timerVM.start()
    }

    private func applySideTransition(_ action: ContentViewModel.PostSaveSideAction) {
        switch action {
        case .switchToLeft:
            selectedSide = "L"
        case .switchToRight:
            selectedSide = "R"
        case .none:
            return
        }

        repsText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.async {
            focusedInputField = .reps
        }
    }

    private func addNewExercise() {
        guard !newExerciseName.isEmpty else { return }
        viewModel.addNewExercise(
            name: newExerciseName,
            bodyPart: selectedBodyPart
        )
        selectedExercise = newExerciseName
        newExerciseName = ""
    }

    private func openExerciseDetailFromInputForm() {
        guard !selectedExercise.isEmpty else { return }
        selectedExerciseNameForDetail = selectedExercise
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showExerciseDetail = true
        }
    }

    private func requestExerciseDeletion(_ name: String) {
        guard !name.isEmpty else { return }
        deleteTargetExercise = name
        showDeleteExerciseAlert = true
    }

    private func confirmExerciseDeletion() {
        let name = deleteTargetExercise
        guard !name.isEmpty else { return }

        viewModel.deleteExercise(
            name: name,
            selectedDate: selectedDate,
            selectedExercise: selectedExercise
        )

        let availableExercises = exercises(for: selectedBodyPart)
        if selectedExercise == name {
            selectedExercise = availableExercises.first ?? ""
        }
        if selectedExerciseNameForDetail == name {
            selectedExerciseNameForDetail = nil
        }
        if selectedExercise.isEmpty {
            isExerciseFilterEnabled = false
        }

        deleteTargetExercise = ""
    }

}

//
// MARK: - Sections
//

private struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Workout")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
    }
}

private struct TrainingDashboardSection: View {
    let remainingSeconds: Int
    let currentLevel: Int
    let currentXP: Int
    let requiredXP: Int
    let xpProgress: Double
    let lastSetText: String
    let isRunning: Bool
    @Binding var isEditingTimer: Bool
    @Binding var tempMinute: Int
    @Binding var tempSecond: Int
    let onTimeTap: () -> Void
    let onDoneTap: () -> Void
    let onPrimaryTap: () -> Void
    let onResetTap: () -> Void

    private var timerText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("タイマー")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))
                Spacer()
                Text(timerText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .onTapGesture(perform: onTimeTap)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("XP")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                    Spacer()
                    Text("Lv \(currentLevel)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accent)
                    Text("\(currentXP) / \(requiredXP)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                ProgressView(value: xpProgress)
                    .tint(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("前セット")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                Text(lastSetText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }

            HStack {
                Spacer()

                if !isEditingTimer {
                    Button(action: onPrimaryTap) {
                        Text(isRunning ? "停止" : "開始")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.accent)
                            .clipShape(Capsule())
                    }

                    Button(action: onResetTap) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }

            if isEditingTimer {
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Picker("", selection: $tempMinute) {
                            ForEach(0...60, id: \.self) { value in
                                Text("\(value)分")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .colorScheme(.dark)
                        .tint(.green)
                        .frame(maxWidth: .infinity)

                        Picker("", selection: $tempSecond) {
                            ForEach(0..<60, id: \.self) { value in
                                Text("\(value)秒")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .colorScheme(.dark)
                        .tint(.green)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 200)

                    Button("完了") {
                        onDoneTap()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accent)
                    .clipShape(Capsule())
                }
                .transition(.move(edge: .bottom))
            }
        }
        .padding()
        .background(Color.card)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: isEditingTimer)
    }
}

private struct BodyPartSection: View {
    @Binding var selectedBodyPart: String
    let bodyParts: [String]
    let onSelectBodyPart: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(bodyParts, id: \.self) { part in
                    Button {
                        onSelectBodyPart(part)
                    } label: {
                        Text(part)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedBodyPart == part
                                ? Color.green.opacity(0.25)
                                : Color.white.opacity(0.08)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct ExercisePickerSection: View {
    @Binding var selectedExercise: String
    let exercises: [String]
    let onAdd: () -> Void
    let onDeleteExercise: (String) -> Void
    let onSelectExercise: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("種目")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))

                Spacer()

                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }

            if exercises.isEmpty {
                Text("種目がありません。右上の + から追加してください。")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(exercises, id: \.self) { exercise in
                            Button {
                                selectedExercise = exercise
                                onSelectExercise()
                            } label: {
                                Text(exercise)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(selectedExercise == exercise ? .black : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedExercise == exercise
                                        ? Color.accent
                                        : Color.cardSub
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDeleteExercise(exercise)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.card)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

private struct IntervalTimerSection: View {
    let isRunning: Bool
    @Binding var isEditingTimer: Bool
    @Binding var tempMinute: Int
    @Binding var tempSecond: Int
    let onDoneTap: () -> Void
    let onPrimaryTap: () -> Void
    let onResetTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()

                if !isEditingTimer {
                    Button(action: onPrimaryTap) {
                        Text(isRunning ? "停止" : "開始")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.accent)
                            .clipShape(Capsule())
                    }

                    Button(action: onResetTap) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }

            if isEditingTimer {
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Picker("", selection: $tempMinute) {
                            ForEach(0...60, id: \.self) { value in
                                Text("\(value)分")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .colorScheme(.dark)
                        .tint(.green)
                        .frame(maxWidth: .infinity)

                        Picker("", selection: $tempSecond) {
                            ForEach(0..<60, id: \.self) { value in
                                Text("\(value)秒")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .colorScheme(.dark)
                        .tint(.green)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 200)

                    Button("完了") {
                        onDoneTap()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accent)
                    .clipShape(Capsule())
                }
                .transition(.move(edge: .bottom))
            }
        }
        .padding()
        .background(Color.card)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: isEditingTimer)
    }
}

private struct DailyListSection: View {
    let dailyEntries: [SetEntry]
    let selectedBodyPart: String
    let selectedExercise: String
    let isExerciseFilterEnabled: Bool
    let totalWeight: Double
    let totalReps: Int

    private func weightText(_ w: Double) -> String {
        w == 0 ? "自重" : String(format: "%.1fkg", w)
    }

    private var filterSummary: String {
        if isExerciseFilterEnabled && !selectedExercise.isEmpty {
            return "\(selectedBodyPart) / \(selectedExercise)"
        }
        if selectedBodyPart == "ALL" {
            return "全ての部位・種目"
        }
        return "\(selectedBodyPart) の全種目"
    }

    var body: some View {
        if !dailyEntries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本日の記録")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(filterSummary)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)

                ForEach(dailyEntries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(entry.bodyPart)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accent.opacity(0.15))
                                .clipShape(Capsule())

                            Text(entry.exercise)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(1)

                            Spacer()
                        }

                        HStack {
                            Text("\(weightText(entry.weight)) × \(entry.reps)回")
                                .foregroundColor(.white)
                            if let side = entry.side, !side.isEmpty {
                                Text(side == "R" ? "(右)" : "(左)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.65))
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.card)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 4) {
                    HStack {
                        Text("合計")
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        Text("\(totalWeight, specifier: "%.0f") kg")
                            .foregroundColor(.green)
                            .font(.title3)
                            .bold()
                    }

                    HStack {
                        Spacer()

                        Text("\(totalReps) 回")
                            .foregroundColor(.green)
                            .font(.title3)
                            .bold()
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct InputFormSection: View {
    @ObservedObject private var toastCenter = XPToastCenter.shared
    @EnvironmentObject private var userStatusVM: UserStatusViewModel
    @State private var levelUpOverlayLevel: Int?
    @State private var titleUnlockOverlayTitle: Title?

    let selectedBodyPart: String
    let selectedExercise: String
    @Binding var isBodyweight: Bool
    @Binding var selectedSide: String
    @Binding var weightText: String
    @Binding var repsText: String
    @Binding var note: String
    @FocusState.Binding var focusedField: WorkoutInputField?
    let onTapExercise: () -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack {
            ZStack {
                LinearGradient(
                    colors: [Color.cardSub, Color.bg],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 44, height: 5)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text("セットを記録")
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    if let item = toastCenter.current, userStatusVM.evolutionEvent == nil {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .font(.title3.weight(.black))
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("+\(item.amount) XP")
                                    .font(.title2.weight(.heavy))
                                    .foregroundStyle(.white)
                                if let comboText = item.comboText {
                                    Text(comboText)
                                        .font(.subheadline.weight(.black))
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.75))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(.yellow.opacity(0.55), lineWidth: 1.2)
                        )
                        .shadow(color: .yellow.opacity(0.35), radius: 16, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
                        .scaleEffect(item.comboText == nil ? 1.0 : 1.07)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    HStack(spacing: 8) {
                        Text(selectedBodyPart)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accent.opacity(0.15))
                            .clipShape(Capsule())

                        Button(action: onTapExercise) {
                            HStack(spacing: 4) {
                                Text(selectedExercise.isEmpty ? "種目未選択" : selectedExercise)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Toggle("自重トレーニング", isOn: $isBodyweight)
                        .tint(.accent)
                        .foregroundColor(.white.opacity(0.9))

                    Picker("左右", selection: $selectedSide) {
                        Text("左").tag("L")
                        Text("右").tag("R")
                        Text("なし").tag("")
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 10) {
                        TextField("重量 (kg)", text: $weightText)
                            .keyboardType(.decimalPad)
                            .disabled(isBodyweight)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        TextField("回数", text: $repsText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .reps)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        TextField("メモ", text: $note)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .foregroundColor(.white)

                    Button(action: onAdd) {
                        Text("このセットを追加")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.accent.opacity(0.95), Color.accent.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if let level = levelUpOverlayLevel {
                LevelUpOverlay(level: level) {
                    levelUpOverlayLevel = nil
                }
                .zIndex(998)
            } else if let title = titleUnlockOverlayTitle {
                LevelUpOverlay(title: title) {
                    titleUnlockOverlayTitle = nil
                }
                .zIndex(997)
            }
        }
        .onReceive(userStatusVM.$levelUpEvent) { newLevel in
            guard let level = newLevel else { return }
            guard level != 15, level != 30 else {
                userStatusVM.levelUpEvent = nil
                return
            }
            levelUpOverlayLevel = level
            userStatusVM.levelUpEvent = nil
        }
        .onReceive(userStatusVM.titleManager.$newlyUnlockedTitle) { unlockedTitle in
            guard let unlockedTitle else { return }
            titleUnlockOverlayTitle = unlockedTitle
            userStatusVM.titleManager.newlyUnlockedTitle = nil
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: toastCenter.current?.id)
    }
}
