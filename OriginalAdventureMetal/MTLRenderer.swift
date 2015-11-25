//
//  MTKRenderer.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 25/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import MetalKit

class MTLRenderer : Renderer {
    let commandQueue: MTLCommandQueue
    
    var currentFrameIndex = 0
    static let MaxFrameLag = 3
    
    let inflightSemaphore = dispatch_semaphore_create(MaxFrameLag)
    
    static let CameraNear : Float = 1.0;
    static let CameraFar : Float = 10000.0;
    static let DepthRangeNear = 0.0;
    static let DepthRangeFar = 1.0;
    
    let MaxMeshes = 128
    let MaxTextures = 2048
    
    var size : WindowDimension = WindowDimension.defaultDimension {
        didSet {
            _projectionMatrix = Matrix4(perspectiveWithFieldOfView: _currentFOV, aspect: Float(self.size.width)/Float(self.size.height), nearZ: MTLRenderer.CameraNear, farZ: MTLRenderer.CameraFar)
        }
    }
    
    var sizeInPixels : WindowDimension = WindowDimension.defaultDimension
    
    private var _currentFOV = Float(M_PI/3.0) {
        didSet {
            _projectionMatrix = Matrix4(perspectiveWithFieldOfView: _currentFOV, aspect: Float(self.size.width)/Float(self.size.height), nearZ: MTLRenderer.CameraNear, farZ: MTLRenderer.CameraFar)
        }
    }
    
    private var _projectionMatrix : Matrix4! = nil;
    
    init() {
        
        // load any resources required for rendering
        commandQueue = Metal.device.newCommandQueue()
        commandQueue.label = "main command queue"
        
        self.setupBuffers(maxMeshes: MaxMeshes, maxTextures: MaxTextures)
        
        self.normalTexture = Metal.device.newTextureWithDescriptor(textureDescriptor)
        Material.fillTextureWithColour(self.normalTexture, colour: float4(0.5, 0.5, 1, 0))
    }
    
    
    private let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA8Unorm, width: 1, height: 1, mipmapped: false)
    
    var transformationBuffers = [MTLBuffer]()
    var lightBuffers = [MTLBuffer]()
    var textureBuffers = [[MTLTexture]]()
    
    var normalTexture : MTLTexture! = nil
    
    
    func setupBuffers(maxMeshes maxMeshes: Int, maxTextures: Int) {
        textureDescriptor.usage = .ShaderRead
        
        for _ in 0..<MTLRenderer.MaxFrameLag {
            let transformationBuffer = Metal.device.newBufferWithLength(ceil(sizeof(ModelMatrices), toNearestMultipleOf: 256) * maxMeshes, options: [.StorageModeManaged])
            transformationBuffer.label = "Model Transformation Buffer"
            transformationBuffers.append(transformationBuffer)
            
            let lightBuffer = Metal.device.newBufferWithLength(ceil(sizeof(LightBlock), toNearestMultipleOf: 256), options: [.StorageModeManaged])
            lightBuffer.label = "Light Information Buffer"
            lightBuffers.append(lightBuffer)
            
            var textures = [MTLTexture]()
            for _ in 0..<maxTextures {
                textures.append(Metal.device.newTextureWithDescriptor(textureDescriptor))
            }
            textureBuffers.append(textures)
        }
    }
    
    private final func preRender() -> (MTLCommandBuffer, MTLRenderCommandEncoder, MTLDrawable)? {
        // use semaphore to encode 3 frames ahead
        dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        let commandBuffer = commandQueue.commandBuffer()
        commandBuffer.label = "Frame command buffer"
        
        // use completion handler to signal the semaphore when this frame is completed allowing the encoding of the next frame to proceed
        // use capture list to avoid any retain cycles if the command buffer gets retained anywhere besides this stack frame
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                dispatch_semaphore_signal(strongSelf.inflightSemaphore)
            }
            return
        }
        
        if !TextureLoader.texturesNeedingMipMapGeneration.isEmpty {
            let blitEncoder = commandBuffer.blitCommandEncoder()
            for texture in TextureLoader.texturesNeedingMipMapGeneration {
                blitEncoder.generateMipmapsForTexture(texture)
            }
            blitEncoder.endEncoding()
            
            TextureLoader.texturesNeedingMipMapGeneration.removeAll()
        }
        
        if let renderPassDescriptor = Metal.view.currentRenderPassDescriptor, currentDrawable = Metal.view.currentDrawable {
            return self.preRender(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor, drawable: currentDrawable)
        }
        
        return nil
    }
    
    func preRender(commandBuffer commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable) -> (MTLCommandBuffer, MTLRenderCommandEncoder, MTLDrawable) {
        preconditionFailure("This method must be overriden in a subclass")
    }
    
    func postRender(commandBuffer commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder, drawable: MTLDrawable) {
        renderEncoder.endEncoding()
        
        commandBuffer.presentDrawable(drawable)
        
        commandBuffer.commit()
        
    }
    
    func setModelMatrices(matricesRef: UnsafeMutablePointer<ModelMatrices>, forMesh mesh: Mesh, worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4) {
        let modelToCameraMatrix = (worldToCameraMatrix * mesh.worldSpaceTransform)
        matricesRef.memory.modelToCameraMatrix = modelToCameraMatrix.cmatrix
        matricesRef.memory.projectionMatrix = projectionMatrix.cmatrix
        matricesRef.memory.modelToCameraRotationMatrix = modelToCameraMatrix.matrix3.cmatrix
        matricesRef.memory.normalModelToCameraMatrix = modelToCameraMatrix.matrix3.inverse.transpose.cmatrix
        matricesRef.memory.textureRepeat = mesh.textureRepeat;
        
    }
    
    func render(meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, fieldOfView: Float, hdrMaxIntensity: Float) {
        if (fieldOfView != _currentFOV) {
            _currentFOV = fieldOfView;
        }
        self.render(meshes, lights: lights, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: _projectionMatrix, hdrMaxIntensity: hdrMaxIntensity)
    }
    
    func render(meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
        guard let (commandBuffer, renderEncoder, currentDrawable) = self.preRender() else { return }
        
        self.render(commandBuffer: commandBuffer, renderEncoder: renderEncoder, drawable: currentDrawable, meshes: meshes, lights: lights, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: projectionMatrix, hdrMaxIntensity: hdrMaxIntensity)
        
        self.postRender(commandBuffer: commandBuffer, renderEncoder: renderEncoder, drawable: currentDrawable)
        currentFrameIndex = (currentFrameIndex + 1) % MTLRenderer.MaxFrameLag
    }
    
    func render(commandBuffer commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder, drawable: MTLDrawable, meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
    }

}