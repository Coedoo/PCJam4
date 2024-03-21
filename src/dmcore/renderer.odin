package dmcore

TexHandle :: distinct Handle
ShaderHandle :: distinct Handle
BatchHandle :: distinct Handle

RenderContext :: struct {
    whiteTexture: TexHandle,

    frameSize: iv2,

    defaultBatch: RectBatch,
    debugBatch:   PrimitiveBatch,
    debugBatchScreen: PrimitiveBatch,

    commandBuffer: CommandBuffer,

    textures: ResourcePool(Texture, TexHandle),
    shaders: ResourcePool(Shader, ShaderHandle),

    defaultShaders: [DefaultShaderType]ShaderHandle,

    /////

    DrawBatch: proc(ctx: ^RenderContext, batch: ^RectBatch),
}
