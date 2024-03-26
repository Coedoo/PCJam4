package dmcore

CommandBuffer :: struct {
    commands: [dynamic]Command
}

Command :: union {
    ClearColorCommand,
    CameraCommand,
    DrawRectCommand,
}

ClearColorCommand :: struct {
    clearColor: color
}

CameraCommand :: struct {
    camera: Camera
}

DrawRectCommand :: struct {
    position: v2,
    size: v2,
    rotation: f32,

    pivot: v2,

    texSource: RectInt,
    tint: color,

    texture: TexHandle,
    shader: ShaderHandle,
}

ClearColor :: proc(color: color) {
    ClearColorCtx(renderCtx, color)
}

ClearColorCtx :: proc(ctx: ^RenderContext, color: color) {
    append(&ctx.commandBuffer.commands, ClearColorCommand {
        color
    })
}


DrawWorldRect :: proc(texture: TexHandle, position: v2, size: v2, 
    rotation: f32 = 0, color := WHITE)
{
    DrawWorldRectCtx(renderCtx, texture, position, size, rotation, color)
}

DrawWorldRectCtx :: proc(ctx: ^RenderContext, texture: TexHandle, position: v2, size: v2, 
    rotation: f32 = 0, color := WHITE)
{
    cmd: DrawRectCommand

    tex := GetTextureCtx(ctx, texture)
    cmd.position = position
    cmd.size = size
    cmd.pivot = {0.5, 0.5}
    cmd.texture = texture
    cmd.texSource= {0, 0, tex.width, tex.height}
    cmd.rotation = rotation
    cmd.tint = color
    cmd.shader = ctx.defaultShaders[.Sprite]

    append(&ctx.commandBuffer.commands, cmd)
}

DrawSprite :: proc(sprite: Sprite, position: v2, 
                   rotation: f32 = 0, color := WHITE)
{
    DrawSpriteCtx(renderCtx, sprite, position, rotation, color)
}

DrawSpriteCtx :: proc(ctx: ^RenderContext, sprite: Sprite, position: v2, 
    rotation: f32 = 0, color := WHITE)
{
    cmd: DrawRectCommand

    texPos := sprite.texturePos

    texInfo := GetTextureCtx(ctx, sprite.texture)

    if sprite.animDirection == .Horizontal {
        texPos.x += sprite.textureSize.x * sprite.currentFrame
        if texPos.x >= texInfo.width {
            texPos.x = texPos.x % max(texInfo.width, 1)
        }
    }
    else {
        texPos.y += sprite.textureSize.y * sprite.currentFrame
        if texPos.y >= texInfo.height {
            texPos.y = texPos.y % max(texInfo.height, 1)
        }
    }

    // texPos += sprite.pixelSize * sprite.currentFrame * ({1, 0} if sprite.animDirection == .Horizontal else {0, 1})


    size := GetSpriteSize(sprite)

    // @TODO: flip will be incorrect for every sprite that doesn't
    // use {0.5, 0.5} as origin
    flip := v2{sprite.flipX ? -1 : 1, sprite.flipY ? -1 : 1}

    cmd.position = position
    cmd.pivot = sprite.origin
    cmd.size = size * flip
    cmd.texSource = {texPos.x, texPos.y, sprite.textureSize.x, sprite.textureSize.y}
    cmd.rotation = rotation
    cmd.tint = color * sprite.tint
    cmd.texture = sprite.texture
    cmd.shader  = ctx.defaultShaders[.Sprite]

    append(&ctx.commandBuffer.commands, cmd)
}

DrawBlankSprite :: proc(position: v2, size: v2, color := WHITE) {
    DrawBlankSpriteCtx(renderCtx, position, size, color)
}

DrawBlankSpriteCtx :: proc(ctx: ^RenderContext, position: v2, size: v2, color := WHITE) {
    cmd: DrawRectCommand

    texture := ctx.whiteTexture
    tex := GetTextureCtx(ctx, texture)

    cmd.position = position
    cmd.size = size
    cmd.texSource = {0, 0, tex.width, tex.height}
    cmd.tint = color
    cmd.pivot = {0.5, 0.5}

    cmd.texture = texture
    cmd.shader =  ctx.defaultShaders[.Sprite]

    append(&ctx.commandBuffer.commands, cmd)
}

DrawRect :: proc {
    DrawRectPos,

    DrawRectSrcDst,
    DrawRectSrcDstCtx,
    DrawRectSize,
    DrawRectSizeCtx,
    DrawRectBlank,
    DrawRectBlankCtx,
}

DrawRectSrcDst :: proc(texture: TexHandle, source: RectInt, dest: Rect, shader: ShaderHandle,
                 origin := v2{0.5, 0.5}, color: color = WHITE)
{
    DrawRectSrcDstCtx(renderCtx, texture, source, dest, shader, origin, color)
}


DrawRectSrcDstCtx :: proc(ctx: ^RenderContext, texture: TexHandle, 
                 source: RectInt, dest: Rect, shader: ShaderHandle,
                 origin := v2{0.5, 0.5},
                 color: color = WHITE)
{
    cmd: DrawRectCommand

    size := v2{dest.width, dest.height}

    cmd.position = {dest.x, dest.y} - origin * size
    cmd.size = size
    cmd.texSource = source
    cmd.tint = color

    cmd.texture = texture
    cmd.shader =  shader

    append(&ctx.commandBuffer.commands, cmd)
}

DrawRectPos :: proc(texture: TexHandle, position: v2,
    origin := v2{0.25, 0.25}, color: color = WHITE, scale := f32(1))
{
    size := GetTextureSize(texture)
    DrawRectSize(texture, position, ToV2(size) * scale, origin, color)
}

DrawRectSize :: proc(texture: TexHandle,  position: v2, size: v2, 
    origin := v2{0.5, 0.5}, color: color = WHITE)
{
    DrawRectSizeCtx(renderCtx, texture, position, size, origin, color)
}

DrawRectSizeCtx :: proc(ctx: ^RenderContext, texture: TexHandle, 
                     position: v2, size: v2, origin := v2{0.5, 0.5}, 
                     color: color = WHITE)
{
    tex := GetTextureCtx(ctx, texture)
    src := RectInt{ 0, 0, tex.width, tex.height}
    destPos := position - origin * size
    dest := Rect{ destPos.x, destPos.y, size.x, size.y }

    DrawRectSrcDstCtx(ctx, texture, src, dest, ctx.defaultShaders[.ScreenSpaceRect], origin, color)
}

DrawRectBlank :: proc(position: v2, size: v2, 
    origin := v2{0.5, 0.5}, color: color = WHITE)
{
    DrawRectBlankCtx(renderCtx, position, size, origin, color)
}

DrawRectBlankCtx :: proc(ctx: ^RenderContext, 
                     position: v2, size: v2, origin := v2{0.5, 0.5}, 
                     color: color = WHITE)
{
    DrawRectSizeCtx(ctx, ctx.whiteTexture, position, size, origin, color)
}

SetCamera :: proc(camera: Camera) {
    append(&renderCtx.commandBuffer.commands, CameraCommand{
        camera
    })
}