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
    gameStarted: bool,

    menu: Menu,

    camera: dm.Camera,

    player: Player,
    playerHP: int,

    bullets: [dynamic]Bullet,

    level: Level,

    boss: Boss,
}

gameState: ^GameState

@export
PreGameLoad : dm.PreGameLoad : proc(assets: ^dm.Assets) {
    dm.RegisterAsset("maemi.png", dm.TextureAssetDescriptor {})

    dm.RegisterAsset("tiles.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("icons_ui.png", dm.TextureAssetDescriptor{})
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
    MaemiCharacter.collisionOffset = {0, 0.5}
    MaemiCharacter.collisionRadius = 0.2

    gameState.boss.sequence = aaaa

    // Player
    LoadLevel(gameState)
    GameReset()
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState := transmute(^GameState) state

    if gameState.gameStarted {
        GameplayUpdate()
    }
    else {
        UpdateMenu(&gameState.menu)
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

    if gameState.gameStarted {
        GameplayRender()
    }
    else {
        DrawMenu(&gameState.menu)
    }
}


/////////////////

GameReset :: proc() {
    gameState.playerHP = 3
    gameState.player.position = {-1, -1}
    gameState.player.character = MaemiCharacter
    gameState.player.wallCollisionSize = {1, 0.2}

    // Boss
    gameState.boss.position = {2, 1}
    gameState.boss.hp = BOSS_HP
    gameState.boss.isAlive = true

    clear(&gameState.bullets)
}

GameplayUpdate :: proc() {
    ControlPlayer(&gameState.player)

    for &bullet in gameState.bullets {
        UpdateBullet(&bullet)
    }

    // Player bullets
    bossBounds := dm.CreateBounds(gameState.boss.position, BOSS_COLL_SIZE)
    #reverse for bullet, i in gameState.bullets {
        for wall in gameState.level.walls {
            if dm.CheckCollisionBoundsCircle(wall.bounds, bullet.position, bullet.radius) {
                unordered_remove(&gameState.bullets, i)
                break
            }
        }

        if bullet.isPlayerBullet && gameState.boss.isAlive {
            if dm.CheckCollisionBoundsCircle(bossBounds, bullet.position, bullet.radius) {
                unordered_remove(&gameState.bullets, i)

                gameState.boss.hp -= 20
                if gameState.boss.hp <= 0 {
                    gameState.boss.isAlive = false
                }

                break
            }
        }

        if bullet.isPlayerBullet == false {
            if dm.CheckCollisionCircles(
                gameState.player.position + gameState.player.character.collisionOffset, 
                gameState.player.character.collisionRadius, 
                bullet.position, 
                bullet.radius)
            {
                clear(&gameState.bullets)
                gameState.playerHP -= 1
                break
            }
        }
    }

    RunSequence(&gameState.boss, &aaaa)


    // DEBUG
    dm.DrawBox2D(dm.renderCtx, gameState.player.position, gameState.player.wallCollisionSize, false, dm.RED)
    dm.DrawCircle(dm.renderCtx, 
        gameState.player.position + gameState.player.character.collisionOffset,
        gameState.player.character.collisionRadius,
        false,
        dm.GREEN)
    dm.DrawBox2D(dm.renderCtx, gameState.boss.position, BOSS_COLL_SIZE, false, dm.GREEN)

    for wall in gameState.level.walls {
        // dm.DrawBox2D(dm.renderCtx, wall.position, wall.size, false)
        dm.DrawBounds2D(dm.renderCtx, wall.bounds, false)
    }

    for bullet in gameState.bullets {
        dm.DrawCircle(dm.renderCtx, bullet.position, bullet.radius, false)
    }

    if dm.GetKeyState(.R) == .JustPressed {
        GameReset()
    }
}

GameplayRender :: proc() {

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

    // Boss
    boss := &gameState.boss
    if boss.isAlive {
        dm.DrawBlankSprite(boss.position, {1, 2}, dm.RED)
    }

    // Bullets
    for &bullet in gameState.bullets {
        dm.DrawSprite(bullet.sprite, bullet.position, 
            rotation = bullet.rotation, 
            color = dm.BLUE if bullet.isPlayerBullet else dm.RED)
    }


    // UI
    DrawGameUI()

    dm.DrawBlankSprite({0,0}, {0.1, 0.1}, dm.RED)
}