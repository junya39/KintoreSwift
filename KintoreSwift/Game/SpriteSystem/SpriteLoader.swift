import SpriteKit

enum SpriteLoader {
    static func loadIdleTextures() -> [SKTexture] {
        let atlas = SKTextureAtlas(named: "Player")
        let textures = [
            atlas.textureNamed("idle_1"),
            atlas.textureNamed("idle_2"),
            atlas.textureNamed("idle_3")
        ]
        textures.forEach { $0.filteringMode = .nearest }
        return textures
    }
}
