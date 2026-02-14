// WorkoutView.swift

import SwiftUI
import Charts
import UIKit

private enum WorkoutSheet: String, Identifiable {
    case input
    case addExercise

    var id: String { rawValue }
}

struct WorkoutView: View {
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

    @StateObject private var viewModel = ContentViewModel()
    @EnvironmentObject private var userStatusVM: UserStatusViewModel

    // ✅ 日付タップで履歴へ遷移するためのフラグ
    @State private var showHistory = false
    @State private var showExerciseDetail = false
    @State private var selectedExerciseNameForDetail: String?
    @State private var showDeleteExerciseAlert = false
    @State private var deleteTargetExercise = ""
    @State private var showXPToast = false
    @State private var showLevelUpFlash = false
    @State private var showLevelUpOverlay = false
    @State private var levelUpScale: CGFloat = 0.5

    private let bodyParts = ["ALL", "胸", "背中", "脚", "肩", "腕", "腹筋"]

    // MARK: - Computed
    private var todayTotalVolume: Int {
        Int(filteredDailyEntries.reduce(0) { $0 + ($1.weight * Double($1.reps)) })
    }

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

                    CalendarSection(
                        selectedDate: $selectedDate,
                        entries: filteredEntries
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
                        isExerciseFilterEnabled: isExerciseFilterEnabled
                    )

                    if !filteredDailyEntries.isEmpty {
                        TodaySummarySection(totalVolume: todayTotalVolume)
                    }
                    }
                    .padding(.bottom, 32)
                }

                if showXPToast {
                    Text("+\(userStatusVM.lastGainedXP) XP")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                if showLevelUpFlash {
                    Color.yellow
                        .opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .zIndex(3)
                }

                if showLevelUpOverlay {
                    VStack(spacing: 8) {
                        Text("LEVEL UP!")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                        Text("Lv \(userStatusVM.level)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(levelUpScale)
                    .shadow(color: .yellow, radius: 20)
                    .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .zIndex(4)
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
            .onChange(of: userStatusVM.lastGainedXP) { _, value in
                guard value > 0 else { return }

                withAnimation {
                    showXPToast = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showXPToast = false
                        userStatusVM.lastGainedXP = 0
                    }
                }
            }
            .onChange(of: userStatusVM.didLevelUp) { _, value in
                if value {
                    triggerWorkoutLevelUp()
                }
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

        let weight = isBodyweight ? 0 : (Double(weightText) ?? 0)

        viewModel.addSet(
            date: selectedDate,
            bodyPart: selectedBodyPart,
            exercise: selectedExercise,
            weight: weight,
            reps: reps,
            note: note.isEmpty ? nil : note,
            side: selectedSide,
            userStatusVM: userStatusVM
        )

        weightText = ""
        repsText = ""
        note = ""
        selectedSide = ""
        isBodyweight = false
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

    private func triggerWorkoutLevelUp() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            levelUpScale = 1.0
            showLevelUpOverlay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showLevelUpOverlay = false
            }
            userStatusVM.didLevelUp = false
        }
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

private struct TodaySummarySection: View {
    let totalVolume: Int

    var body: some View {
        HStack {
            Text("合計")
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            Text("\(totalVolume) kg")
                .foregroundColor(.green)
                .bold()
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }
}

private struct CalendarSection: View {
    @Binding var selectedDate: Date
    let entries: [SetEntry]

    var body: some View {
        CalendarView(
            selectedDate: $selectedDate,
            markedDates: entries.map { $0.date }
        )
        .frame(height: 220)
        .background(Color.card)
        .cornerRadius(16)
        .padding(.horizontal, 16)
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

private struct DailyListSection: View {
    let dailyEntries: [SetEntry]
    let selectedBodyPart: String
    let selectedExercise: String
    let isExerciseFilterEnabled: Bool

    private func weightText(_ w: Double) -> String {
        w == 0 ? "自重" : "\(Int(w))kg"
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
            }
        }
    }
}

private struct InputFormSection: View {
    @EnvironmentObject private var userStatusVM: UserStatusViewModel
    @State private var showLevelUpOverlay = false
    @State private var levelUpScale: CGFloat = 0.3

    let selectedBodyPart: String
    let selectedExercise: String
    @Binding var isBodyweight: Bool
    @Binding var selectedSide: String
    @Binding var weightText: String
    @Binding var repsText: String
    @Binding var note: String
    let onTapExercise: () -> Void
    let onAdd: () -> Void

    private func triggerLevelUpAnimation() {
        showLevelUpOverlay = true
        levelUpScale = 0.3

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.easeOut(duration: 0.25)) {
            levelUpScale = 1.3
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                levelUpScale = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showLevelUpOverlay = false
            }
            userStatusVM.didLevelUp = false
        }
    }

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

            if showLevelUpOverlay {
                VStack {
                    Spacer()

                    Text("LEVEL UP!")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.8), radius: 20)
                        .scaleEffect(levelUpScale)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.4))
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .onChange(of: userStatusVM.didLevelUp) { _, value in
            if value {
                triggerLevelUpAnimation()
            }
        }
    }
}
