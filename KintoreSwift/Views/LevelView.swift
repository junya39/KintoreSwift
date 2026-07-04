
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Lv.\(viewModel.displayLevel)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.gameGold)
                        .monospacedDigit()

                    XPGaugeBar(progress: viewModel.progress)
                        .frame(height: 14)

                    Text("XP \(viewModel.userStatus.currentXP.formatted()) / \(viewModel.requiredXP.formatted())")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white.opacity(0.9))
                        .monospacedDigit()

                    Text("次のレベルまで あと\(viewModel.remainingXP.formatted()) XP")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 13)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.gameGold.opacity(0.3), lineWidth: 1)
                )

                HStack(spacing: 10) {
                    LevelStatCard(
                        icon: "flame.fill",
                        iconColor: .orange,
                        title: "POW",
                        value: viewModel.displayPower
                    )

                    LevelStatCard(
                        icon: "bolt.heart.fill",
                        iconColor: .cyan,
                        title: "END",
                        value: viewModel.displayEndurance
                    )
                }

                if viewModel.lastGainedXP > 0 {
                    VStack(spacing: 8) {
                        Text("前回獲得XP")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.white.opacity(0.6))
                        Text("+\(viewModel.lastGainedXP.formatted()) XP")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(.gameGold)
                            .monospacedDigit()
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
        .fontDesign(.rounded)
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

private struct LevelStatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.white.opacity(0.72))
            }

            Text("\(value.formatted())")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
