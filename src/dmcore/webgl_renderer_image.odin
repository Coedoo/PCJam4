//+build js
package dmcore

import gl "vendor:wasm/WebGL"

Texture_wgl :: struct {
    using info: Texture,

    texId: gl.Texture,
}

_CreateTexture :: proc(rawData: []u8, width, height, channels: int, renderCtx: ^RenderContext, filter: TextureFilter) -> TexHandle {
    texture := CreateElement(renderCtx.textures)

    texture.width  = i32(width)
    texture.height = i32(height)

    id := gl.CreateTexture()
    texture.backendData = transmute(int) id
    gl.BindTexture(gl.TEXTURE_2D, id)

    switch filter {
    case .Point:
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.NEAREST))
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.NEAREST))

    case .Bilinear:
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.LINEAR))
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.LINEAR))

    case .Mip:
        panic("Implement Me!")
    }

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.CLAMP_TO_EDGE))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.CLAMP_TO_EDGE))

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(width), i32(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, len(rawData), raw_data(rawData))

    gl.BindTexture(gl.TEXTURE_2D, 0)

    return texture.handle
}
