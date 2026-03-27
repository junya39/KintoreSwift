import SwiftUI
import SpriteKit

struct GameSpriteView: View {
    private let scene: SKScene

    init() {
        self.scene = GameScene(size: CGSize(width: 256, height: 256))
    }

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea(edges: [])
    }
}
