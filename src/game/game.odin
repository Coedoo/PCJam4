package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "../ldtk"

v2 :: dm.v2
iv2 :: dm.iv2

GameStage :: enum {
    Menu,
    Gameplay,
    Won,
    Lost,
}

GameState :: struct {
    gameStage: GameStage,

    menu: Menu,

    camera: dm.Camera,

    player: Player,
    playerHP: int,

    bullets: [dynamic]Bullet,

    level: Level,

    boss: Boss,

    levelEndFadeTimer: f32,
}

gameState: ^GameState

@export
PreGameLoad : dm.PreGameLoad : proc(assets: ^dm.Assets) {
    dm.RegisterAsset("maemi.png", dm.TextureAssetDescriptor {})
    dm.RegisterAsset("maemi_portrait.png", dm.TextureAssetDescriptor {})

    dm.RegisterAsset("guns.png", dm.TextureAssetDescriptor {})
    dm.RegisterAsset("tiles.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("icons_ui.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("level.ldtk", dm.RawFileAssetDescriptor{})
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)

    gameState.camera = dm.CreateCamera(4.8, 8./6.)

    // Characters
    maemiSprite := dm.GetTextureAsset("maemi.png")
    MaemiCharacter.idleSprites[.South] = dm.CreateSprite(maemiSprite, {0, 1, 32, 48}, origin = {0.5, 1}, frames = 5)
    MaemiCharacter.idleSprites[.East]  = dm.CreateSprite(maemiSprite, {0, 1, 32, 48}, origin = {0.5, 1}, frames = 5)
    MaemiCharacter.idleSprites[.North] = dm.CreateSprite(maemiSprite, {0, 1, 32, 48}, origin = {0.5, 1}, frames = 5)
    MaemiCharacter.idleSprites[.West]  = dm.CreateSprite(maemiSprite, {0, 1, 32, 48}, origin = {0.5, 1}, frames = 5)
    
    MaemiCharacter.idleSprites[.West].flipX = true
    // MaemiCharacter.idleSprites[.North].tint = dm.GREEN
    // MaemiCharacter.idleSprites[.West].tint  = dm.BLUE

    MaemiCharacter.portrait = dm.GetTextureAsset("maemi_portrait.png")

    guns := dm.GetTextureAsset("guns.png")
    MaemiCharacter.gunSprite = dm.CreateSprite(guns, {0, 0, 32, 16}, origin = {0.3, 0.6})
    MaemiCharacter.gunOffset = {-0.1, 0.4}
    MaemiCharacter.muzzleOffset = {-0.25, -0.2}
    MaemiCharacter.collisionOffset = {0, 0.5}
    MaemiCharacter.collisionRadius = 0.2

    // Player
    LoadLevel(gameState)
    GameReset(.Gameplay)
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState := transmute(^GameState) state

    switch gameState.gameStage {
    case .Menu:     UpdateMenu(&gameState.menu)
    case .Gameplay: GameplayUpdate()
    case .Lost:     UpdateGameLost(&gameState.menu)
    case .Won:      UpdateGameWon(&gameState.menu)
    }

}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr, debug: bool) {
    if dm.platform.debugState {
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
            GameReset(.Gameplay)
        }

        dm.muiBeginWindow(dm.mui, "Cheats", {200, 20, 150, 200}, {})

        dm.muiToggle(dm.mui, "God Mode", &god_mode)

        dm.muiEndWindow(dm.mui)
    }
}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    gameState = cast(^GameState) state

    dm.SetCamera(gameState.camera)
    dm.ClearColor({0.1, 0.2, 0.4, 1})

    switch gameState.gameStage {
    case .Gameplay: GameplayRender()
    case .Menu: DrawMenu()
    case .Lost: DrawGameWon() 
    case .Won: DrawGameLost()
    }

}


/////////////////

GameReset :: proc(toStage: GameStage) {
    gameState.playerHP = 3
    gameState.player.position = {-1, -1}
    gameState.player.character = MaemiCharacter
    gameState.player.wallCollisionSize = {1, 0.2}
    gameState.player.noHurtyTimer = NOHURTY_TIME

    // Boss
    gameState.boss.position = {2, 1}
    gameState.boss.hp = BOSS_HP
    gameState.boss.isAlive = true

    gameState.boss.waitingTimer = PRE_SEQUENCE_WAIT
    gameState.boss.currentSeqIdx = 0
    gameState.boss.sequences = testSeq

    gameState.gameStage = toStage

    ResetBossSequence(&gameState.boss)

    clear(&gameState.bullets)
}

GameplayUpdate :: proc() {
    if gameState.playerHP > 0 {
        ControlPlayer(&gameState.player)

        gameState.player.noHurtyTimer -= f32(dm.time.deltaTime)
        gameState.player.noHurtyTimer = max(0, gameState.player.noHurtyTimer)
    }

    if gameState.boss.isAlive {
        UpdateBoss(&gameState.boss)
    }

    bossBounds := dm.CreateBounds(gameState.boss.position, BOSS_COLL_SIZE)
    #reverse for &bullet, i in gameState.bullets {
        UpdateBullet(&bullet)

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
                    // gameState.boss.isAlive = false
                    clear(&gameState.bullets)
                    if BossNextSequence(&gameState.boss) == false {
                        gameState.levelEndFadeTimer = END_GAME_FADE_TIME
                    }

                    break
                }
            }
        }

        if bullet.isPlayerBullet == false && 
           gameState.player.noHurtyTimer == 0 &&
           gameState.playerHP > 0 &&
           god_mode == false
        {
            if dm.CheckCollisionCircles(
                gameState.player.position + gameState.player.character.collisionOffset, 
                gameState.player.character.collisionRadius, 
                bullet.position, 
                bullet.radius)
            {
                clear(&gameState.bullets)
                gameState.playerHP -= 1

                gameState.player.noHurtyTimer = NOHURTY_TIME

                ResetBossSequence(&gameState.boss)

                if gameState.playerHP == 0 {
                    gameState.levelEndFadeTimer = END_GAME_FADE_TIME
                }

                break
            }
        }
    }

    if gameState.playerHP == 0 ||
       gameState.boss.isAlive == false
    {
        gameState.levelEndFadeTimer -= f32(dm.time.deltaTime)
        if gameState.levelEndFadeTimer <= 0 {
            gameState.gameStage = .Won if gameState.boss.isAlive == false else .Lost
        }
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
    if gameState.playerHP > 0 {
        player := &gameState.player
        character := &player.character
        playerSprite := &character.idleSprites[player.heading]

        dm.AnimateSprite(playerSprite, f32(dm.time.gameTime), 0.12)
        dm.DrawSprite(playerSprite^, player.position,
            color = {1, 1, 1, dm.CosRange(.5, 1, 10 * gameState.player.noHurtyTimer)},
        )

        dm.DrawSprite(character.gunSprite, player.position + character.gunOffset, 
            rotation = player.gunRotation,
        )
    }

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

    if gameState.playerHP == 0 ||
       gameState.boss.isAlive == false
    {
        alpha := 1 - gameState.levelEndFadeTimer / END_GAME_FADE_TIME
        dm.DrawRectBlank({0, 0}, dm.ToV2(dm.renderCtx.frameSize), origin = {0, 0}, color = {0, 0, 0, alpha})
    }
}