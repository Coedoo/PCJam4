package game

import dm "../dmcore"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"

Heading :: enum {
    South,
    East,
    North,
    West,
}

Character :: struct {

    idleSprites: [Heading]dm.Sprite,
    runSprites: [Heading]dm.Sprite,

    portrait: dm.TexHandle,

    weapon: WeaponVariant,

    gunOffset: v2,
    gunSprite: dm.Sprite,
    muzzleOffset: v2,

    // collisionRadius: f32,
    collisionOffset: v2,
}

Player :: struct {
    position: v2,
    heading: Heading,
    gunRotation: f32,

    noHurtyTimer: f32,

    wallCollisionSize: v2,

    character: Character,
}

ControlPlayer :: proc(player: ^Player) {
    horizontal := dm.GetAxis(.A, .D)
    vertical := dm.GetAxis(.S, .W)

    isWalking := dm.GetMouseButton(.Right) == .Down
    speed:f32 = isWalking ? PLAYER_WALK_SPEED : PLAYER_MOVE_SPEED

    move := v2{horizontal, vertical} * speed * f32(dm.time.deltaTime)
    for wall in gameState.level.walls {
        // X check
        playerBounds := dm.CreateBounds(player.position + {move.x, 0}, player.wallCollisionSize)
        if dm.CheckCollisionBounds(playerBounds, wall.bounds) {
            delta: f32
            if move.x > 0 {
                delta = playerBounds.right - wall.bounds.left
                move.x -= delta + 0.001
            }
            else {
                delta = wall.bounds.right - playerBounds.left
                move.x += delta + 0.001
            }
        }

        // Y Check
        playerBounds = dm.CreateBounds(player.position + {0, move.y}, player.wallCollisionSize)
        if dm.CheckCollisionBounds(playerBounds, wall.bounds) {
            delta: f32
            if move.y > 0 {
                delta = playerBounds.top - wall.bounds.bot
                move.y -= delta + 0.001
            }
            else {
                delta = wall.bounds.top - playerBounds.bot
                move.y += delta + 0.001
            }

        }
    }

    player.position += move

    // aiming
    mouseWorldPos := dm.ScreenToWorldSpace(gameState.camera, dm.input.mousePos, dm.renderCtx.frameSize)
    mousePos := v2{mouseWorldPos.x, mouseWorldPos.y}

    gunPos := player.position + player.character.gunOffset
    aimDelta := mousePos - gunPos
    angle := math.atan2(aimDelta.y, aimDelta.x)
    player.gunRotation = angle

    rotMat := matrix[2, 2]f32 {
        math.cos(angle), -math.sin(angle),
        math.sin(angle),  math.cos(angle)
    }

    // dm.DrawLine(dm.renderCtx, gunPos, mousePos, false)

    // shooting
    muzzlePos := gunPos + glsl.normalize(aimDelta) + (rotMat * player.character.muzzleOffset)
    ControlWeapon(&player.character.weapon, muzzlePos, angle)
    
    player.character.gunSprite.flipY = math.abs(angle) > math.PI / 2

    // camera control
    // @NOTE: I'm not sure if I wanted it here

    target := player.position + aimDelta * 0.3
    cameraPos := math.lerp(
                    dm.ToV2(gameState.camera.position),
                    target,
                    20 * f32(dm.time.deltaTime
                ))

    gameState.camera.position = {cameraPos.x, cameraPos.y, 1}

    // heading
    pi := f32(math.PI)
    if angle > -pi/4 && angle <= pi/4 {
        player.heading = .East
    }
    else if angle > pi/4 && angle <=  3 * pi/4 {
        player.heading = .North
    }
    else if angle > -3 * pi/4 && angle <= -pi/4 {
        player.heading = .South
    }
    else {
        player.heading = .West
    }
}

//////////////////

// RepeatType :: enum {
//     Auto, Click,
// }

Weapon :: struct {
    dmg: int,
    // repeat: RepeatType,
    bullet: BulletType,
    bulletSize: f32,
    bulletSpeed: f32,
}

Shotgun :: struct {
    using weapon: Weapon,

    bulletsCount: int,
    angleVariation: f32,
}

Rifle :: struct {
    using weapon: Weapon,

    timeBetweenBullets:f32,
    timer:f32,
}

WeaponVariant :: union {
    Shotgun, Rifle,
}

BulletType :: enum {
    Ball,
    Rect,
    Manta,
    Pointy,
}

BulletColors := [BulletType]dm.color {
    .Ball = {1, 0, 0, 1},
    .Rect = {1, 1, 0, 1},
    .Manta = {0, 0, 1, 1},
    .Pointy ={0.3, 0, .8, 1},
}

Bullet :: struct {
    spawnTime: f32,

    position: v2,
    rotation: f32,
    speed: f32,
    angleChange: f32,
    radius: f32,

    type: BulletType,
    sprite: dm.Sprite,

    isPlayerBullet: bool,
}

GetDMG :: proc(weapon: WeaponVariant) -> int {
    switch w in weapon {
        case Shotgun: return w.dmg
        case Rifle: return w.dmg
    }

    return 0
}

UpdateBullet :: proc(bullet: ^Bullet) {
    bullet.rotation += bullet.angleChange * f32(dm.time.deltaTime)
    direction := v2{
        math.cos(bullet.rotation),
        math.sin(bullet.rotation),
    }

    bullet.position += direction * bullet.speed * f32(dm.time.deltaTime)
}

SpawnBullet :: proc(
    position: v2, 
    rotation: f32,
    type: BulletType,
    isPlayerBullet: bool,
    radius := f32(0.2),
    speed := f32(10),
    angleChange := f32(0),
)
{
    bullet := Bullet{
        position = position,
        rotation = rotation,
        angleChange = angleChange,
        spawnTime = f32(dm.time.gameTime),

        type = type,
        sprite = gameState.bulletSprites[type],

        radius = radius,
        speed = speed,

        isPlayerBullet = isPlayerBullet
    }

    append(&gameState.bullets, bullet)
}

ControlWeapon :: proc(weapon: ^WeaponVariant, muzzlePos: v2, aimAngle: f32) {
    switch &w in weapon {
        case Shotgun:
        if dm.GetMouseButton(.Left) == .JustPressed {
            for i in 0..<w.bulletsCount {
                variation := rand.float32() * w.angleVariation - (w.angleVariation / 2)
                SpawnBullet(
                    muzzlePos, 
                    aimAngle + math.to_radians(variation),
                    w.bullet, 
                    true, 
                    radius = w.bulletSize,
                    speed = w.bulletSpeed
                )
            }

            dm.PlaySound(cast(dm.SoundHandle) dm.GetAsset("shotgun.mp3"))
        }

        case Rifle:
        w.timer -= f32(dm.time.deltaTime)

        if dm.GetMouseButton(.Left) == .Down {
            if w.timer > 0 {
                return
            }

            w.timer = w.timeBetweenBullets

            SpawnBullet(
                muzzlePos, 
                aimAngle,
                w.bullet, 
                true, 
                radius = w.bulletSize,
                speed = w.bulletSpeed
            )
        }
    }
}