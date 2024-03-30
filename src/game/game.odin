package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"

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

    levelTimer: f32,
    level: Level,

    bossSprite: dm.Sprite,
    boss: Boss,

    levelEndFadeTimer: f32,

    bulletSprites: [BulletType]dm.Sprite,

    bulletDestroyParticles: dm.ParticleSystem,

    icons: dm.TexHandle,

    arrowSprite: dm.Sprite,

    // audio
    // menuMusic: dm.SoundHandle,
    gameMusic: dm.SoundHandle,
    // shotgun: dm.SoundHandle,
    hitSound: dm.SoundHandle,

    ///
    kekTexture: dm.TexHandle,
    pleadTexture: dm.TexHandle,
}

///////
MaemiAsset :: #load("../../assets/maemi.png")
MaemiPortraitAsset :: #load("../../assets/maemi_portrait.png")
FismanAsset :: #load("../../assets/Fishman.png")
GunsAsset :: #load("../../assets/guns.png")
BulletsAsset :: #load("../../assets/bullets.png")
TilesAsset :: #load("../../assets/tiles.png")
IconsAsset :: #load("../../assets/icons_ui.png")
LevelAsset :: #load("../../assets/level.ldtk")

KekAsset :: #load("../../assets/theoKek.png")
PleadAsset :: #load("../../assets/plead.png")

// ShotgunAsset := #load("../../assets/shotgun.mp3")
GameMusicAsset :: #load("../../assets/Attempt_2.mp3")
HitSoundAsset :: #load("../../assets/hit.wav")
//////

gameState: ^GameState

@export
PreGameLoad : dm.PreGameLoad : proc(assets: ^dm.Assets) {
    // dm.RegisterAsset("maemi.png",          dm.TextureAssetDescriptor{})
    // dm.RegisterAsset("maemi_portrait.png", dm.TextureAssetDescriptor{})

    // dm.RegisterAsset("Fishman.png", dm.TextureAssetDescriptor{})

    // dm.RegisterAsset("gunsssss.png",     dm.TextureAssetDescriptor{})
    // dm.RegisterAsset("bullets.png",  dm.TextureAssetDescriptor{})
    // dm.RegisterAsset("tiles.png",    dm.TextureAssetDescriptor{})
    // dm.RegisterAsset("icons_ui.png", dm.TextureAssetDescriptor{})
    // dm.RegisterAsset("level.ldtk",   dm.RawFileAssetDescriptor{})

    // dm.RegisterAsset("shotgun.mp3", dm.SoundAssetDescriptor{})
    // dm.RegisterAsset("Attempt_2.mp3", dm.SoundAssetDescriptor{})
    // dm.RegisterAsset("Something.mp3", dm.SoundAssetDescriptor{})

}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)

    gameState.camera = dm.CreateCamera(4.8, 8./6.)

    // Characters
    // maemiSprite := dm.GetTextureAsset("maemi.png")
    MaemiCharacter: Character
    maemiSprite := dm.LoadTextureFromMemory(MaemiAsset)
    MaemiCharacter.idleSprites[.South] = dm.CreateSprite(maemiSprite, {0, 1, 32, 48}, origin = {0.5, 1}, frames = 5)
    MaemiCharacter.idleSprites[.East]  = dm.CreateSprite(maemiSprite, {0, 1, 32, 48}, origin = {0.5, 1}, frames = 5)
    MaemiCharacter.idleSprites[.North] = dm.CreateSprite(maemiSprite, {0, 1, 32, 48}, origin = {0.5, 1}, frames = 5)
    MaemiCharacter.idleSprites[.West]  = dm.CreateSprite(maemiSprite, {0, 1, 32, 48}, origin = {0.5, 1}, frames = 5)
    
    MaemiCharacter.idleSprites[.West].flipX = true
    // MaemiCharacter.idleSprites[.North].tint = dm.GREEN
    // MaemiCharacter.idleSprites[.West].tint  = dm.BLUE

    // MaemiCharacter.portrait = dm.GetTextureAsset("maemi_portrait.png")
    MaemiCharacter.portrait = dm.LoadTextureFromMemory(MaemiPortraitAsset)

    // guns := dm.GetTextureAsset("gunsssss.png")
    guns := dm.LoadTextureFromMemory(GunsAsset)
    MaemiCharacter.gunSprite = dm.CreateSprite(guns, {0, 0, 32, 16}, origin = {0.3, 0.6})
    MaemiCharacter.gunOffset = {-0.1, 0.4}
    MaemiCharacter.muzzleOffset = {-0.25, 0}
    MaemiCharacter.collisionOffset = {0, 0.5}
    // MaemiCharacter.collisionRadius = 0.2

    // MaemiCharacter.weapon = Shotgun {
    //     dmg = 10,
    //     bullet = .Rect,
    //     bulletSize = 0.15,
    //     bulletSpeed = 16,
    //     bulletsCount = 5,
    //     angleVariation = 20,
    // }

    MaemiCharacter.weapon = Rifle {
        dmg = 8,
        bullet = .Rect,
        bulletSize = 0.15,
        bulletSpeed = 25,

        timeBetweenBullets = 0.1,
    }

    gameState.player.character = MaemiCharacter

    // bullets := dm.GetTextureAsset("bullets.png")
    bullets := dm.LoadTextureFromMemory(BulletsAsset)
    gameState.bulletSprites[.Ball]   = dm.CreateSprite(bullets, {16 * 0, 0, 16, 16})
    gameState.bulletSprites[.Rect]   = dm.CreateSprite(bullets, {16 * 1, 0, 16, 16})
    gameState.bulletSprites[.Manta]  = dm.CreateSprite(bullets, {16 * 2, 0, 16, 16})
    gameState.bulletSprites[.Pointy] = dm.CreateSprite(bullets, {16 * 3, 0, 16, 16})

    // Paritcle System
    particles := dm.DefaultParticleSystem
    particles.emitRate = 0
    // particles.maxParticles = 100
    particles.texture = dm.renderCtx.whiteTexture
    particles.size = dm.FloatOverLifetime{1, 0, .Quadratic_In}
    particles.startSize = dm.RandomFloat{0.3, .8}
    dm.InitParticleSystem(&particles)
    gameState.bulletDestroyParticles = particles

    // bossTex := dm.GetTextureAsset("Fishman.png")
    bossTex := dm.LoadTextureFromMemory(FismanAsset)
    gameState.bossSprite = dm.CreateSprite(bossTex, {0, 0, 32, 64})
    gameState.boss.currentSeqIdx = 0

    // gameState.gameMusic = cast(dm.SoundHandle) dm.GetAsset("Attempt_2.mp3")

    // gameState.menuMusic = cast(dm.SoundHandle) dm.GetAsset("Something.mp3")
    // dm.SetLooping(gameState.menuMusic, true)

    gameState.icons = dm.LoadTextureFromMemory(IconsAsset)

    gameState.arrowSprite = dm.CreateSprite(gameState.icons, {16, 0, 16, 16})
    gameState.arrowSprite.origin = {.5, 0}

    gameState.gameMusic = dm.LoadSoundFromMemory(GameMusicAsset)
    dm.SetLooping(gameState.gameMusic, true)
    dm.SetVolume(gameState.gameMusic, 0.5)

    gameState.hitSound = dm.LoadSoundFromMemory(HitSoundAsset)
    dm.SetVolume(gameState.hitSound, 0.2)

    // gameState.shotgun = dm.LoadSoundFromMemory(ShotgunAsset)
    // dm.SetLooping(gameState.gameMusic, true)
    // dm.SetVolume(gameState.shotgun, 0.5)

    gameState.kekTexture = dm.LoadTextureFromMemory(KekAsset)
    gameState.pleadTexture = dm.LoadTextureFromMemory(PleadAsset)

    LoadLevel(gameState)
    GameReset(.Menu)
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    switch gameState.gameStage {
    case .Menu:     UpdateMenu(&gameState.menu)
    case .Gameplay: GameplayUpdate()
    case .Lost:     UpdateGameLost(&gameState.menu)
    case .Won:      UpdateGameWon(&gameState.menu)
    }

}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr, debug: bool) {
    gameState = cast(^GameState) state

    if dm.platform.debugState {
        dm.DrawBox2D(dm.renderCtx, gameState.player.position, gameState.player.wallCollisionSize, false, dm.RED)
        dm.DrawCircle(dm.renderCtx, 
            gameState.player.position + gameState.player.character.collisionOffset,
            PLAYER_COLL_RADIUS,
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
    dm.ClearColor(BACK_COLOR)

    switch gameState.gameStage {
    case .Gameplay: GameplayRender()
    case .Menu: DrawMenu()
    case .Won: DrawGameWon()
    case .Lost: DrawGameLost()
    }
}


/////////////////

GameReset :: proc(toStage: GameStage) {
    gameState.playerHP = PLAYER_HP
    gameState.player.position = {0, -5}
    // gameState.player.character = MaemiCharacter
    gameState.player.wallCollisionSize = {1, 0.2}
    gameState.player.noHurtyTimer = NOHURTY_TIME

    // Boss
    gameState.boss.position = {0, 0}
    gameState.boss.isAlive = true

    gameState.boss.waitingTimer = PRE_SEQUENCE_WAIT
    gameState.boss.currentSeqIdx = 0
    // gameState.boss.currentSeqIdx = 2

    gameState.boss.hp = BossSequence[gameState.boss.currentSeqIdx].hp

    gameState.levelTimer = 0

    gameState.gameStage = toStage

    clear(&gameState.bullets)

    ResetBossSequence(&gameState.boss)

    if toStage == .Gameplay {
        // dm.StopSound(gameState.menuMusic)
        dm.PlaySound(gameState.gameMusic)
    }
    else if toStage == .Menu {
        // dm.PlaySound(gameState.menuMusic)
        // dm.StopSound(gameState.gameMusic)
    }
}

DestroyBullets :: proc() {
    for p in gameState.bullets {
        color := BulletColors[p.type]
        dm.SpawnParticles(&gameState.bulletDestroyParticles, 6, p.position, color)
    }

    clear(&gameState.bullets)
}

GameplayUpdate :: proc() {
    gameState.levelTimer += f32(dm.time.deltaTime)

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

                dmg := GetDMG(gameState.player.character.weapon)
                gameState.boss.hp -= f32(dmg)

                dm.PlaySound(gameState.hitSound)

                if gameState.boss.hp <= 0 {
                    if BossNextSequence(&gameState.boss) == false {
                        gameState.levelEndFadeTimer = END_GAME_FADE_TIME
                    }

                    DestroyBullets()

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
                PLAYER_COLL_RADIUS, 
                bullet.position, 
                bullet.radius)
            {
                DestroyBullets()

                // clear(&gameState.bullets)
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
            if gameState.playerHP == 0 {
                gameState.gameStage = .Lost
            }
            else {
                gameState.gameStage = .Won
            }
        }
    }

    dm.UpdateParticleSystem(&gameState.bulletDestroyParticles, f32(dm.time.deltaTime))
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

        isWalking := dm.GetMouseButton(.Right) == .Down
        if isWalking {
            heartSprite := dm.CreateSprite(gameState.icons, {1, 1, 15, 15})
            heartSprite.scale = PLAYER_COLL_RADIUS * 2
            pos := player.position + player.character.collisionOffset
            dm.DrawSprite(heartSprite, pos)
        }
    }

    // Boss
    boss := &gameState.boss
    if boss.isAlive {
        dm.DrawSprite(gameState.bossSprite, boss.position)
    }


    // Bullets
    for &bullet in gameState.bullets {
        sprite := bullet.sprite
        sprite.scale = bullet.radius * 2 + 0.2
        dm.DrawSprite(sprite, bullet.position, 
            rotation = bullet.rotation - math.PI / 2)
    }

    // Particles
    dm.DrawParticleSystem(dm.renderCtx, &gameState.bulletDestroyParticles)

    // UI
    DrawGameUI()

    // Arrow
    cBounds := dm.GetCameraBounds(gameState.camera)
    if dm.IsInBounds(cBounds, gameState.boss.position) == false {
        toBoss := PlayerPos() - gameState.boss.position
        angle := math.atan2(toBoss.y, toBoss.x) + math.PI / 2

        // pos := PlayerPos() - glsl.normalize(toBoss)
        pos := gameState.boss.position
        pos.x = math.clamp(pos.x, cBounds.left, cBounds.right)
        pos.y = math.clamp(pos.y, cBounds.bot, cBounds.top)
        dm.DrawSprite(gameState.arrowSprite, pos, rotation = angle)
    }

    if gameState.playerHP == 0 ||
       gameState.boss.isAlive == false
    {
        alpha := 1 - gameState.levelEndFadeTimer / END_GAME_FADE_TIME
        color := BACK_COLOR
        color.a = alpha
        dm.DrawRectBlank({0, 0}, dm.ToV2(dm.renderCtx.frameSize), origin = {0, 0}, color = color)
    }
}