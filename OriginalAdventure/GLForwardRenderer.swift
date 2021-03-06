//
//  GLForwardRenderer.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 9/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import OpenGL.GL3

class GLForwardRenderer : Renderer {
    
    static let CameraNear : Float = 10.0;
    static let CameraFar : Float = 4000.0;
    static let DepthRangeNear = 0.0;
    static let DepthRangeFar = 1.0;
    
    private var _shader : Shader = {
        let vertexShaderText = try! String(contentsOfFile: NSBundle.mainBundle().pathForResource("ForwardRenderer", ofType: "vert")!)
        let fragmentShaderText = try! String(contentsOfFile: NSBundle.mainBundle().pathForResource("ForwardRenderer", ofType: "frag")!)
        var shader = Shader(withVertexShader: vertexShaderText, fragmentShader: fragmentShaderText);
        shader.addTextureMappings([.AmbientColourMap : .AmbientColourUnit, .DiffuseColourMap : .DiffuseColourUnit, .SpecularityMap : .SpecularityUnit, .NormalMap : .NormalMapUnit])
        return shader
    }()
    
    var size : WindowDimension = WindowDimension.defaultDimension {
        didSet {
            _projectionMatrix = Matrix4(perspectiveWithFieldOfView: _currentFOV, aspect: Float(self.size.width)/Float(self.size.height), nearZ: GLForwardRenderer.CameraNear, farZ: GLForwardRenderer.CameraFar)
        }
    }
    
    var sizeInPixels : WindowDimension = WindowDimension.defaultDimension
    
    private var _currentFOV = Float(M_PI/3.0) {
        didSet {
            _projectionMatrix = Matrix4(perspectiveWithFieldOfView: _currentFOV, aspect: Float(self.size.width)/Float(self.size.height), nearZ: GLForwardRenderer.CameraNear, farZ: GLForwardRenderer.CameraFar)
        }
    }
    
    private var _projectionMatrix : Matrix4! = nil;
    
    init() {
    }
    
    /**
    * Setup GL state for rendering.
    */
    private func preRender() {
        glEnable(GLenum(GL_FRAMEBUFFER_SRGB));
    
        glEnable(GLenum(GL_CULL_FACE));
        glCullFace(GLenum(GL_BACK));
        glFrontFace(GLenum(GL_CCW));
    
        glEnable(GLenum(GL_DEPTH_TEST));
        glDepthMask(1);
        glDepthFunc(GLenum(GL_LEQUAL));
        glDepthRange(0.0, 1.0);
        glEnable(GLenum(GL_DEPTH_CLAMP));
    
        glClear(GLenum(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT));
    }
    
    /**
    * Revert changed GL state.
    */
    private func postRender() {
        glDisable(GLenum(GL_FRAMEBUFFER_SRGB));
        glDisable(GLenum(GL_CULL_FACE));
        glDisable(GLenum(GL_DEPTH_TEST));
    }
    
    func render(meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, fieldOfView: Float, hdrMaxIntensity: Float) {
        if (fieldOfView != _currentFOV) {
            _currentFOV = fieldOfView;
        }
        
        self.render(meshes, lights: lights, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: _projectionMatrix, hdrMaxIntensity: hdrMaxIntensity)

    }
    
    func render(meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
        
        var error = glGetError()
        if error != 0 {
            assertionFailure("OpenGL error \(error)")
        }
        
        self.preRender();
        
        _shader.useProgram();
        
        _shader.setMatrix(projectionMatrix, forProperty: .Matrix4CameraToClip)
        
        let lightBlock = Light.toLightBlock(lights.filter({$0.isEnabled}), worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
        _shader.setBuffer(lightBlock, forProperty: .LightBlock)
        
        for mesh in meshes {
            let nodeToCameraSpaceTransform = worldToCameraMatrix * mesh.worldSpaceTransform
            let normalModelToCameraSpaceTransform = nodeToCameraSpaceTransform.matrix3.inverse.transpose;
            
            _shader.setMatrix(nodeToCameraSpaceTransform, forProperty: .Matrix4ModelToCamera);
            _shader.setMatrix(nodeToCameraSpaceTransform.matrix3, forProperty: .Matrix3ModelToCamera);
            _shader.setMatrix(normalModelToCameraSpaceTransform, forProperty: .Matrix4NormalModelToCamera)
            
            (mesh as! GLMesh).renderWithShader(_shader, hdrMaxIntensity: hdrMaxIntensity)
            
        }
    
        _shader.endUseProgram();
        
        self.postRender();
        
        error = glGetError()
        if error != 0 {
            assertionFailure("OpenGL error \(error)")
        }
    }
}