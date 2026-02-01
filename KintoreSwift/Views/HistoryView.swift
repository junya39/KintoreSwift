// HistoryView.swift


import SwiftUI

struct HistoryView: View {

    let selectedDate: Date
    @StateObject private var viewModel = HistoryViewModel()

    private var dateTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: selectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 日付
                Text(dateTitle)
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                if viewModel.groups.isEmpty {
                    Text("この日の記録はありません")
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                }

                ForEach(viewModel.groups) { group in
                    ExerciseHistoryCard(group: group)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("")
        .onAppear {
            viewModel.load(date: selectedDate)
        }
    }
}
