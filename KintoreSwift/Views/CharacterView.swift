import SwiftUI
import Combine

struct CharacterView: View {
    let level: Int

    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        let form = getCharacterForm(level: level)
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
