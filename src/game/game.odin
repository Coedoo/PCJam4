package game

import dm "../dmcore"
import "core:math"
import "core:math/linalg/glsl"
import "core:fmt"

v2 :: dm.v2
iv2 :: dm.iv2

GameState :: struct {
    camera: dm.Camera,

    player: Player,
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
}


@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)

    gameState.camera = dm.CreateCamera(5, 8./6.)

    gameState.player.sprite = dm.CreateSprite(platform.renderCtx.whiteTexture, {0, 0, 1, 1})
    gameState.player.gunSprite = dm.CreateSprite(platform.renderCtx.whiteTexture, {0, 0, 1, 1})
    gameState.player.gunSprite.origin = {0, 0.5}

}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState := transmute(^GameState) state

    ControlPlayer(&gameState.player)
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
    dm.DrawSprite(gameState.player.gunSprite, gameState.player.position, 
        rotation = gameState.player.gunRotation, 
        color = dm.RED
    )
}