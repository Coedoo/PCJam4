package dmcore

import "core:fmt"
import "core:os"

ASSETS_ROOT :: "assets/"

TextureAssetDescriptor :: struct {
    filter: TextureFilter
}

ShaderAssetDescriptor :: struct {
}

FontAssetDescriptor :: struct {
    fontType: FontType,
    fontSize: int,
}

SoundAssetDescriptor :: struct {
}

RawFileAssetDescriptor :: struct {
}

AssetDescriptor :: union {
    TextureAssetDescriptor,
    ShaderAssetDescriptor,
    FontAssetDescriptor,
    SoundAssetDescriptor,
    RawFileAssetDescriptor,
}

AssetData :: struct {
    fileName: string,

    fileData: []u8,

    lastWriteTime: os.File_Time,

    handle: Handle,

    descriptor: AssetDescriptor,

    // Linked list
    // @NOTE: 
    // This is primarly for loading assets in asynchronous way,
    // since you can't index map the easy way.
    // So the question is, wouldn't be better to just have array of
    // registered assets, and store them in map only after loading?
    prev: ^AssetData,
    next: ^AssetData,
}

Assets :: struct {
    assetsMap: map[string]AssetData,

    firstAsset: ^AssetData,
    lastAsset: ^AssetData,
}

RegisterAsset :: proc(fileName: string, desc: AssetDescriptor) {
    RegisterAssetCtx(assets, fileName, desc)
}

RegisterAssetCtx :: proc(assets: ^Assets, fileName: string, desc: AssetDescriptor) {
    if fileName in assets.assetsMap {
        fmt.eprintln("Duplicated asset file name:", fileName, ". Skipping...")
        return
    }

    assets.assetsMap[fileName] = AssetData {
        fileName = fileName,
        descriptor = desc,
    }

    // add to linked list
    assetPtr := &assets.assetsMap[fileName]
    if assets.firstAsset == nil {
        assets.firstAsset = assetPtr
        assets.lastAsset = assetPtr
    }
    else {
        assetPtr.prev = assets.lastAsset
        assets.lastAsset.next = assetPtr
        assets.lastAsset = assetPtr
    }
}

GetAssetData :: proc(fileName: string) -> ^AssetData {
    return GetAssetDataCtx(assets, fileName)
}

GetAssetDataCtx :: proc(assets: ^Assets, fileName: string) -> ^AssetData {
    return &assets.assetsMap[fileName]
}


GetAsset :: proc(fileName: string) -> Handle {
    return GetAssetCtx(assets, fileName)
}

GetAssetCtx :: proc(assets: ^Assets, fileName: string) -> Handle {
    return assets.assetsMap[fileName].handle
}

GetTextureAsset :: proc(fileName: string) -> TexHandle {
    return cast(TexHandle) GetAssetCtx(assets, fileName)
}

GetTextureAssetCtx :: proc(assets: ^Assets, fileName: string) -> TexHandle {
    return cast(TexHandle) GetAssetCtx(assets, fileName)
}

// @TODO: ReloadAsset

ReleaseAssetData :: proc(fileName: string) {
    ReleaseAssetDataCtx(assets, fileName)
}

ReleaseAssetDataCtx :: proc(assets: ^Assets, fileName: string) {
    assetData, ok := &assets.assetsMap[fileName]
    if ok && assetData.fileData != nil {
        delete(assetData.fileData)
        assetData.fileData = nil
    }
}