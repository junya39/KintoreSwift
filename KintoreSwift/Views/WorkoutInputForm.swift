// WorkoutInputForm.swift
// セット記録の入力フォーム（Home / Workout 共用）

import SwiftUI

enum WorkoutInputField: Hashable {
    case reps
}

struct InputFormSection: View {
    @ObservedObject private var toastCenter = XPToastCenter.shared
    @ObservedObject private var monsterToastCenter = MonsterUnlockToastCenter.shared
    @EnvironmentObject private var userStatusVM: UserStatusViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var levelUpOverlayEvent: LevelUpEvent?
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
        NavigationStack {
        ZStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    if let item = toastCenter.current {
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

                    if let item = monsterToastCenter.current {
                        HStack(spacing: 12) {
                            Image(systemName: "pawprint.fill")
                                .font(.title3.weight(.black))
                                .foregroundStyle(Color.gameGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(item.monsterName)
                                    .font(.title3.weight(.heavy))
                                    .foregroundStyle(Color.gameGold)
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
                                .strokeBorder(Color.gameGold.opacity(0.55), lineWidth: 1.2)
                        )
                        .shadow(color: .gameGold.opacity(0.3), radius: 16, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    HStack(spacing: 8) {
                        Text(selectedBodyPart)
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.gameGold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.gameGold.opacity(0.15))
                            .clipShape(Capsule())

                        Button(action: onTapExercise) {
                            HStack(spacing: 4) {
                                Text(selectedExercise.isEmpty ? "種目未選択" : selectedExercise)
                                    .font(.headline.weight(.heavy))
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
                        .tint(.gameGold)
                        .font(.subheadline.weight(.semibold))
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
                            .background(Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        TextField("回数", text: $repsText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .reps)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                            .background(Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        TextField("メモ", text: $note)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 14)
                            .background(Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .foregroundColor(.white)

                    Button(action: onAdd) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline.weight(.black))
                            Text("このセットを追加")
                                .font(.headline.weight(.heavy))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.gameGold, .gameGoldDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: .gameGold.opacity(0.3), radius: 8, x: 0, y: 3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if let event = levelUpOverlayEvent {
                LevelUpOverlay(event: event) {
                    levelUpOverlayEvent = nil
                }
                .zIndex(999)
            } else if let title = titleUnlockOverlayTitle {
                LevelUpOverlay(title: title) {
                    titleUnlockOverlayTitle = nil
                }
                .zIndex(998)
            }
        }
        .navigationTitle("セットを記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
        }
        .fontDesign(.rounded)
        .onReceive(userStatusVM.$levelUpEvent) { event in
            guard let event else { return }
            levelUpOverlayEvent = event
            userStatusVM.levelUpEvent = nil
        }
        .onReceive(userStatusVM.titleManager.$titleUnlockEvent) { unlockedTitle in
            guard let unlockedTitle else { return }
            titleUnlockOverlayTitle = unlockedTitle
            userStatusVM.titleManager.titleUnlockEvent = nil
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: toastCenter.current?.id)
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: monsterToastCenter.current?.id)
    }
}
