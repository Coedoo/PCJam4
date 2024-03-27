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

    gunOffset: v2,
    gunSprite: dm.Sprite,
    muzzleOffset: v2,

    collisionRadius: f32,
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

    move := v2{horizontal, vertical} * PLAYER_MOVE_SPEED * f32(dm.time.deltaTime)
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

    // shooting
    muzzlePos := gunPos + glsl.normalize(aimDelta) + player.character.muzzleOffset
    if dm.GetMouseButton(.Left) == .JustPressed {
        for i in 0..<3 {
            variation := rand.float32() * 0.2 - 0.1
            SpawnBullet(muzzlePos, angle + variation, gameState.bulletSprites[.Rect], true)
        }
    }

    player.character.gunSprite.flipY = math.abs(angle) > math.PI / 2

    // camera control
    // @NOTE: I'm not sure if I wanted it here

    cameraPos := player.position + aimDelta * 0.3
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

BulletType :: enum {
    Ball,
    Rect,
    Manta,
    Pointy,
}

Bullet :: struct {
    spawnTime: f32,

    position: v2,
    rotation: f32,
    speed: f32,
    angleChange: f32,
    radius: f32,

    sprite: dm.Sprite,

    isPlayerBullet: bool,
}

MaemiCharacter: Character

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
    sprite: dm.Sprite,
    isPlayerBullet: bool,
    radius := f32(0.1),
    speed := f32(10),
    angleChange := f32(0),
)
{
    bullet := Bullet{
        position = position,
        rotation = rotation,
        angleChange = angleChange,
        spawnTime = f32(dm.time.gameTime),

        sprite = sprite,

        radius = radius,
        speed = speed,

        isPlayerBullet = isPlayerBullet
    }

    append(&gameState.bullets, bullet)
}
