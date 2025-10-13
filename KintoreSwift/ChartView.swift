//  ChartView.swift

import SwiftUI
import Charts

struct ChartView: View {
    var entries: [SetEntry]
    var grouping: GroupingType

    var body: some View {
        let groupedData = groupedEntries()

        Chart {
            ForEach(groupedData, id: \.0) { (date, avgWeight) in
                LineMark(
                    x: .value("日付", date),
                    y: .value("平均重量(kg)", avgWeight)
                )
                .foregroundStyle(.blue)
                .symbol(Circle())
                .lineStyle(.init(lineWidth: 3))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("日付", date),
                    y: .value("平均重量(kg)", avgWeight)
                )
                .foregroundStyle(.blue)
            }
        }
        .frame(height: 220)
        .chartYAxisLabel("重量 (kg)")
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXAxis {
            AxisMarks(values: groupedData.map { $0.0 }) { value in
                AxisGridLine() // グリッド線（縦線）
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.bottom, 8) // X軸ラベルとグラフの間に少し余白
    }

    // ✅ 各日ごとに「平均重量」を算出
    private func groupedEntries() -> [(Date, Double)] {
        var grouped: [Date: [Double]] = [:]
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
        }

        return grouped.map { (key, weights) in
            (key, weights.reduce(0, +) / Double(weights.count))
        }
        .sorted { $0.0 < $1.0 }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}
