package main

import d3d11 "vendor:directx/d3d11"
import dxgi "vendor:directx/dxgi"
import d3d "vendor:directx/d3d_compiler"

import sdl "vendor:sdl2"

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

import "core:dynlib"

import math "core:math/linalg/glsl"

import mem "core:mem/virtual"

import dm "../dmcore"

import "core:image/png"

window: ^sdl.Window

engineData: dm.Platform

SetWindowSize :: proc(width, height: int) {
    engineData.renderCtx.frameSize.x = i32(width)
    engineData.renderCtx.frameSize.y = i32(height)

    oldSize: dm.iv2
    sdl.GetWindowSize(window, &oldSize.x, &oldSize.y)

    delta := dm.iv2{i32(width), i32(height)} - oldSize
    delta /= 2

    pos: dm.iv2
    sdl.GetWindowPosition(window, &pos.x, &pos.y)
    sdl.SetWindowPosition(window, pos.x - delta.x, pos.y - delta.y)

    sdl.SetWindowSize(window, i32(width), i32(height))
    dm.ResizeFrambuffer(engineData.renderCtx, width, height)
}

defaultWindowWidth  :: 800
defaultWindowHeight :: 600

main :: proc() {
    sdl.Init({.VIDEO, .AUDIO})
    defer sdl.Quit()

    sdl.SetHintWithPriority(sdl.HINT_RENDER_DRIVER, "direct3d11", .OVERRIDE)

    window = sdl.CreateWindow("DanMofu", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, 
                               defaultWindowWidth, defaultWindowHeight,
                               {.ALLOW_HIGHDPI, .HIDDEN})

    defer sdl.DestroyWindow(window);

    engineData.SetWindowSize = SetWindowSize

    engineData.renderCtx = dm.CreateRenderContext(window)
    engineData.renderCtx.frameSize = {defaultWindowWidth, defaultWindowHeight}

    engineData.mui = dm.muiInit(engineData.renderCtx)

    dm.InitAudio(&engineData.audio)

    dm.TimeInit(&engineData)

    gameCode: GameCode
    if LoadGameCode(&gameCode, "Game.dll") == false {
        return
    }

    gameCode.setStatePointers(&engineData)

    // Assets loading!
    if gameCode.preGameLoad != nil {
        gameCode.preGameLoad(&engineData.assets)

        for name, asset in &engineData.assets.assetsMap {
            if asset.descriptor == nil {
                fmt.eprintln("Incorrect asset descriptor for asset:", name)
                continue
            }

            path := strings.concatenate({dm.ASSETS_ROOT, name}, context.temp_allocator)
            fmt.println("Loading asset at path:", path)
            // data, ok := os.read_entire_file(path, context.temp_allocator)

            // if ok == false {
            //     fmt.eprintln("Failed to load asset file at path:", path)
            //     continue
            // }


            switch desc in asset.descriptor {
            case dm.TextureAssetDescriptor:
                asset.handle = cast(dm.Handle) dm.LoadTextureFromFileCtx(engineData.renderCtx, path, desc.filter)
                writeTime, err := os.last_write_time_by_name(path)
                if err == os.ERROR_NONE {
                    asset.lastWriteTime = writeTime
                }

            case dm.ShaderAssetDescriptor:
                data, ok := os.read_entire_file(path, context.temp_allocator)
                str := strings.string_from_ptr(raw_data(data), len(data))
                asset.handle = cast(dm.Handle) dm.CompileShaderSource(engineData.renderCtx, str)

            case dm.FontAssetDescriptor:
                panic("FIX SUPPORT OF FONT ASSET LOADING")

            case dm.SoundAssetDescriptor:
                asset.handle = cast(dm.Handle) dm.LoadSound(path)

            case dm.RawFileAssetDescriptor:
                data, ok := os.read_entire_file(path)
                if ok {
                    asset.fileData = data
                }
            }
        }
    }

    gameCode.gameLoad(&engineData)

    sdl.ShowWindow(window)

    for shouldClose := false; !shouldClose; {
        free_all(context.temp_allocator)

        // Game code hot reload
        newTime, err2 := os.last_write_time_by_name("Game.dll")
        if newTime > gameCode.lastWriteTime {
            res := ReloadGameCode(&gameCode, "Game.dll")
            // gameCode.gameLoad(&engineData)
            if res {
                gameCode.setStatePointers(&engineData)
            }
        }

        // Assets Hot Reload
        for name, asset in &engineData.assets.assetsMap {
            switch desc in asset.descriptor {
            case dm.FontAssetDescriptor, dm.SoundAssetDescriptor:
                continue

            case dm.TextureAssetDescriptor:
                path := strings.concatenate({dm.ASSETS_ROOT, name}, context.temp_allocator)
                newTime, err := os.last_write_time_by_name(path)
                if err == os.ERROR_NONE && newTime > asset.lastWriteTime {
                    data, ok := os.read_entire_file(path, context.temp_allocator)
                    if ok {
                        image, pngErr := png.load_from_bytes(data, allocator = context.temp_allocator)
                        if pngErr == nil {
                            tex := dm.GetTextureCtx(engineData.renderCtx, auto_cast asset.handle)
                            dm._ReleaseTexture(tex)
                            dm._InitTexture(engineData.renderCtx, tex, image.pixels.buf[:], image.width, image.height, image.channels, desc.filter)

                            asset.lastWriteTime = newTime
                        }
                    }
                }

            case dm.ShaderAssetDescriptor:
            case dm.RawFileAssetDescriptor: // @TODO: I'm not sure how to handle that, or even if I should?
            }

        }

        // !!!!!
        using engineData
        // !!!!!

        // Frame Begin
        dm.TimeUpdate(&engineData)

        // Input
        for key, state in input.curr {
            input.prev[key] = state
        }

        for mouseBtn, i in input.mouseCurr {
            input.mousePrev[i] = input.mouseCurr[i]
        }

        input.runesCount = 0
        input.scrollX = 0;
        input.scroll = 0;

        for e: sdl.Event; sdl.PollEvent(&e); {
            #partial switch e.type {

            case .QUIT:
                shouldClose = true

            case .KEYDOWN: 
                key := SDLKeyToKey[e.key.keysym.scancode]

                // if key == .Esc {
                //     shouldClose = true
                // }

                input.curr[key] = .Down

            case .KEYUP:
                key := SDLKeyToKey[e.key.keysym.scancode]
                input.curr[key] = .Up

            case .MOUSEMOTION:
                input.mousePos.x = e.motion.x
                input.mousePos.y = e.motion.y

                input.mouseDelta.x = e.motion.xrel
                input.mouseDelta.y = e.motion.yrel

                // fmt.println("mousePos: ", input.mousePos)

            case .MOUSEWHEEL:
                input.scroll  = int(e.wheel.y)
                input.scrollX = int(e.wheel.x)

            case .MOUSEBUTTONDOWN:
                btnIndex := e.button.button
                btnIndex = clamp(btnIndex, 0, len(SDLMouseToButton) - 1)

                input.mouseCurr[SDLMouseToButton[btnIndex]] = .Down

            case .MOUSEBUTTONUP:
                btnIndex := e.button.button
                btnIndex = clamp(btnIndex, 0, len(SDLMouseToButton) - 1)

                input.mouseCurr[SDLMouseToButton[btnIndex]] = .Up

            case .TEXTINPUT:
                // @TODO: I'm not sure here, I should probably scan entire buffer
                r, i := utf8.decode_rune(e.text.text[:])
                input.runesBuffer[input.runesCount] = r
                input.runesCount += 1
            }
        }

        dm.muiProcessInput(engineData.mui, &input)
        dm.muiBegin(engineData.mui)

        when ODIN_DEBUG {
            if dm.GetKeyStateCtx(&input, .U) == .JustPressed {
                debugState = !debugState
                pauseGame = debugState

                if debugState {
                    dm.muiShowWindow(mui, "Debug")
                }
            }

            if debugState && dm.muiBeginWindow(mui, "Debug", {0, 0, 100, 240}, nil) {

                dm.muiLabel(mui, "Unscalled Time:", time.unscalledTime)
                dm.muiLabel(mui, "GameTime:", time.gameTime)
                dm.muiLabel(mui, "GameDuration:", time.gameDuration)

                dm.muiLabel(mui, "Frame:", time.frame)
                dm.muiLabel(mui, "FPS:", 1 / time.deltaTime)
                dm.muiLabel(mui, "Frame Time:", time.deltaTime * 1000)

                if dm.muiButton(mui, "Play" if pauseGame else "Pause") {
                    pauseGame = !pauseGame
                }

                if dm.muiButton(mui, ">") {
                    moveOneFrame = true
                }

                dm.muiEndWindow(mui)
            }
        }

        if gameCode.lib != nil {
            if pauseGame == false || moveOneFrame {
                gameCode.gameUpdate(gameState)
            }

            when ODIN_DEBUG {
                if gameCode.gameUpdateDebug != nil {
                    gameCode.gameUpdateDebug(gameState, debugState)
                }
            }

            gameCode.gameRender(gameState)
        }

        // dm.test_window(mui)

        dm.FlushCommands(cast(^dm.RenderContext_d3d) renderCtx)
        dm.DrawPrimitiveBatch(&renderCtx.debugBatch, cast(^dm.RenderContext_d3d) renderCtx)
        dm.DrawPrimitiveBatch(&renderCtx.debugBatchScreen, cast(^dm.RenderContext_d3d) renderCtx)

        dm.muiEnd(engineData.mui)
        dm.muiRender(engineData.mui, renderCtx)

        dm.EndFrame(cast(^dm.RenderContext_d3d) renderCtx)
    }
}