package platform_wasm

import "core:mem"
import "core:runtime"
import dm "../dmcore"

wasmContext: runtime.Context

// @TODO make it configurable
tempBackingBuffer: [16 * mem.Megabyte]byte
tempArena: mem.Arena


mainBackingBuffer: [128 * mem.Megabyte]byte
mainAllocator: dm.FreeList

InitContext :: proc () {
    // wasmContext = context

    mem.arena_init(&tempArena, tempBackingBuffer[:])
    wasmContext.temp_allocator = mem.arena_allocator(&tempArena)

    dm.FreeListInit(&mainAllocator, mainBackingBuffer[:])
    wasmContext.allocator = dm.FreeListAllocator(&mainAllocator)

    wasmContext.logger = context.logger
}

@(export, link_name = "get_ctx_ptr")
GetContextPtr :: proc "contextless" () -> (^runtime.Context) {
    return &wasmContext
}

@(export, link_name="wasm_alloc")
WasmAlloc :: proc "contextless" (byteLength: uint) -> rawptr {
    context = wasmContext
    rec := make([]byte, byteLength, context.allocator)
    return raw_data(rec)
}

@(export, link_name="wasm_temp_alloc")
WasmTempAlloc :: proc "contextless" (byteLength: uint) -> rawptr {
    context = wasmContext
    rec := make([]byte, byteLength, context.temp_allocator)
    return raw_data(rec)
}