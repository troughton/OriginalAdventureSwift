//
//  GLForwardRenderer.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 9/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import OpenGL

class GLForwardRenderer : Renderer {
    
    static let CameraNear : Float = 1.0;
    static let CameraFar : Float = 10000.0;
    static let DepthRangeNear = 0.0;
    static let DepthRangeFar = 1.0;
    
    private var _shader : Shader = {
        let vertexShaderText = try! String(contentsOfFile: NSBundle.mainBundle().pathForResource("PassthroughShader", ofType: "vert")!)
        let fragmentShaderText = try! String(contentsOfFile: NSBundle.mainBundle().pathForResource("PickerShader", ofType: "frag")!)
        return Shader(withVertexShader: vertexShaderText, fragmentShader: fragmentShaderText);
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
    
        glClear(GLenum(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT));
    }
    
    /**
    * Revert changed GL state.
    */
    private func postRender() {
        glDisable(GLenum(GL_FRAMEBUFFER_SRGB));
        glDisable(GLenum(GL_CULL_FACE));
        glDisable(GLenum(GL_DEPTH_TEST));
    }
    
    func render(nodes: [GameObject], lights: [Light], worldToCameraMatrix: Matrix4, fieldOfView: Float, hdrMaxIntensity: Float) {
        if (fieldOfView != _currentFOV) {
            _currentFOV = fieldOfView;
        }
        
        self.render(nodes, lights: lights, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: _projectionMatrix, hdrMaxIntensity: hdrMaxIntensity)

    }
    
    func render(nodes: [GameObject], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
        var error = GLenum(0)
        
        self.preRender();
        
        _shader.useProgram();
        
        _shader.setMatrix(projectionMatrix, forProperty: .Matrix4CameraToClip)
        
  //      _shader.setLightData(Light.toLightBlock(lights.stream().filter(Light::isOn).collect(Collectors.toList()), worldToCameraMatrix, hdrMaxIntensity));
        
        for node in nodes {
            guard let mesh = node.mesh else { continue }
            let nodeToCameraSpaceTransform = worldToCameraMatrix * node.nodeToWorldSpaceTransform
            let normalModelToCameraSpaceTransform = nodeToCameraSpaceTransform.matrix3.inverse.transpose;
            
            _shader.setMatrix(nodeToCameraSpaceTransform, forProperty: .Matrix4ModelToCamera);
        //    _shader.setMatrix(normalModelToCameraSpaceTransform, forProperty: .Matrix4NormalModelToCamera)
            
            mesh.renderWithShader(_shader, hdrMaxIntensity: hdrMaxIntensity)
            
        }
    
        _shader.endUseProgram();
        
        self.postRender();
        
        error = glGetError()
        if error != 0 {
            assertionFailure("OpenGL error \(error)")
        }
    }
}