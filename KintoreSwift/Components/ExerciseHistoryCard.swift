
//  ExerciseHistoryCard.swift



import SwiftUI

struct ExerciseHistoryCard: View {

    let group: ExerciseHistoryGroup
    let onTap: () -> Void
    
    private var totalVolume: Int {
        group.sets.reduce(0) {
            $0 + Int($1.weight * Double($1.reps))
        }
    }


    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 種目名
            Text(group.exercise)
                .font(.headline)
                .foregroundColor(.white)

            // セット一覧
            // セット一覧（Set番号つき）
            ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 12) {

                    // Set番号
                    Text("Set \(index + 1)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 48, alignment: .leading)

                    // 重量 × 回数
                    Text(set.weight == 0
                         ? "自重 × \(set.reps)回"
                         : "\(Int(set.weight))kg × \(set.reps)回"
                    )
                    .foregroundColor(.white.opacity(0.9))

                    Spacer()
                }
            }
            
            // 合計ボリューム
            HStack {
                Spacer()

                Text("合計 \(totalVolume) kg")
                    .font(.caption)
                    .foregroundColor(.green.opacity(0.9))
            }


        }
        .padding()
        .background(Color.card)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}
