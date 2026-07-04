//  Components.swift

import SwiftUI

struct RoundedFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .font(.body)
    }
}

struct SegmentedPickerRow: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Picker(title, selection: $selection) {
                Text("左").tag("L")
                Text("右").tag("R")
                Text("なし").tag("")
            }
            .pickerStyle(.segmented)
        }
    }
}

/// Home画面基準の金グラデーションXPゲージ（共通トンマナ部品）
struct XPGaugeBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.gameGold, .gameGoldDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 12))
                    .shadow(color: .gameGold.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 14)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.headline)
        }
    }
}
