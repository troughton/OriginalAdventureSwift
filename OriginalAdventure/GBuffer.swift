//
//  File.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 5/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import OpenGL.GL3

final class GBuffer {
    
    private let _frameBufferObject : GLuint
    private let _glTextures : [GLuint]
    private let _depthTexture : GLuint
    private let _finalTexture : GLuint
    private let _finalBufferAttachment : GLenum
    
    init(ofSize sizeInPixels: WindowDimension) {
        // Create the FBO

        var fbo : GLuint = 0
        glGenFramebuffers(1, &fbo)

        _frameBufferObject = fbo;
        glBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), _frameBufferObject);
    
        
        let textureCount = TextureUnit.deferredShadingUnits.count
        let textureBuffer = UnsafeMutableBufferPointer<GLuint>(start: UnsafeMutablePointer<GLuint>(malloc(textureCount * sizeof(GLuint))), count: textureCount)
        glGenTextures(GLsizei(textureCount), textureBuffer.baseAddress)

        let textures = [GLuint](textureBuffer)
        free(textureBuffer.baseAddress)
        _glTextures = textures
        
        _depthTexture = glGenTexture();
        _finalTexture = glGenTexture();
        
        var i = 0;
        for textureUnit in TextureUnit.deferredShadingUnits {
            glBindTexture(GLenum(GL_TEXTURE_2D), _glTextures[i]);
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GBuffer.gBufferFormatForTextureUnit(textureUnit), sizeInPixels.width, sizeInPixels.height, 0, GLenum(GL_BGRA), GLenum(GL_FLOAT), nil);
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
            glFramebufferTexture2D(GLenum(GL_DRAW_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0 + i), GLenum(GL_TEXTURE_2D), _glTextures[i], 0);
            
            i++;
        }
        
        // depth
        glBindTexture(GLenum(GL_TEXTURE_2D), _depthTexture);
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_DEPTH32F_STENCIL8, sizeInPixels.width, sizeInPixels.height, 0, GLenum(GL_DEPTH_STENCIL), GLenum(GL_FLOAT_32_UNSIGNED_INT_24_8_REV), nil);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST);
        glFramebufferTexture2D(GLenum(GL_DRAW_FRAMEBUFFER), GLenum(GL_DEPTH_STENCIL_ATTACHMENT), GLenum(GL_TEXTURE_2D), _depthTexture, 0);
        
        _finalBufferAttachment = GLenum(GL_COLOR_ATTACHMENT0 + i);
        
        // final
        glBindTexture(GLenum(GL_TEXTURE_2D), _finalTexture);
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_SRGB8_ALPHA8, sizeInPixels.width, sizeInPixels.height, 0, GLenum(GL_RGBA), GLenum(GL_FLOAT), nil);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_COMPARE_MODE), GL_NONE);
        glFramebufferTexture2D(GLenum(GL_DRAW_FRAMEBUFFER), _finalBufferAttachment, GLenum(GL_TEXTURE_2D), _finalTexture, 0);
        
        let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER));
        
        if (status != GLenum(GL_FRAMEBUFFER_COMPLETE)) {
            print("FB error, status: 0x%x", status);
        }
        
        // restore default FBO
        glBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), 0);
    }
    
    deinit {
        if (_frameBufferObject != 0) {
            var fbo = _frameBufferObject
            glDeleteFramebuffers(1, &fbo)
        }
        
        if (_glTextures[0] != 0) {
            glDeleteTextures(GLsizei(_glTextures.count), _glTextures);
        }
        
        if (_depthTexture != 0) {
            var texture = _depthTexture
            glDeleteTextures(1, &texture)
        }
        
        if (_finalTexture != 0) {
            var texture = _finalTexture
            glDeleteTextures(1, &texture)
        }
    }
    
    private static func gBufferFormatForTextureUnit(textureUnit: TextureUnit) -> GLint {
        switch textureUnit {
        case .DiffuseColourUnit:
            return GL_RGB8
        case .SpecularityUnit:
            return GL_RGBA8_SNORM
        case .VertexNormalUnit:
            return GL_R11F_G11F_B10F //This is a positive-only format, so we need to modify the values in the shader
        default:
            preconditionFailure("\(textureUnit) does not have an associated GBuffer format")
        }
    }
    
    func startFrame() {
        glBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), _frameBufferObject);
        glDrawBuffer(_finalBufferAttachment);
    }
    
    
    func bindForGeometryPass() {
    
        let drawBuffers : [GLenum] = [GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_COLOR_ATTACHMENT1), GLenum(GL_COLOR_ATTACHMENT2), _finalBufferAttachment] //Normals, diffuse, specular, ambient.
        glDrawBuffers(GLsizei(drawBuffers.count), drawBuffers)
    }
    
    func bindForStencilPass() {
        // must disable the draw buffers
        glDrawBuffer(GLenum(GL_NONE))
    }
    
    func bindForLightPass() {
        glDrawBuffer(_finalBufferAttachment);
    
        var i = 0;
        for textureUnit in TextureUnit.deferredShadingUnits {
            textureUnit.makeActive()
            glBindTexture(GLenum(GL_TEXTURE_2D), _glTextures[i]);
            i++;
        }
    
        TextureUnit.DepthTextureUnit.makeActive()
        glBindTexture(GLenum(GL_TEXTURE_2D), _depthTexture)
    }
    
    func bindForFinalPass() {
        glBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), 0);
        glBindFramebuffer(GLenum(GL_READ_FRAMEBUFFER), _frameBufferObject);
        glReadBuffer(_finalBufferAttachment);
    }
    
}