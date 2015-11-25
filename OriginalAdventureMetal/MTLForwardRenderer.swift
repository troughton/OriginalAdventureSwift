//
//  MTKForwardRenderer.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import MetalKit


class MTLForwardRenderer : MTLRenderer {
    
    var pipelineState: MTLRenderPipelineState! = nil
    var depthState: MTLDepthStencilState! = nil
    
    override init() {
        super.init()
        
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
    }
    
    override func preRender(commandBuffer commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable) -> (MTLCommandBuffer, MTLRenderCommandEncoder, MTLDrawable) {
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderEncoder.label = "render encoder"
        
        renderEncoder.pushDebugGroup("Drawing meshes")
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setCullMode(.Front)
        renderEncoder.setDepthClipMode(.Clamp)
        return (commandBuffer, renderEncoder, drawable)
    }
    
    override func postRender(commandBuffer commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder, drawable: MTLDrawable) {
       renderEncoder.popDebugGroup()
        super.postRender(commandBuffer: commandBuffer, renderEncoder: renderEncoder, drawable: drawable)
        
    }
    
    var texturesWithColours = [float4 : MTLTexture]()
    func textureWithColour(colour: float4, textureBuffer: [MTLTexture], inout nextTextureIndex: Int) -> MTLTexture {
        var texture = texturesWithColours[colour]
        
        if texture == nil {
            texture = textureBuffer[nextTextureIndex++]
            Material.fillTextureWithColour(texture!, colour: colour)
            texturesWithColours[colour] = texture
        }
        
        return texture!
    }
    
    override func render(commandBuffer commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder, drawable: MTLDrawable, meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
        
        let mtlTransformationBuffer = self.transformationBuffers[currentFrameIndex]
        let transformationBuffer = UnsafeMutablePointer<Void>(mtlTransformationBuffer.contents()) //needs to be typed as void so we offset by bytes
        let transformationBufferStep = ceil(sizeof(ModelMatrices), toNearestMultipleOf: 256)
        
        let mtlLightBuffer = self.lightBuffers[currentFrameIndex]
        let lightBuffer = UnsafeMutablePointer<LightBlock>(mtlLightBuffer.contents())
        
        let lightBlock = Light.toLightBlock(lights, worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
        lightBuffer.memory = lightBlock
        mtlLightBuffer.didModifyRange(NSMakeRange(0, sizeof(LightBlock)))
        
        renderEncoder.setVertexBuffer(self.transformationBuffers[currentFrameIndex], offset: 0, atIndex: 2)
        renderEncoder.setFragmentBuffer(self.lightBuffers[currentFrameIndex], offset: 0, atIndex: 0)
        
        let textureBuffer = self.textureBuffers[currentFrameIndex];
        var nextTextureIndex = 0;
        self.texturesWithColours.removeAll(keepCapacity: true)
        
        for (matricesBufferIndex, mesh) in meshes.enumerate() {
            let transformationBufferOffset = matricesBufferIndex * transformationBufferStep
            let matricesRef = UnsafeMutablePointer<ModelMatrices>(transformationBuffer.advancedBy(transformationBufferOffset))
            self.setModelMatrices(matricesRef, forMesh: mesh, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: projectionMatrix)
            mtlTransformationBuffer.didModifyRange(NSMakeRange(transformationBufferOffset, sizeof(ModelMatrices)))
            
            renderEncoder.setVertexBufferOffset(transformationBufferOffset, atIndex: 2)
            
            (mesh as! MTLMesh).renderWithMaterials(renderEncoder, useMaterial: { (material) -> () in
                
                renderEncoder.setFragmentTexture(material.ambientMap?.texture ??
                    self.textureWithColour(float4(material.ambientColour / hdrMaxIntensity, material.useAmbient ? 1 : 0), textureBuffer: textureBuffer, nextTextureIndex: &nextTextureIndex),
                    atIndex: 0)
                renderEncoder.setFragmentTexture(material.diffuseMap?.texture ??
                    self.textureWithColour(float4(material.diffuseColour, material.opacity), textureBuffer: textureBuffer, nextTextureIndex: &nextTextureIndex),
                    atIndex: 1)
                renderEncoder.setFragmentTexture(material.specularityMap?.texture ??
                    self.textureWithColour(float4(material.specularColour, material.specularity), textureBuffer: textureBuffer, nextTextureIndex: &nextTextureIndex),
                    atIndex: 2)
                renderEncoder.setFragmentTexture(material.normalMap?.texture ?? self.normalTexture, atIndex: 3)
            })
        }
    }
    
    
}