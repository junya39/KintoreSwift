//  ChartView.swift

import SwiftUI
import Charts

struct ChartView: View {
    var entries: [SetEntry]
    var grouping: GroupingType

    var body: some View {
        let groupedData = groupedEntries()

        Chart {
            ForEach(groupedData, id: \.0) { (date, maxWeight, isBodyweight) in
                // 折れ線（通常 or 自重で色を変える）
                LineMark(
                    x: .value("日付", date),
                    y: .value("最大重量(kg)", maxWeight)
                )
                .foregroundStyle(isBodyweight ? .gray : .blue)
                .symbol(Circle())
                .lineStyle(.init(lineWidth: 3))
                .interpolationMethod(.catmullRom)

                // 各ポイント（自重の場合ラベルを表示）
                PointMark(
                    x: .value("日付", date),
                    y: .value("最大重量(kg)", maxWeight)
                )
                .foregroundStyle(isBodyweight ? .gray : .blue)
                .annotation(position: .top) {
                    if isBodyweight {
                        Text("自重")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    } else {
                        Text("\(Int(maxWeight))kg")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(height: 220)
        .chartYAxisLabel("重量 (kg)")
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXAxis {
            AxisMarks(values: groupedData.map { $0.0 }) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    // ✅ 各日ごとに「最大重量」を算出（自重フラグ付き）
    private func groupedEntries() -> [(Date, Double, Bool)] {
        var grouped: [Date: [Double]] = [:]
        var isBodyweightFlags: [Date: Bool] = [:]
        let calendar = Calendar.current

        for e in entries {
            let key: Date
            switch grouping {
            case .day:
                key = calendar.startOfDay(for: e.date)
            case .week:
                key = calendar.dateInterval(of: .weekOfYear, for: e.date)!.start
            case .month:
                key = calendar.dateInterval(of: .month, for: e.date)!.start
            }

            grouped[key, default: []].append(e.weight)
            // ✅ weight=0ならその日のデータを「自重」として扱う
            if e.weight == 0 {
                isBodyweightFlags[key] = true
            }
        }

        // 🔹 各日の「最大重量」を使用
        return grouped.map { (key, weights) in
            let maxWeight = weights.max() ?? 0
            let isBody = isBodyweightFlags[key] ?? false
            return (key, maxWeight, isBody)
        }
        .sorted { $0.0 < $1.0 }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

