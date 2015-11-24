//
//  TextureSampler.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import Metal
import ModelIO

struct TextureSampler : Hashable, Equatable {
    let texture : MTLTexture
    let textureUnit : TextureUnit
    
    init(texture: MTLTexture, textureUnit: TextureUnit, filter: MDLTextureFilter) {
        self.texture = texture
        self.textureUnit = textureUnit
    }
    
    
    func bindTexture() {
        
    }
    
    func unbindTexture() {
        
    }
    
    var hashValue : Int {
        return texture.hash * 31 + Int(textureUnit.rawValue)
    }
}

func ==(lhs: TextureSampler, rhs: TextureSampler) -> Bool {
    return lhs.texture === rhs.texture && lhs.textureUnit == rhs.textureUnit
}