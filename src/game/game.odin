package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "../ldtk"

v2 :: dm.v2
iv2 :: dm.iv2

GameState :: struct {
    camera: dm.Camera,

    player: Player,
    playerBullets: [dynamic]Bullet,

    level: Level,
}

gameState: ^GameState

//////////////////

Bullet :: struct {
    startPosition: v2,
    startRotation: f32,
    spawnTime: f32,

    position: v2,
    rotation: f32,

    sprite: dm.Sprite,

    radius: f32,

    speed: f32,
}

MaemiCharacter: Character

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

        radius = 0.2,
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

    dm.RegisterAsset("tiles.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("level.ldtk", dm.RawFileAssetDescriptor{})
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)

    gameState.camera = dm.CreateCamera(6, 8./6.)

    // Characters
    maemiSprite := dm.GetTextureAsset("maemi.png")
    MaemiCharacter.idleSprites[.South] = dm.CreateSprite(maemiSprite, {0, 0, 24, 40}, origin = {0.5, 1})
    MaemiCharacter.idleSprites[.East]  = dm.CreateSprite(maemiSprite, {0, 0, 24, 40}, origin = {0.5, 1})
    MaemiCharacter.idleSprites[.North] = dm.CreateSprite(maemiSprite, {0, 0, 24, 40}, origin = {0.5, 1})
    MaemiCharacter.idleSprites[.West]  = dm.CreateSprite(maemiSprite, {0, 0, 24, 40}, origin = {0.5, 1})
    
    MaemiCharacter.idleSprites[.East].tint  = dm.RED
    MaemiCharacter.idleSprites[.North].tint = dm.GREEN
    MaemiCharacter.idleSprites[.West].tint  = dm.BLUE

    MaemiCharacter.gunSprite = dm.CreateSprite(maemiSprite, {0, 41, 24, 6}, origin = {0.18, 0.5})
    MaemiCharacter.gunOffset = {-0.2, 0.6}
    MaemiCharacter.muzzleOffset = {-0.25, -0.2}

    // Player
    gameState.player.character = MaemiCharacter
    gameState.player.wallCollisionSize = {1, 0.2}

    LoadLevel(gameState)
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState := transmute(^GameState) state

    ControlPlayer(&gameState.player)

    for &bullet in gameState.playerBullets {
        UpdateBullet(&bullet)
    }


    #reverse for bullet, i in gameState.playerBullets {
        for wall in gameState.level.walls {
            if dm.CheckCollisionBoundsCircle(wall.bounds, bullet.position, bullet.radius) {
                unordered_remove(&gameState.playerBullets, i)
                break
            }
        }
    }

    // DEBUG
    dm.DrawBox2D(dm.renderCtx, gameState.player.position, gameState.player.wallCollisionSize, false, dm.RED)

    for wall in gameState.level.walls {
        // dm.DrawBox2D(dm.renderCtx, wall.position, wall.size, false)
        dm.DrawBounds2D(dm.renderCtx, wall.bounds, false)
    }

    for bullet in gameState.playerBullets {
        dm.DrawCircle(dm.renderCtx, bullet.position, bullet.radius, false)
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

    // Level
    for tile in gameState.level.tiles {
        dm.DrawSprite(tile.sprite, tile.position)
    }

    for wall in gameState.level.walls {
        dm.DrawSprite(wall.sprite, wall.position)
    }

    // Player
    player := &gameState.player
    character := &player.character
    playerSprite := character.idleSprites[player.heading]

    dm.DrawSprite(playerSprite, player.position)
    dm.DrawSprite(character.gunSprite, player.position + character.gunOffset, 
        rotation = player.gunRotation
    )


    for &bullet in gameState.playerBullets {
        dm.DrawSprite(bullet.sprite, bullet.position, rotation = bullet.rotation)
    }

    dm.DrawBlankSprite({0,0}, {0.1, 0.1}, dm.RED)
}