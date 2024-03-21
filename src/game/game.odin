package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"

v2 :: dm.v2
iv2 :: dm.iv2

GameState :: struct {
    camera: dm.Camera,

    player: Player,
    playerBullets: [dynamic]Bullet

}

gameState: ^GameState

//////////

Player :: struct {
    position: v2,

    sprite: dm.Sprite,

    gunSprite: dm.Sprite,
    gunRotation: f32,
}

ControlPlayer :: proc(player: ^Player) {
    horizontal := dm.GetAxis(.A, .D)
    vertical := dm.GetAxis(.S, .W)

    move := v2{horizontal, vertical} * PLAYER_MOVE_SPEED * f32(dm.time.deltaTime)

    player.position += move

    // aiming
    mousePos := dm.input.mousePos
    worldPos := dm.ScreenToWorldSpace(gameState.camera, mousePos, dm.renderCtx.frameSize)

    aimDelta := v2{worldPos.x, worldPos.y} - player.position
    angle := math.atan2(aimDelta.y, aimDelta.x)
    player.gunRotation = angle

    // shooting

    muzzlePos := player.position + glsl.normalize(aimDelta) - {0.25, 0.2}
    if dm.GetMouseButton(.Left) == .JustPressed {
        for i in 0..=5 {
            variation := rand.float32() * 0.2 - 0.1
            SpawnBullet(muzzlePos, angle + variation)
        }
    }

    player.gunSprite.flipY = math.abs(angle) > math.PI / 2

}


//////////////////

Bullet :: struct {
    startPosition: v2,
    startRotation: f32,
    spawnTime: f32,

    position: v2,
    rotation: f32,

    sprite: dm.Sprite,

    speed: f32,
}

UpdateBullet :: proc(bullet: ^Bullet) {
    bullet.rotation = bullet.startRotation
    direction := v2{
        math.cos(bullet.rotation),
        math.sin(bullet.rotation),
    }

    lifeTime := f32(dm.time.gameTime) - bullet.spawnTime
    bullet.position = bullet.startPosition + direction * bullet.speed * lifeTime
}

SpawnBullet :: proc(position: v2, rotation: f32) {
    bullet := Bullet{
        startPosition = position,
        startRotation = rotation,
        spawnTime = f32(dm.time.gameTime),

        sprite = dm.CreateSprite(dm.renderCtx.whiteTexture, {0, 0, 1, 1}),

        speed = 10,
    }

    bullet.sprite.scale = 0.2

    append(&gameState.playerBullets, bullet)
}

@export
PreGameLoad : dm.PreGameLoad : proc(assets: ^dm.Assets) {
    dm.RegisterAsset("maemi.png", dm.TextureAssetDescriptor {
        filter = .Point
    })
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)

    gameState.camera = dm.CreateCamera(3, 8./6.)

    maemiSprite := dm.GetTextureAsset("maemi.png")
    gameState.player.sprite = dm.CreateSprite(maemiSprite, {0, 0, 24, 40})
    gameState.player.gunSprite = dm.CreateSprite(maemiSprite, {0, 41, 24, 6})
    gameState.player.gunSprite.origin = {0.18, 0.5}

}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState := transmute(^GameState) state

    ControlPlayer(&gameState.player)

    for &bullet in gameState.playerBullets {
        UpdateBullet(&bullet)
    }
}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr, debug: bool) {
}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    gameState = cast(^GameState) state

    dm.SetCamera(gameState.camera)
    dm.ClearColor({0.1, 0.2, 0.4, 1})


    dm.DrawSprite(gameState.player.sprite, gameState.player.position)
    dm.DrawSprite(gameState.player.gunSprite, gameState.player.position - {0.05, 0.2}, 
        rotation = gameState.player.gunRotation
    )


    for &bullet in gameState.playerBullets {
        dm.DrawSprite(bullet.sprite, bullet.position, rotation = bullet.rotation)
    }
}