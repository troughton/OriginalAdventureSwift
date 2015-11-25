//
//  MTKDeferredRenderer.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 25/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import MetalKit

class MTLDeferredRenderer : MTLRenderer {
    
    var gBufferPipelineState: MTLRenderPipelineState! = nil
    var depthState: MTLDepthStencilState! = nil
    
    let colourAttachmentFormats = [Metal.view.colorPixelFormat, .RG11B10Float, .BGRA8Unorm, Metal.view.colorPixelFormat]
    var colourTextures = [MTLTexture]()
    var colourAttachments = [MTLRenderPassColorAttachmentDescriptor]()
    
    func setupColourAttachmentsForTexture(texture: MTLTexture, renderPassDescriptor: MTLRenderPassDescriptor) {
        if (colourTextures.first?.width != texture.width) || (colourTextures.first?.height != texture.height) {
            
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.Invalid, width: texture.width, height: texture.height, mipmapped: false)
            textureDescriptor.usage = .RenderTarget
            
            self.colourTextures.removeAll()
            self.colourAttachments.removeAll()
            
            for format in colourAttachmentFormats.dropFirst() {
                textureDescriptor.pixelFormat = format
                let attachmentTexture = Metal.device.newTextureWithDescriptor(textureDescriptor)
                colourTextures.append(attachmentTexture)
                
                let colourAttachmentDescriptor = MTLRenderPassColorAttachmentDescriptor()
                colourAttachmentDescriptor.loadAction = .Clear
                colourAttachmentDescriptor.storeAction = .DontCare
                colourAttachmentDescriptor.texture = attachmentTexture
                self.colourAttachments.append(colourAttachmentDescriptor)
            }
        }
        
        for (i, attachment) in self.colourAttachments.enumerate() {
            renderPassDescriptor.colorAttachments[i + 1] = attachment
        }
    }
    
    override init() {
        super.init()
        
        let defaultLibrary = Metal.device.newDefaultLibrary()!
        let fragmentProgram = defaultLibrary.newFunctionWithName("gBufferFragmentShader")!
        let vertexProgram = defaultLibrary.newFunctionWithName("forwardRendererVertexShader")!
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        
        for (i, format) in colourAttachmentFormats.enumerate() {
            pipelineStateDescriptor.colorAttachments[i].pixelFormat = format
        }
        
        pipelineStateDescriptor.depthAttachmentPixelFormat = Metal.view.depthStencilPixelFormat
        pipelineStateDescriptor.stencilAttachmentPixelFormat = Metal.view.depthStencilPixelFormat
        pipelineStateDescriptor.sampleCount = Metal.view.sampleCount
        pipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(MTLMesh.vertexDescriptor)
        
        do {
            try gBufferPipelineState = Metal.device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error {
            print("Failed to create pipeline state, error \(error)")
            NSApp.terminate(nil)
        }
        
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthWriteEnabled = true
        depthStencilDescriptor.depthCompareFunction = .LessEqual
        self.depthState = Metal.device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
    }
    
    override func preRender(commandBuffer commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable) -> (MTLCommandBuffer, MTLRenderCommandEncoder, MTLDrawable) {
        self.setupColourAttachmentsForTexture(drawable.texture, renderPassDescriptor: renderPassDescriptor)
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderEncoder.label = "render encoder"
        
        renderEncoder.pushDebugGroup("Drawing meshes")
        renderEncoder.setRenderPipelineState(gBufferPipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setCullMode(.Front)
        renderEncoder.setDepthClipMode(.Clamp)
        
        return (commandBuffer, renderEncoder, drawable)
    }
    
    
    override func postRender(commandBuffer commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder, drawable: MTLDrawable) {
        renderEncoder.popDebugGroup()
        
        super.postRender(commandBuffer: commandBuffer, renderEncoder: renderEncoder, drawable: drawable)
        
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
        var textureIndex = 0;
        
        for (matricesBufferIndex, mesh) in meshes.enumerate() {
            let transformationBufferOffset = matricesBufferIndex * transformationBufferStep
            let matricesRef = UnsafeMutablePointer<ModelMatrices>(transformationBuffer.advancedBy(transformationBufferOffset))
            self.setModelMatrices(matricesRef, forMesh: mesh, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: projectionMatrix)
            mtlTransformationBuffer.didModifyRange(NSMakeRange(transformationBufferOffset, sizeof(ModelMatrices)))
            
            renderEncoder.setVertexBufferOffset(transformationBufferOffset, atIndex: 2)
            
            
            (mesh as! MTLMesh).renderWithMaterials(renderEncoder, useMaterial: { (material) -> () in
                
                renderEncoder.setFragmentTexture(material.ambientMap?.texture ??
                    Material.fillTextureWithColour(textureBuffer[textureIndex++], colour: float4(material.ambientColour / hdrMaxIntensity, material.useAmbient ? 1 : 0)),
                    atIndex: 0)
                renderEncoder.setFragmentTexture(material.diffuseMap?.texture ??
                    Material.fillTextureWithColour(textureBuffer[textureIndex++], colour: float4(material.diffuseColour, material.opacity)),
                    atIndex: 1)
                renderEncoder.setFragmentTexture(material.specularityMap?.texture ??
                    Material.fillTextureWithColour(textureBuffer[textureIndex++], colour: float4(material.specularColour, material.specularity)),
                    atIndex: 2)
                renderEncoder.setFragmentTexture(material.normalMap?.texture ?? self.normalTexture, atIndex: 3)
                
            })
        }

    }
}