package game

import dm "../dmcore"

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