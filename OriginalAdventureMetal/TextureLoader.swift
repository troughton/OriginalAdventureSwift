//
//  TextureLoader.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import MetalKit

class TextureLoader {
    private static var textureLoader = MTKTextureLoader(device: Metal.device)
    class func loadTexture(atPath path: String, useSRGB : Bool, isHeightMap: Bool = false) throws -> MTLTexture {
        let texture = try textureLoader.newTextureWithContentsOfURL(NSURL.fileURLWithPath(path), options: [MTKTextureLoaderOptionAllocateMipmaps : true, MTKTextureLoaderOptionSRGB: useSRGB, MTKTextureLoaderOptionTextureUsage : MTLTextureUsage.ShaderRead.rawValue])
        texturesNeedingMipMapGeneration.append(texture)
        return texture
    }
    
    static var texturesNeedingMipMapGeneration = [MTLTexture]()
}