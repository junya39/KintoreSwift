import SwiftUI
import UIKit

struct WorkoutAnalysisDebugView: View {
    let result: WorkoutAnalysisViewModel.AnalysisResult

    @Environment(\.dismiss) private var dismiss
    @State private var showsCopiedMessage = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        summaryGrid
                        jsonSection
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("AI分析用データ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        copyJSON()
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                    }
                    .accessibilityLabel("AI分析用データのJSONをコピー")
                }
            }
            .overlay(alignment: .bottom) {
                if showsCopiedMessage {
                    Text("コピーしました")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.green)
                        .clipShape(Capsule())
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .fontDesign(.rounded)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI分析用データ")
                .font(.title2.weight(.heavy))
                .foregroundColor(.white)

            Text("現在は接続前の確認画面です。このデータをもとに、今後AIがトレーニング内容を分析します。")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryGrid: some View {
        let summary = result.summary

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            SummaryTile(title: "対象日", value: summary.analysisDate, color: .green)
            SummaryTile(title: "合計セット数", value: "\(summary.totalSets)セット", color: .mint)
            SummaryTile(title: "合計回数", value: "\(summary.totalReps)回", color: .cyan)
            SummaryTile(title: "総ボリューム", value: "\(formatVolume(summary.totalVolumeKg))kg", color: .orange)
            SummaryTile(title: "種目数", value: "\(summary.exerciseCount)種目", color: .green)
        }
    }

    private var jsonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("JSON")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.green.opacity(0.9))

                Spacer()

                Button {
                    copyJSON()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                        Text("コピー")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("AI分析用データのJSONをコピー")
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(result.jsonText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.88))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func copyJSON() {
        UIPasteboard.general.string = result.jsonText
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            showsCopiedMessage = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                showsCopiedMessage = false
            }
        }
    }

    private func formatVolume(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundColor(.white.opacity(0.58))

            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.24), lineWidth: 1)
        )
    }
}

struct WorkoutAnalysisEmptyView: View {
    let result: WorkoutAnalysisViewModel.EmptyResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.green)
                        .frame(width: 78, height: 78)
                        .background(Color.green.opacity(0.14))
                        .clipShape(Circle())

                    Text(result.title)
                        .font(.title3.weight(.heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(result.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                            .font(.headline.weight(.heavy))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle("AI分析用データ")
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
    }
}
