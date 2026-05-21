
//  LevelView.swift

import SwiftUI

struct LevelView: View {
    @EnvironmentObject private var monsterManager: MonsterManager
    @StateObject var viewModel: LevelViewModel
    @State private var showResetConfirmation = false

    init(viewModel: LevelViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("Lv \(viewModel.displayLevel)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    ProgressView(value: viewModel.progress)
                        .tint(.green)
                        .scaleEffect(x: 1.0, y: 2.0, anchor: .center)

                    Text("\(viewModel.userStatus.currentXP.formatted()) / \(viewModel.requiredXP.formatted()) XP")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)

                    Text("次まで \(viewModel.remainingXP.formatted()) XP")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                HStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("POWER")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))
                        Text("\(viewModel.displayPower)")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)

                    VStack(spacing: 6) {
                        Text("ENDURANCE")
                            .font(.caption)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                            .foregroundColor(.white.opacity(0.72))
                        Text("\(viewModel.displayEndurance)")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }

                if viewModel.lastGainedXP > 0 {
                    VStack(spacing: 12) {
                        Text("前回獲得XP")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))
                        Text("+\(viewModel.lastGainedXP.formatted()) XP")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Lv / XP / MonsterDex をリセット", systemImage: "arrow.counterclockwise")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red.opacity(0.85))
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .alert("ステータスをリセット", isPresented: $showResetConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("リセット", role: .destructive) {
                viewModel.resetStatusProgress()
                monsterManager.resetUnlockProgress()
                MonsterUnlockToastCenter.shared.reset()
            }
        } message: {
            Text("過去の筋トレ記録は残したまま、Lv / XP / POWER / ENDURANCE / MonsterDex解放状態をリセットします。よろしいですか？")
        }
    }
}
