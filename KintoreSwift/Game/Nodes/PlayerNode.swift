import SpriteKit

final class PlayerNode: SKSpriteNode {
    private static let idleActionKey = "player.idle.animation"
    private let idleTextures: [SKTexture]

    init() {
        idleTextures = [
            SKTexture(imageNamed: "idle_1"),
            SKTexture(imageNamed: "idle_2"),
            SKTexture(imageNamed: "idle_3")
        ]
        super.init(texture: idleTextures[0], color: .clear, size: idleTextures[0].size())

        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        for texture in idleTextures {
            texture.filteringMode = .nearest
        }
        self.size = CGSize(width: 256, height: 256)
        runIdleAnimation()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func runIdleAnimation() {
        removeAction(forKey: Self.idleActionKey)
        let idle = SKAction.animate(with: idleTextures, timePerFrame: 0.4)
        run(SKAction.repeatForever(idle), withKey: Self.idleActionKey)
    }
}
