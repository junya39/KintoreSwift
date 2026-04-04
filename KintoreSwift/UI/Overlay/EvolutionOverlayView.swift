import SwiftUI

struct EvolutionOverlayView: View {
    let event: EvolutionEvent
    let imageNames: [String]

    @State private var flashOpacity: Double = 0.0
    @State private var bgOpacity: Double = 0.0
    @State private var contentOpacity: Double = 0.0
    @State private var contentScale: CGFloat = 0.82
    @State private var glowScale: CGFloat = 0.7
    @State private var frameIndex = 0

    private let timer = Timer.publish(every: AnimationSpeed.evolution, on: .main, in: .common).autoconnect()

    private var currentImageName: String {
        guard !imageNames.isEmpty else { return "lv1_idle_1" }
        return imageNames[frameIndex % imageNames.count]
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(bgOpacity)
                .ignoresSafeArea()

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 12)
                .scaleEffect(glowScale)

            VStack(spacing: 18) {
                Text("進化")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(.white)

                Image(currentImageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 180, height: 180)

                Text("\(event.fromName) → \(event.toName)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text("新しい形態に進化しました")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.black.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            startAnimation()
        }
        .onReceive(timer) { _ in
            guard !imageNames.isEmpty else { return }
            frameIndex = (frameIndex + 1) % imageNames.count
        }
    }

    private func startAnimation() {
        withAnimation(.easeOut(duration: 0.22)) {
            bgOpacity = 0.55
            flashOpacity = 0.52
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            contentOpacity = 1.0
            contentScale = 1.0
            glowScale = 1.08
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.9)) {
                flashOpacity = 0.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeInOut(duration: 0.95)) {
                contentOpacity = 0.0
                bgOpacity = 0.0
                contentScale = 1.06
                glowScale = 1.16
            }
        }
    }
}
