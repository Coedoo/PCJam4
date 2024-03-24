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
            // SwitchMenuState(menu, .CharacterSelect)
            gameState.gameStarted = true
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
    }

    if MenuButton(menu, "Exit") {
        SwitchMenuState(menu, .Main)
    }

    move := dm.GetAxisInt(.W, .S, .JustPressed)

    menu.hotButton += int(move)
    menu.hotButton = clamp(menu.hotButton, 0, len(menu.buttons))
}

DrawMenu :: proc(menu: ^Menu) {
    font := dm.LoadDefaultFont(dm.renderCtx)
    offset := dm.ToV2(dm.renderCtx.frameSize / 2) + {0, 50}

    for btn, i in menu.buttons {
        if menu.hotButton == i {
            size := dm.MeasureText(btn, font)
            size += {10, -8}

            dm.DrawRectBlank({0, f32(i) * font.lineHeight} + offset, size, 
                color = {0, 0, 0, 0.5},
                origin = {0.25, 0.25} // WHY?!?!
            )
        }

        dm.DrawTextCentered(dm.renderCtx, btn, font, {0, f32(i) * font.lineHeight} + offset)
    }
}