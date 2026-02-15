import SwiftUI
import UIKit

struct XPToastView: View {
    @ObservedObject private var center = XPToastCenter.shared
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .top) {
            if let item = center.current {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("+\(item.amount) XP")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        if let comboText = item.comboText {
                            Text(comboText)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                .scaleEffect(isVisible ? 1.15 : 0.8)
                .opacity(isVisible ? 1.0 : 0.0)
            }
        }
        .onChange(of: center.current?.id) { _, newId in
            guard newId != nil else { return }
            animateInAndOut()
        }
    }

    private func animateInAndOut() {
        isVisible = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            isVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                isVisible = false
            }
        }
    }
}
