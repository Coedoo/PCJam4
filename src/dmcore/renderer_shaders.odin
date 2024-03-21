package dmcore

DefaultShaderType :: enum {
    Sprite,
    ScreenSpaceRect,
    SDFFont,
}

Shader :: struct {
    handle: ShaderHandle,
    backend: _Shader,
}
