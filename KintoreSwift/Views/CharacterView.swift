import SwiftUI
import Combine

enum AnimationSpeed {
    static let evolution: Double = 0.2
    static let skinnyIdle: Double = 0.35
    static let machoIdle: Double = 0.4
    static let finalFormIdle: Double = 0.5
}

struct CharacterView: View {
    let level: Int

    @State private var frameIndex = 0

    private var form: CharacterForm {
        getCharacterForm(level: level)
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: idleFrameInterval, on: .main, in: .common).autoconnect()
    }

    private var idleFrameInterval: Double {
        switch form {
        case .skinny:
            return AnimationSpeed.skinnyIdle
        case .macho:
            return AnimationSpeed.machoIdle
        case .finalForm:
            return AnimationSpeed.finalFormIdle
        }
    }

    var body: some View {
        let images = getCharacterImages(form: form)

        Image(images[frameIndex])
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: 150, height: 150)
            .onReceive(timer) { _ in
                guard !images.isEmpty else { return }
                frameIndex = (frameIndex + 1) % images.count
            }
    }
}
