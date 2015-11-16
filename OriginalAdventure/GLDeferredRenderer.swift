//
//  GLDeferredRenderer.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 29/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

/**
 * Created by Thomas Roughton, Student ID 300313924, on 11/10/15.
 *
 * Implementation adapted from http://ogldev.atspace.co.uk/www/tutorial37/tutorial37.html
 */
class GLDeferredRenderer : Renderer {
    
    
    private var _geometryPassShader : Shader;
    private var _pointLightPassShader : Shader;
    private var _directionalLightPassShader :  Shader;
    private var _nullShader : Shader;

    private var _currentFOV = Float(M_PI/3.0) {
        didSet {
            _projectionMatrix = Matrix4(perspectiveWithFieldOfView: _currentFOV, aspect: Float(self.size.width)/Float(self.size.height), nearZ: GLDeferredRenderer.CameraNear, farZ: GLDeferredRenderer.CameraFar)
        }
    }
    private var _projectionMatrix : Matrix4;
    
    private var _gBuffer : GBuffer?;
    
    init(dimensions : WindowDimension) {
        
        _geometryPassShader = Shader();
        _pointLightPassShader = Shader();
        _nullShader = Shader();
        
        self.size = dimensions
    }
    
    var size : WindowDimension {
        didSet {
            _projectionMatrix = Matrix4(perspectiveWithFieldOfView: _currentFOV, aspect: Float(self.size.width)/Float(self.size.height), nearZ: GLDeferredRenderer.CameraNear, farZ: GLDeferredRenderer.CameraFar)
        }
    }
    
    var sizeInPixels : WindowDimension {
        didSet {
            _gBuffer = GBuffer(ofSize: self.sizeInPixels);
            
            _directionalLightPassShader.setUniform(Float(self.sizeInPixels.width), Float(self.sizeInPixels.height), forProperty: .ScreenSize)
            _pointLightPassShader.setUniform(Float(self.sizeInPixels.width), Float(self.sizeInPixels.height), forProperty: .ScreenSize)
        }
    }
    
    /**
    * Renders the given nodes using the given lights and transformation matrix
    * @param nodes The nodes to render
    * @param lights The lights to use in lighting the nodes
    * @param worldToCameraMatrix A transformation to convert the node's position in world space to a position in camera space.
    * @param fieldOfView The field of view of the camera
    * @param hdrMaxIntensity The maximum light intensity in the scene.
    */
    func render(nodes: [GameObject], lights: [Light], worldToCameraMatrix: Matrix4, fieldOfView: Float, hdrMaxIntensity: Float) {
        
        if (fieldOfView != _currentFOV) {
            _currentFOV = fieldOfView;
        }
        
        self.render(nodes, lights: lights, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: _projectionMatrix, hdrMaxIntensity: hdrMaxIntensity);
    }
    
    func render(nodes: [GameObject], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
        guard let gBuffer = _gBuffer else { return }
        
        self.preRender();
        
        gBuffer.startFrame();
        self.performGeometryPass(nodes: nodes, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: projectionMatrix, ambientMaxIntensity: hdrMaxIntensity);
        
        // We need stencil to be enabled in the stencil pass to get the stencil buffer
        // updated and we also need it in the light pass because we render the light
        // only if the stencil passes.
        glEnable(GLenum(GL_STENCIL_TEST));
        
        for light in lights {
            switch light {
            case .Point(_, _, _, _, _):
                    let lightToCameraMatrix = self.calculatePointLightSphereToCameraTransform(light: light, worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
                    self.performStencilPass(lightToCameraMatrix: lightToCameraMatrix, projectionMatrix: projectionMatrix)
                    self.performPointLightPass(light, lightToCameraMatrix: lightToCameraMatrix, projectionMatrix: projectionMatrix, hdrMaxIntensity: hdrMaxIntensity)
            }
        }
        
        // The directional light does not need a stencil test because its volume
        // is unlimited and the final pass simply copies the texture.
        glDisable(GLenum(GL_STENCIL_TEST));
        
        self.performDirectionalLightPass(lights, worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity);
        
        self.performFinalPass();
        
        self.postRender();

    }
    
    /**
    * Setup GL state for rendering.
    */
    func preRender() {
        glEnable(GLenum(GL_FRAMEBUFFER_SRGB));
        
        glEnable(GLenum(GL_CULL_FACE));
        glCullFace(GLenum(GL_BACK))
        glFrontFace(GLenum(GL_CCW))
        
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthMask(1);
        glDepthFunc(GLenum(GL_LEQUAL))
        glDepthRange(GLDeferredRenderer.DepthRangeNear, GLDeferredRenderer.DepthRangeFar);
        glEnable(GLenum(GL_DEPTH_CLAMP))
        
        glClear(GLenum(GL_DEPTH_BUFFER_BIT));
        
        glDisable(GLenum(GL_BLEND));
    }
    
    /**
    * Revert changed GL state.
    */
    func postRender() {
        glDisable(GLenum(GL_FRAMEBUFFER_SRGB));
        glDisable(GLenum(GL_CULL_FACE));
        glDisable(GLenum(GL_DEPTH_TEST))
        
        glEnable(GLenum(GL_BLEND))
        
        glBlendEquationSeparate(GLenum(GL_FUNC_ADD), GLenum(GL_FUNC_ADD))
        glBlendFuncSeparate(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA), GLenum(GL_ONE), GLenum(GL_ONE))
    }
    
    func performGeometryPass(nodes nodes: [GameObject], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, ambientMaxIntensity : Float) {
        _geometryPassShader.useProgram();
        
        _gBuffer!.bindForGeometryPass();
        
        glDepthMask(1);
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT));
        
        glEnable(GLenum(GL_DEPTH_TEST))
        
        _geometryPassShader.setMatrix(projectionMatrix, forProperty: .Matrix4CameraToClip)
        
        for node in nodes {
            guard let mesh = node.mesh else { continue }
            
            let nodeToCameraTransform = worldToCameraMatrix * node.nodeToWorldSpaceTransform
            let normalModelToCameraTransform = nodeToCameraTransform.matrix3.inverse.transpose
            
            _geometryPassShader.setMatrix(nodeToCameraTransform, forProperty: .Matrix4ModelToCamera)
            _geometryPassShader.setMatrix(normalModelToCameraTransform, forProperty: .Matrix4NormalModelToCamera)
            
            mesh.renderWithShader(_geometryPassShader, hdrMaxIntensity: ambientMaxIntensity)
        }
        
        _geometryPassShader.endUseProgram();
        
        // When we get here the depth buffer is already populated and the stencil pass
        // depends on it, but it does not write to it.
        glDepthMask(0);
    }
    
    func performStencilPass(lightToCameraMatrix lightToCameraMatrix : Matrix4, projectionMatrix : Matrix4) {
        _nullShader.useProgram();
        
        _gBuffer!.bindForStencilPass();
        
        glEnable(GLenum(GL_DEPTH_TEST));
        glDisable(GLenum(GL_CULL_FACE));
        
        glClear(GLenum(GL_STENCIL_BUFFER_BIT));
        
        // We need the stencil test to be enabled but we want it
        // to succeed always. Only the depth test matters.
        glStencilFunc(GLenum(GL_ALWAYS), 0, 0);
        
        glStencilOpSeparate(GLenum(GL_BACK), GLenum(GL_KEEP), GLenum(GL_INCR_WRAP), GLenum(GL_KEEP));
        glStencilOpSeparate(GLenum(GL_FRONT), GLenum(GL_KEEP), GLenum(GL_DECR_WRAP), GLenum(GL_KEEP));
        
        let sphereMesh = MeshType.meshFromFile(fileName: "sphere.obj")
        
        let modelToClipMatrix = lightToCameraMatrix * projectionMatrix
        
        _nullShader.setMatrix(modelToClipMatrix, forProperty: .Matrix4ModelToClip)
        
        sphereMesh.render();
    }
    
    private func calculatePointLightSphereRadius(pointLight : Light, hdrMaxIntensity : Float) -> Float {
        let colourVector = pointLight.colourVector;
        let maxChannel = max(max(colourVector.x, colourVector.y), colourVector.z) * 256 / hdrMaxIntensity;
        
        let falloff = pointLight.falloff
        
        let radius = (-falloff.linear + sqrtf(falloff.linear * falloff.linear - 4 * falloff.quadratic * (falloff.constant - maxChannel)))/(2 * falloff.quadratic);
        return radius;
    }
    
    func calculatePointLightSphereToCameraTransform(light light : Light, worldToCameraMatrix : Matrix4, hdrMaxIntensity : Float) -> Matrix4 {
        let nodeToCameraSpaceTransform = worldToCameraMatrix * light.parent!.nodeToWorldSpaceTransform;
        
        let translationInWorldSpace = nodeToCameraSpaceTransform * Vector4.ZeroPosition;
        
        let scale = self.calculatePointLightSphereRadius(light, hdrMaxIntensity: hdrMaxIntensity);
        let scaleMatrix = Matrix4(withScale: Vector3(scale));
        return Matrix4(withTranslation: Vector3(translationInWorldSpace.x, translationInWorldSpace.y, translationInWorldSpace.z)) * scaleMatrix
    }
    
    func computeHalfSizeNearPlane(zNear zNear: Float, windowDimensions : WindowDimension, projectionMatrix: Matrix4) -> (x: Float, y: Float) {
        let cameraAspect = windowDimensions.aspect;
        let tanHalfFoV = 1/(projectionMatrix[0][0] * cameraAspect);
        let y = tanHalfFoV * zNear;
        let x = y * cameraAspect;
        return (x, y)
    }
    
    func performPointLightPass(light : Light, lightToCameraMatrix : Matrix4, projectionMatrix : Matrix4, hdrMaxIntensity : Float) {
        
        let sphereMesh = MeshType.meshFromFile(fileName: "sphere.obj")
        
        _gBuffer!.bindForLightPass();
        
        _pointLightPassShader.useProgram();
        
        glStencilFunc(GLenum(GL_NOTEQUAL), 0, 0xFF);
        
        glDisable(GLenum(GL_DEPTH_TEST));
        glEnable(GLenum(GL_BLEND));
        glBlendEquation(GLenum(GL_FUNC_ADD));
        glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE));
        
        glEnable(GLenum(GL_CULL_FACE));
        glCullFace(GLenum(GL_FRONT));
        
        _pointLightPassShader.pointLightData = light.pointLightDataBuffer(lightToCameraMatrix, hdrMaxIntensity);
        _pointLightPassShader.setMatrix(lightToCameraMatrix, forProperty: .Matrix4ModelToCamera)
        _pointLightPassShader.setMatrix(projectionMatrix, forProperty: .Matrix4CameraToClip);
        
        _pointLightPassShader.setUniform(Float(GLDeferredRenderer.DepthRangeNear), Float(GLDeferredRenderer.DepthRangeFar), forProperty: .DepthRange);
        
        let halfSizeNearPlane = self.computeHalfSizeNearPlane(zNear: GLDeferredRenderer.CameraNear, windowDimensions: self.sizeInPixels, projectionMatrix: projectionMatrix)
        _pointLightPassShader.setUniform(halfSizeNearPlane.x, halfSizeNearPlane.y, forProperty: .HalfSizeNearPlane)
        
        sphereMesh.render();
        
        glCullFace(GLenum(GL_BACK));
        glDisable(GLenum(GL_BLEND));
    }
    
    func performDirectionalLightPass(lights: [Light], worldToCameraMatrix : Matrix4, hdrMaxIntensity : Float) {
        guard !lights.isEmpty else { return }
        
        _gBuffer!.bindForLightPass();
        _directionalLightPassShader.useProgram();
        
        let quadMesh = MeshType.meshFromFile(fileName: "Plane.obj");
        
        let filteredLights = lights.filter { (light) -> Bool in
            switch light {
            case .Ambient(_, _, _):
                return true
            case .Directional(_, _, _, _):
                return true
            default:
                return false
            }
        }
        
        _directionalLightPassShader.lightData = Light.toLightBlock(filteredLights, worldToCameraMatrix, hdrMaxIntensity);
        
        glDisable(GLenum(GL_DEPTH_TEST));
        glEnable(GLenum(GL_BLEND));
        glBlendEquation(GLenum(GL_FUNC_ADD));
        glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE));
        
        quadMesh.render();
        
        glDisable(GLenum(GL_BLEND));
        
        _directionalLightPassShader.endUseProgram();
    }
    
    func performFinalPass() {
        _gBuffer!.bindForFinalPass();
        
        glBlitFramebuffer(0, 0, self.sizeInPixels.width, self.sizeInPixels.height,
            0, 0, self.sizeInPixels.width, self.sizeInPixels.height, GLenum(GL_COLOR_BUFFER_BIT), GLenum(GL_LINEAR));
        glBindFramebuffer(GLenum(GL_READ_FRAMEBUFFER), 0);
    }
    
}