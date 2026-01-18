// HomeView.swift

import SwiftUI

struct HomeView: View {
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

                    // レベルカード（仮）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lv 12")
                            .font(.headline)
                            .foregroundColor(.white)

                        ProgressView(value: 0.72)
                            .tint(.green)

                        Text("4,300 / 4,500 XP")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.15))
                    .cornerRadius(14)

                    // 今日のワークアウト
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Workout")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.45))
                        
                        HStack {
                            Text("Bench Press")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.white)

                            Spacer()

                            Text("1,000 kg")
                                .foregroundColor(.green)
                        }

                        NavigationLink {
                            WorkoutView()
                        } label: {
                            Text("Start Workout")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.15))
                    .cornerRadius(14)

                    // 全体進捗（仮）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overall Progress")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.45))

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Volume")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                Text("120,000 kg")
                                    .bold()
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            VStack(alignment: .leading) {
                                Text("Streak")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("25 days")
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
        }
    }
}

