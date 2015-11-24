//
//  TextureSampler.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 12/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import ModelIO
import OpenGL.GL3
import GLKit

extension MDLMaterialTextureWrapMode {
    var glMode : GLint {
        switch self {
        case .Clamp:
            return GL_CLAMP_TO_EDGE
        case .Mirror:
            return GL_MIRRORED_REPEAT
        case .Repeat:
            return GL_REPEAT
        }
    }
}

extension MDLTextureFilter {
    
    func glFilter(filter : MDLMaterialTextureFilterMode, _ mipFilter: MDLMaterialMipMapFilterMode, _ useMipMaps: Bool) -> GLint {
        
        switch (filter, mipFilter, useMipMaps) {
        case (.Nearest, _, false):
            return GL_NEAREST
        case (.Linear, _, false):
            return GL_LINEAR
        case (.Nearest, .Nearest, true):
            return GL_NEAREST_MIPMAP_NEAREST
        case (.Linear, .Nearest, true):
            return GL_LINEAR_MIPMAP_NEAREST
        case (.Nearest, .Linear, true):
            return GL_NEAREST_MIPMAP_LINEAR
        case (.Linear, .Linear, true):
            return GL_LINEAR_MIPMAP_LINEAR
        }
    }
    
    func applyToSampler(sampler: GLuint, useMipMaps: Bool) {
        glSamplerParameteri(sampler, GLenum(GL_TEXTURE_MAG_FILTER), self.glFilter(self.magFilter, self.mipFilter, false))
        glSamplerParameteri(sampler, GLenum(GL_TEXTURE_MIN_FILTER), self.glFilter(self.minFilter, self.mipFilter, useMipMaps));
        
        glSamplerParameteri(sampler, GLenum(GL_TEXTURE_WRAP_S), self.sWrapMode.glMode);
        glSamplerParameteri(sampler, GLenum(GL_TEXTURE_WRAP_T), self.tWrapMode.glMode);
        glSamplerParameteri(sampler, GLenum(GL_TEXTURE_WRAP_R), self.rWrapMode.glMode)
    }
}

struct TextureSampler : Hashable {
    let texture : GLKTextureInfo
    let textureUnit : TextureUnit
    
    init(texture: GLKTextureInfo, textureUnit: TextureUnit, filter: MDLTextureFilter) {
        self.texture = texture
        self.textureUnit = textureUnit
        
        filter.applyToSampler(_glSamplerRef, useMipMaps: self.texture.containsMipmaps)
        
        glSamplerParameterf(_glSamplerRef, GLenum(GL_TEXTURE_MAX_ANISOTROPY_EXT), 4.0);
    }
 
    private let _glSamplerRef : GLuint = {
        var sampler : GLuint = 0;
        glGenSamplers(1, &sampler)
        return sampler
    }()
    
    func bindTexture() {
        self.textureUnit.makeActive()

        glBindTexture(texture.target, texture.name)
        
        glBindSampler(self.textureUnit.rawValue, _glSamplerRef)
        
    }
    
    func unbindTexture() {
        self.textureUnit.makeActive()
        glBindTexture(texture.target, 0)
        
        glBindSampler(self.textureUnit.rawValue, 0)
    }
    
    var hashValue : Int {
        return texture.hash * 31 + Int(textureUnit.rawValue)
    }
}

func ==(lhs: TextureSampler, rhs: TextureSampler) -> Bool {
    return lhs.texture === rhs.texture && lhs.textureUnit == rhs.textureUnit
}