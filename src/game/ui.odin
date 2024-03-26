package game

import dm "../dmcore"
import "core:fmt"

DrawGameUI :: proc() {
    font := dm.LoadDefaultFont(dm.renderCtx)
    icons := dm.GetTextureAsset("icons_ui.png")

    dm.DrawText(dm.renderCtx, "HP: ", font, {10, 0})
    textSize := dm.MeasureText("HP: ", font)
    for i in 0..<gameState.playerHP {
        posX := textSize.x + f32(i) * 32 + 3
        posY := textSize.y / 2 + 5
        dm.DrawRectSrcDst(icons, {1, 1, 15, 15}, {posX, posY, 32, 32}, dm.renderCtx.defaultShaders[.ScreenSpaceRect])
    }


    frameSize := dm.ToV2(dm.renderCtx.frameSize)
    bossHPBarSize := v2{frameSize.x * gameState.boss.hp / BOSS_HP, 20}
    hpBarPos := v2{0, f32(dm.renderCtx.frameSize.y) - bossHPBarSize.y}

    phasesLeft := len(gameState.boss.sequences) - gameState.boss.currentSeqIdx
    for i in 0..<phasesLeft {
        pos := hpBarPos + {f32(i) * 21, -21}
        dm.DrawRectBlank(pos, {20, 20}, origin = {0, 0}, color = dm.RED)
    }

    dm.DrawRectBlank(hpBarPos, bossHPBarSize, origin = {0, 0}, color = dm.RED)
}

////////////////
// MENU
/////////////

MenuState :: enum {
    Main,
    Controls,
    Credits,

    CharacterSelect,
}

Menu :: struct {
    state: MenuState,

    hotButton: int,
    buttons: [dynamic]string,
}

MenuButton :: proc(menu: ^Menu, str: string) -> bool {
    append(&menu.buttons, str)
    idx := len(menu.buttons) - 1
    return menu.hotButton == idx && dm.GetKeyState(.Return) == .JustPressed
}

SwitchMenuState :: proc(menu: ^Menu, newState: MenuState) {
    menu.state = newState
    menu.hotButton = 0
}

UpdateMenu:: proc(menu: ^Menu) {
    clear(&menu.buttons)

    switch menu.state {
    case .Main:
        if MenuButton(menu, "Start") {
            SwitchMenuState(menu, .CharacterSelect)
            // gameState.gameStage = .Gameplay
            // GameReset(.Gameplay)
        }
        if MenuButton(menu, "Controls") {
            SwitchMenuState(menu, .Controls)
        }
        if MenuButton(menu, "Credits") {
            SwitchMenuState(menu, .Credits)
        }

    case .Controls:
    case .Credits:
    case .CharacterSelect:
        if MenuButton(menu, "Start") {
            GameReset(.Gameplay)
        }
    }

    if menu.state != .Main {
        if MenuButton(menu, "Back") {
            SwitchMenuState(menu, .Main)
        }
    }

    move := dm.GetAxisInt(.W, .S, .JustPressed)

    menu.hotButton += int(move)
    menu.hotButton = clamp(menu.hotButton, 0, len(menu.buttons))
}

DrawMenu :: proc() {
    font := dm.LoadDefaultFont(dm.renderCtx)

    switch gameState.menu.state {
    case .Main:
        DrawMenuButtons(&gameState.menu, {400, 370})
    case .Controls:
        DrawMenuButtons(&gameState.menu, {400, 370})
    case .Credits:
        DrawMenuButtons(&gameState.menu, {400, 370})

    case .CharacterSelect:
        dm.DrawRectPos(gameState.player.character.portrait, {210, 300})

        dm.DrawTextCentered(dm.renderCtx, "Choose your character!", font,
            {400, 40}, 60, dm.BLACK)

        dm.DrawTextCentered(dm.renderCtx, "Tenma Maemi", font,
            {550, 200}, 50)

        DrawMenuButtons(&gameState.menu, {400, 520})
    }
}

DrawMenuButtons :: proc(menu: ^Menu, pos: v2) {
    font := dm.LoadDefaultFont(dm.renderCtx)

    for btn, i in menu.buttons {
        if menu.hotButton == i {
            size := dm.MeasureText(btn, font)
            size += {10, -12}

            dm.DrawRectBlank({0, f32(i) * font.lineHeight} + pos + {0, 3}, size, 
                color = {0, 0, 0, 0.5},
                origin = {0.25, 0.25} // WHY?!?!
            )
        }

        dm.DrawTextCentered(dm.renderCtx, btn, font, {0, f32(i) * font.lineHeight} + pos)
    }
}

////////////

UpdateGameLost :: proc(menu: ^Menu) {
    clear(&menu.buttons)

    if MenuButton(menu, "Lost") {
    }
    if MenuButton(menu, "Restart") {
        GameReset(.Gameplay)
    }
    if MenuButton(menu, "Back to menu") {
        gameState.gameStage = .Menu
        gameState.menu.state = .Main
    }

    move := dm.GetAxisInt(.W, .S, .JustPressed)

    menu.hotButton += int(move)
    menu.hotButton = clamp(menu.hotButton, 0, len(menu.buttons))
}

UpdateGameWon :: proc(menu: ^Menu) {
    clear(&menu.buttons)

    if MenuButton(menu, "WON") {
    }
    if MenuButton(menu, "Restart") {
        GameReset(.Gameplay)
    }
    if MenuButton(menu, "Back to menu") {
        gameState.gameStage = .Menu
        gameState.menu.state = .Main
    }

    move := dm.GetAxisInt(.W, .S, .JustPressed)

    menu.hotButton += int(move)
    menu.hotButton = clamp(menu.hotButton, 0, len(menu.buttons))
}


DrawGameWon :: proc() {
    DrawMenuButtons(&gameState.menu, {400, 520})
}

DrawGameLost :: proc() {
    DrawMenuButtons(&gameState.menu, {400, 520})
}