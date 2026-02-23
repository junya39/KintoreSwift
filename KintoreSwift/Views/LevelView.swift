
//  LevelView.swift

import SwiftUI

struct LevelView: View {
    @StateObject var viewModel: LevelViewModel

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
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
