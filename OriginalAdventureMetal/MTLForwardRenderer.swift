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
    var pipelineStateNormalMaps: MTLRenderPipelineState! = nil
    var depthState: MTLDepthStencilState! = nil
    
    override init() {
        super.init()
        
        let defaultLibrary = Metal.device.newDefaultLibrary()!
        
        
        let fragmentProgram = defaultLibrary.newFunctionWithName("forwardRendererFragmentShader")!
        
        let fragmentProgramNormalMap = defaultLibrary.newFunctionWithName("forwardRendererFragmentShaderNormalMap")!
        
        let vertexProgram = defaultLibrary.newFunctionWithName("forwardRendererVertexShader")!
        
        let vertexProgramNormalMap = defaultLibrary.newFunctionWithName("forwardRendererVertexShaderNormalMap")!
        
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
        
        pipelineStateDescriptor.vertexFunction = vertexProgramNormalMap
        pipelineStateDescriptor.fragmentFunction = fragmentProgramNormalMap
        
        do {
            try pipelineStateNormalMaps = Metal.device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
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
    
    let transformationBufferStep = ceil(sizeof(ModelMatrices), toNearestMultipleOf: 256)
    let lightBufferSize = ceil(sizeof(LightBlock), toNearestMultipleOf: 256)
    let materialBufferStep = ceil(sizeof(MaterialStruct), toNearestMultipleOf: 256)
    
    override func render(commandBuffer commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder, drawable: MTLDrawable, meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
        
        let mtlTransformationBuffer = self.bufferWithCapacity(transformationBufferStep * meshes.count, label: "Transformation Matrices")
        let transformationBuffer = UnsafeMutablePointer<Void>(mtlTransformationBuffer.contents()) //needs to be typed as void so we offset by bytes
        
        let mtlLightBuffer = self.bufferWithCapacity(lightBufferSize, label: "Light Information")
        let lightBuffer = UnsafeMutablePointer<LightBlock>(mtlLightBuffer.contents())
        
        let lightBlock = Light.toLightBlock(lights, worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
        lightBuffer.memory = lightBlock
        mtlLightBuffer.didModifyRange(NSMakeRange(0, sizeof(LightBlock)))
        
        var numMaterials = 0
        for mesh in meshes {
            numMaterials += (mesh as! MTLMesh).materials.count
            numMaterials += (mesh.materialOverride != nil ? 1 : 0)
        }
        
        let mtlMaterialBuffer = self.bufferWithCapacity(numMaterials * materialBufferStep, label: "Material Buffer")
        
        renderEncoder.setVertexBuffer(mtlTransformationBuffer, offset: 0, atIndex: 2)
        renderEncoder.setFragmentBuffer(mtlLightBuffer, offset: 0, atIndex: 0)
        renderEncoder.setFragmentBuffer(mtlMaterialBuffer, offset: 0, atIndex: 1)
        
        var materialBufferIndex = 0
        
        for (bufferIndex, mesh) in meshes.enumerate() {
            let transformationBufferOffset = bufferIndex * transformationBufferStep
            let matricesRef = UnsafeMutablePointer<ModelMatrices>(transformationBuffer.advancedBy(transformationBufferOffset))
            self.setModelMatrices(matricesRef, forMesh: mesh, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: projectionMatrix)
            mtlTransformationBuffer.didModifyRange(NSMakeRange(transformationBufferOffset, sizeof(ModelMatrices)))
            
            renderEncoder.setVertexBufferOffset(transformationBufferOffset, atIndex: 2)
            
            (mesh as! MTLMesh).renderWithMaterials(renderEncoder, useMaterial: { (material) -> () in
                
                let materialBufferOffset = self.materialBufferStep * materialBufferIndex++
                UnsafeMutablePointer<MaterialStruct>(mtlMaterialBuffer.contents().advancedBy(materialBufferOffset)).memory = material.toStruct(hdrMaxIntensity: hdrMaxIntensity)
                mtlMaterialBuffer.didModifyRange(NSRange(location: materialBufferOffset, length: sizeof(MaterialStruct)))
                renderEncoder.setFragmentBufferOffset(materialBufferOffset, atIndex: 1)
                
                renderEncoder.setFragmentTexture(material.ambientMap?.texture ??
                    self.normalTexture,
                    atIndex: 0)
                renderEncoder.setFragmentTexture(material.diffuseMap?.texture ??
                    self.normalTexture,
                    atIndex: 1)
                renderEncoder.setFragmentTexture(material.specularityMap?.texture ??
                    self.normalTexture,
                    atIndex: 2)
                
                if material.normalMap != nil {
                    renderEncoder.setRenderPipelineState(self.pipelineStateNormalMaps)
                    renderEncoder.setFragmentTexture(material.normalMap?.texture ?? self.normalTexture, atIndex: 3)
                } else {
                    renderEncoder.setRenderPipelineState(self.pipelineState)
                }
                
            })
        }
    }
    
    
}