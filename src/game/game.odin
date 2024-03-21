package game

import dm "../dmcore"
import "core:math"
import "core:math/linalg/glsl"
import "core:fmt"

v2 :: dm.v2
iv2 :: dm.iv2

GameState :: struct {
    camera: dm.Camera,
}

gameState: ^GameState

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    dm.AlocateGameData(platform, GameState)
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    
}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr, debug: bool) {
}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    gameState = cast(^GameState) state

    dm.SetCamera(gameState.camera)
    dm.ClearColor({0.4, 0.5, 0.8, 1})

    dm.DrawTextCentered(dm.renderCtx, "Hello Game", dm.LoadDefaultFont(dm.renderCtx), {400, 300})
}