import SpriteKit

final class GameScene: SKScene {
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .black

        if childNode(withName: "player") == nil {
            let player = PlayerNode()
            player.name = "player"
            player.position = CGPoint(x: frame.midX, y: frame.midY)
            addChild(player)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        childNode(withName: "player")?.position = CGPoint(x: frame.midX, y: frame.midY)
    }
}
