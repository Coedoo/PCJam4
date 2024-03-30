package game

import dm "../dmcore"
import "core:fmt"

DrawGameUI :: proc() {
    font := dm.LoadDefaultFont(dm.renderCtx)
    // icons := dm.GetTextureAsset("icons_ui.png")
    icons := gameState.icons
    frameSize := dm.ToV2(dm.renderCtx.frameSize)

    // timer
    dm.DrawTextCentered(
        dm.renderCtx,
        fmt.tprintf("%.2f", gameState.levelTimer),
        font,
        {frameSize.x / 2, font.lineHeight - 20}
    )

    // HP
    dm.DrawText(dm.renderCtx, "HP: ", font, {10, 0})
    textSize := dm.MeasureText("HP: ", font)
    for i in 0..<gameState.playerHP {
        posX := textSize.x + f32(i) * 32 + 3
        posY := textSize.y / 2 + 5
        dm.DrawRectSrcDst(icons, {1, 1, 15, 15}, {posX, posY, 32, 32}, dm.renderCtx.defaultShaders[.ScreenSpaceRect])
    }

    // Boss HP
    if gameState.boss.isAlive {
        maxHp := BossSequence[gameState.boss.currentSeqIdx].hp
        bossHPBarSize := v2{frameSize.x * gameState.boss.hp / maxHp, 20}
        hpBarPos := v2{0, f32(dm.renderCtx.frameSize.y) - bossHPBarSize.y}

        phasesLeft := len(BossSequence) - gameState.boss.currentSeqIdx
        for i in 0..<phasesLeft {
            pos := hpBarPos + {f32(i) * 21, -21}
            dm.DrawRectBlank(pos, {20, 20}, origin = {0, 0}, color = dm.RED)
        }

        dm.DrawRectBlank(hpBarPos, bossHPBarSize, origin = {0, 0}, color = dm.RED)
    }
}

////////////////
// MENU
/////////////

MenuState :: enum {
    Main,
    Credits,
    Controls,
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
            // gameState.gameStage = .Gameplay
            GameReset(.Gameplay)
        }
        // if MenuButton(menu, "Controls") {
        //     SwitchMenuState(menu, .Controls)
        // }
        if MenuButton(menu, "Credits") {
            SwitchMenuState(menu, .Credits)
        }

        if MenuButton(menu, "Controls") {
            SwitchMenuState(menu, .Controls)
        }

    case .Credits:
    case .Controls:
    // case .Controls:
    // case .CharacterSelect:
    //     if MenuButton(menu, "Start") {
    //         GameReset(.Gameplay)
    //     }
    }

    if menu.state != .Main {
        if MenuButton(menu, "Back") {
            SwitchMenuState(menu, .Main)
        }
    }

    move := dm.GetAxisInt(.W, .S, .JustPressed)
    if move == 0 {
        move = dm.GetAxisInt(.Up, .Down, .JustPressed)
    }

    menu.hotButton += int(move)
    menu.hotButton = clamp(menu.hotButton, 0, len(menu.buttons) - 1)
}

DrawMenu :: proc() {
    font := dm.LoadDefaultFont(dm.renderCtx)

    switch gameState.menu.state {
    case .Main:
        dm.DrawTextCentered(dm.renderCtx,
            "Tenma",
            font,
            {500, 100},
            80
        )

        dm.DrawTextCentered(dm.renderCtx,
            "VS",
            font,
            {560, 180},
            80
        )

        dm.DrawTextCentered(dm.renderCtx,
            "Sakana",
            font,
            {620, 260},
            80
        )

        dm.DrawRectPos(gameState.player.character.portrait, {210, 300})
        DrawMenuButtons(&gameState.menu, {560, 390})
    // case .Controls:
    //     DrawMenuButtons(&gameState.menu, {400, 370})
    case .Credits:
        dm.DrawTextCentered(dm.renderCtx,
            "Character art: Kairo (@kairo0_)\nMusic: FettuccineBroccoli\nStuff: Coedo",
            font,
            {400, 260},
            45
        )

        DrawMenuButtons(&gameState.menu, {400, 500})

    // case .CharacterSelect:
    //     dm.DrawRectPos(gameState.player.character.portrait, {210, 300})

    //     dm.DrawTextCentered(dm.renderCtx, "Choose your character!", font,
    //         {400, 40}, 60, dm.BLACK)

    //     dm.DrawTextCentered(dm.renderCtx, "Tenma Maemi", font,
    //         {550, 200}, 50)

    //     DrawMenuButtons(&gameState.menu, {400, 520})
    case .Controls:
        dm.DrawTextCentered(dm.renderCtx,
            "WSAD - movement\nLeft mouse btn - Shoot\nRight mouse btn - slow move mode",
            font,
            {400, 260},
            45
        )
        DrawMenuButtons(&gameState.menu, {400, 500})
    }

    dm.DrawTextCentered(
        dm.renderCtx,
        "W, S or Arrows - Select. Enter - accept.",
        font,
        {400, 600 - 20},
        20
    )

    dm.DrawTextCentered(
        dm.renderCtx,
        "Made with #NoEngine",
        font,
        {720, 600 - 16},
        16
    )
}

DrawMenuButtons :: proc(menu: ^Menu, pos: v2) {
    font := dm.LoadDefaultFont(dm.renderCtx)

    for btn, i in menu.buttons {
        if menu.hotButton == i {
            size := dm.MeasureText(btn, font)
            size += {10, -12}

            dm.DrawRectBlank({0, f32(i) * font.lineHeight} + pos + {0, 3}, size, 
                color = {1, 1, 1, 0.5},
                origin = {0.25, 0.25} // WHY?!?!
            )
        }

        dm.DrawTextCentered(dm.renderCtx, btn, font, {0, f32(i) * font.lineHeight} + pos)
    }
}

////////////

UpdateGameLost :: proc(menu: ^Menu) {
    clear(&menu.buttons)

    if MenuButton(menu, "Restart") {
        GameReset(.Gameplay)
    }
    if MenuButton(menu, "Back to menu") {
        gameState.gameStage = .Menu
        gameState.menu.state = .Main
    }

    move := dm.GetAxisInt(.W, .S, .JustPressed)
    if move == 0 {
        move = dm.GetAxisInt(.Up, .Down, .JustPressed)
    }

    menu.hotButton += int(move)
    menu.hotButton = clamp(menu.hotButton, 0, len(menu.buttons) - 1)
}

UpdateGameWon :: proc(menu: ^Menu) {
    clear(&menu.buttons)

    if MenuButton(menu, "Restart") {
        GameReset(.Gameplay)
    }
    if MenuButton(menu, "Back to menu") {
        gameState.gameStage = .Menu
        gameState.menu.state = .Main
    }

    move := dm.GetAxisInt(.W, .S, .JustPressed)
    if move == 0 {
        move = dm.GetAxisInt(.Up, .Down, .JustPressed)
    }

    menu.hotButton += int(move)
    menu.hotButton = clamp(menu.hotButton, 0, len(menu.buttons) - 1)
}


DrawGameWon :: proc() {
    dm.DrawTextCentered(
        dm.renderCtx,
        fmt.tprintf("Time: %.2f", gameState.levelTimer),
        dm.LoadDefaultFont(dm.renderCtx),
        {400, 120},
        40
    )

    dm.DrawRect(gameState.pleadTexture, {400, 300})
    DrawMenuButtons(&gameState.menu, {400, 400})

    dm.DrawTextCentered(
        dm.renderCtx,
        "W, S or Arrows - Select. Enter - accept.",
        dm.LoadDefaultFont(dm.renderCtx),
        {400, 600 - 20},
        20
    )
}

DrawGameLost :: proc() {
    dm.DrawTextCentered(
        dm.renderCtx,
        "You lost to Sakana!",
        dm.LoadDefaultFont(dm.renderCtx),
        {400, 120},
        40
    )
    
    dm.DrawRect(gameState.kekTexture, {400, 220})
    DrawMenuButtons(&gameState.menu, {400, 370})

    dm.DrawTextCentered(
        dm.renderCtx,
        "W, S or Arrows - Select. Enter - accept.",
        dm.LoadDefaultFont(dm.renderCtx),
        {400, 600 - 20},
        20
    )}