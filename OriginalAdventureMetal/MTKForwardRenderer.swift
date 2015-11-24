//
//  MTKForwardRenderer.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import MetalKit


class MTKForwardRenderer : Renderer {
    
    var commandQueue: MTLCommandQueue! = nil
    var pipelineState: MTLRenderPipelineState! = nil
    var depthState: MTLDepthStencilState! = nil
    var vertexBuffer: MTLBuffer! = nil
    var vertexColorBuffer: MTLBuffer! = nil
    
    var _currentFrameIndex = 0
    static let MaxFrameLag = 3
    
    let inflightSemaphore = dispatch_semaphore_create(MaxFrameLag)
    
    static let CameraNear : Float = 1.0;
    static let CameraFar : Float = 10000.0;
    static let DepthRangeNear = 0.0;
    static let DepthRangeFar = 1.0;
    
    let MaxMeshes = 128
    let MaxMaterials = 128
    
    var size : WindowDimension = WindowDimension.defaultDimension {
        didSet {
            _projectionMatrix = Matrix4(perspectiveWithFieldOfView: _currentFOV, aspect: Float(self.size.width)/Float(self.size.height), nearZ: MTKForwardRenderer.CameraNear, farZ: MTKForwardRenderer.CameraFar)
        }
    }
    
    var sizeInPixels : WindowDimension = WindowDimension.defaultDimension
    
    private var _currentFOV = Float(M_PI/3.0) {
        didSet {
            _projectionMatrix = Matrix4(perspectiveWithFieldOfView: _currentFOV, aspect: Float(self.size.width)/Float(self.size.height), nearZ: MTKForwardRenderer.CameraNear, farZ: MTKForwardRenderer.CameraFar)
        }
    }
    
    private var _projectionMatrix : Matrix4! = nil;
    
    init() {
        
        // load any resources required for rendering
        commandQueue = Metal.device.newCommandQueue()
        commandQueue.label = "main command queue"
        
        let defaultLibrary = Metal.device.newDefaultLibrary()!
        let fragmentProgram = defaultLibrary.newFunctionWithName("forwardRendererFragmentShader")!
        let vertexProgram = defaultLibrary.newFunctionWithName("forwardRendererVertexShader")!
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = Metal.view.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = Metal.view.depthStencilPixelFormat
        pipelineStateDescriptor.stencilAttachmentPixelFormat = Metal.view.depthStencilPixelFormat
        pipelineStateDescriptor.sampleCount = Metal.view.sampleCount
        pipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(MTLMesh.vertexDescriptor)
        
        do {
            try pipelineState = Metal.device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error {
            print("Failed to create pipeline state, error \(error)")
            NSApp.terminate(nil)
        }
        
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthWriteEnabled = true
        depthStencilDescriptor.depthCompareFunction = .LessEqual
        depthState = Metal.device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
        
        self.setupBuffers(maxMeshes: MaxMeshes, maxMaterials: MaxMaterials)
    }
    
    var transformationBuffers = [MTLBuffer]()
    var lightBuffers = [MTLBuffer]()
    var materialBuffers = [MTLBuffer]()
    
    func setupBuffers(maxMeshes maxMeshes: Int, maxMaterials: Int) {
        for _ in 0..<MTKForwardRenderer.MaxFrameLag {
            let transformationBuffer = Metal.device.newBufferWithLength(ceil(sizeof(ModelMatrices), toNearestMultipleOf: 256) * maxMeshes, options: [])
            transformationBuffer.label = "Model Transformation Buffer"
            transformationBuffers.append(transformationBuffer)
            
            let lightBuffer = Metal.device.newBufferWithLength(ceil(sizeof(LightBlock), toNearestMultipleOf: 256), options: [])
            lightBuffer.label = "Light Information Buffer"
            lightBuffers.append(lightBuffer)
            
            let materialBuffer = Metal.device.newBufferWithLength(ceil(sizeof(MaterialStruct), toNearestMultipleOf: 256) * maxMaterials, options: [])
            materialBuffer.label = "Material Buffer"
            materialBuffers.append(materialBuffer)
        }
    }
    
    func fillMaterialBuffer(buffer: MTLBuffer, materials: [Material], _ materials2: FlattenBidirectionalCollection<[[Material]]>, hdrMaxIntensity: Float) -> [Material : Int] {
        var materialOffsets = [Material : Int]()
        
        let materialBuffer = UnsafeMutablePointer<Void>(buffer.contents())
        let step = ceil(sizeof(MaterialStruct), toNearestMultipleOf: 256)
        var index = 0
        
        for material in materials {
            if materialOffsets[material] != nil { continue }
            
            let materialRef = UnsafeMutablePointer<MaterialStruct>(materialBuffer.advancedBy(index * step))
            materialRef.memory = material.toStruct(hdrMaxIntensity: hdrMaxIntensity)
            
            materialOffsets[material] = index * step
            
            index++
        }
        
        for material in materials2 {
            if materialOffsets[material] != nil { continue }
            
            let materialRef = UnsafeMutablePointer<MaterialStruct>(materialBuffer.advancedBy(index * step))
            materialRef.memory = material.toStruct(hdrMaxIntensity: hdrMaxIntensity)
            
            materialOffsets[material] = index * step
            
            index++
        }
        
        return materialOffsets
    }
    
    func render(meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, fieldOfView: Float, hdrMaxIntensity: Float) {
        if (fieldOfView != _currentFOV) {
            _currentFOV = fieldOfView;
        }
        self.render(meshes, lights: lights, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: _projectionMatrix, hdrMaxIntensity: hdrMaxIntensity)
    }
    
    func render(meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
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
        
        if let renderPassDescriptor = Metal.view.currentRenderPassDescriptor, currentDrawable = Metal.view.currentDrawable
        {
            let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
            renderEncoder.label = "render encoder"
            
            renderEncoder.pushDebugGroup("Drawing meshes")
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setDepthStencilState(depthState)
            renderEncoder.setCullMode(.Front)
            renderEncoder.setDepthClipMode(.Clamp)
            
            let transformationBuffer = UnsafeMutablePointer<Void>(self.transformationBuffers[_currentFrameIndex].contents()) //needs to be typed as void so we offset by bytes
            let transformationBufferStep = ceil(sizeof(ModelMatrices), toNearestMultipleOf: 256)
            
            let lightBuffer = UnsafeMutablePointer<LightBlock>(self.lightBuffers[_currentFrameIndex].contents())
            
            let lightBlock = Light.toLightBlock(lights, worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
            lightBuffer.memory = lightBlock

            renderEncoder.setFragmentBuffer(self.lightBuffers[_currentFrameIndex], offset: 0, atIndex: 0)
            
            let materialBuffer = self.materialBuffers[_currentFrameIndex]
            let materialOffsets = self.fillMaterialBuffer(materialBuffer, materials: meshes.flatMap { $0.materialOverride }, meshes.map({($0 as! MTLMesh).materials}).flatten(), hdrMaxIntensity: hdrMaxIntensity)
        
            for (matricesBufferIndex, mesh) in meshes.enumerate() {
                let transformationBufferOffset = matricesBufferIndex * transformationBufferStep
                let matricesRef = UnsafeMutablePointer<ModelMatrices>(transformationBuffer.advancedBy(transformationBufferOffset))
                
                let modelToCameraMatrix = (worldToCameraMatrix * mesh.worldSpaceTransform)
                matricesRef.memory.modelToCameraMatrix = modelToCameraMatrix.cmatrix
                matricesRef.memory.projectionMatrix = projectionMatrix.cmatrix
                matricesRef.memory.modelToCameraRotationMatrix = modelToCameraMatrix.matrix3.cmatrix
                matricesRef.memory.normalModelToCameraMatrix = modelToCameraMatrix.matrix3.inverse.transpose.cmatrix
              
                renderEncoder.setVertexBuffer(self.transformationBuffers[_currentFrameIndex], offset: transformationBufferOffset, atIndex: 2)
                
                
                (mesh as! MTLMesh).renderWithMaterials(renderEncoder, useMaterial: { (material) -> () in
                    renderEncoder.setFragmentBuffer(materialBuffer, offset: materialOffsets[material]!, atIndex: 1)
                    })
            }
            
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
            
            commandBuffer.presentDrawable(currentDrawable)
        }
        
        commandBuffer.commit()
        
        _currentFrameIndex = (_currentFrameIndex + 1) % MTKForwardRenderer.MaxFrameLag
    }
    

}