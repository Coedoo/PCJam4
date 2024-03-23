package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "../ldtk"


Tile :: struct {
    sprite: dm.Sprite,
    position: v2,
}

Wall :: struct {
    using tile: Tile,
    // size: v2,
    bounds: dm.Bounds2D,
}

Level :: struct {
    tiles: []Tile,
    walls: []Wall,
}

LoadLevel :: proc(gameState: ^GameState) {
    tilesHandle := dm.GetTextureAsset("tiles.png")
    levelAsset := dm.GetAssetData("level.ldtk")
    defer dm.ReleaseAssetData("level.ldtk")

    project, ok := ldtk.load_from_memory(levelAsset.fileData).?

    if ok == false {
        fmt.eprintln("Failed to load level file")
        return
    }

    for level in project.levels {
        levelPxSize := iv2{i32(level.px_width), i32(level.px_height)}
        levelSize := dm.ToV2(levelPxSize) / 32
        centerOffset := levelSize / 2 - {0.5, 0.5}

        for layer in level.layer_instances {
            yOffset := layer.c_height * layer.grid_size

            if layer.identifier == "Tiles" {
                tiles := layer.type == .Tiles ? layer.grid_tiles : layer.auto_layer_tiles
                gameState.level.tiles = make([]Tile, len(tiles))

                for tile, i in tiles {
                    posX := f32(tile.px.x) / f32(layer.grid_size)
                    posY := f32(-tile.px.y + yOffset) / f32(layer.grid_size)

                    sprite := dm.CreateSprite(tilesHandle, {i32(tile.src.x), i32(tile.src.y), 32, 32})
                    gameState.level.tiles[i] = Tile {
                        sprite = sprite,
                        position = v2{posX, posY} - centerOffset
                    }
                }
            }
            else if layer.identifier == "Walls" {
                // @CopyPaste
                tiles := layer.type == .Tiles ? layer.grid_tiles : layer.auto_layer_tiles
                gameState.level.walls = make([]Wall, len(tiles))

                for tile, i in tiles {
                    posX := f32(tile.px.x) / f32(layer.grid_size)
                    posY := f32(-tile.px.y + yOffset) / f32(layer.grid_size)

                    sprite := dm.CreateSprite(tilesHandle, {i32(tile.src.x), i32(tile.src.y), 32, 32})
                    gameState.level.walls[i] = Wall {
                        sprite = sprite,
                        position = v2{posX, posY} - centerOffset,
                        // size = {1, 1},
                        bounds = dm.CreateBounds(v2{posX, posY} - centerOffset, {1, 1})
                    }
                }
            }
        }
    }

}