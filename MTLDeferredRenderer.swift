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
    
    static let quadVerts : [Float] =
    [
        -1.0, 1.0,
        1.0, -1.0,
        -1.0, -1.0,
        -1.0, 1.0,
        1.0, 1.0,
        1.0, -1.0
    ];
    
    let quadBuffer = Metal.device.newBufferWithBytes(MTLDeferredRenderer.quadVerts, length: sizeof(Float) * quadVerts.count, options: [.StorageModeManaged])
    
    // set up icosahedron for point lights
    static let X : Float = 0.5 / 0.755761314076171;
    static let Z : Float = X * (1.0 + sqrtf(5.0)) / 2.0;
    static let lightVData : [Float] =
    [
    -X, 0.0, Z, 1.0,
    X, 0.0, Z, 1.0,
    -X, 0.0, -Z, 1.0,
    X, 0.0, -Z, 1.0,
    0.0, Z, X, 1.0,
    0.0, Z, -X, 1.0,
    0.0, -Z, X, 1.0,
    0.0, -Z, -X, 1.0,
    Z, X, 0.0, 1.0,
    -Z, X, 0.0, 1.0,
    Z, -X, 0.0, 1.0,
    -Z, -X, 0.0, 1.0
    ];
    
    static let lightVIndices : [UInt16] =
    [
    0, 1, 4,
    0, 4, 9,
    9, 4, 5,
    4, 8, 5,
    4, 1, 8,
    8, 1, 10,
    8, 10, 3,
    5, 8, 3,
    5, 3, 2,
    2, 3, 7,
    7, 3, 10,
    7, 10, 6,
    7, 6, 11,
    11, 6, 0,
    0, 6, 1,
    6, 10, 1,
    9, 11, 0,
    9, 2, 11,
    9, 5, 2,
    7, 11, 2
    ];
    
    let lightVertexBuffer = Metal.device.newBufferWithBytes(MTLDeferredRenderer.lightVData, length: sizeof(float4) * MTLDeferredRenderer.lightVData.count, options: [.StorageModeManaged])
    let lightIndexBuffer = Metal.device.newBufferWithBytes(MTLDeferredRenderer.lightVIndices, length: sizeof(Int) * MTLDeferredRenderer.lightVIndices.count, options: [.StorageModeManaged])
    
    var geometryPassPipelineState: MTLRenderPipelineState! = nil
    var pointLightStencilPassPipelineState: MTLRenderPipelineState! = nil
    var pointLightColourPassPipelineState: MTLRenderPipelineState! = nil
    var compositionPassPipelineState: MTLRenderPipelineState! = nil
    
    var geometryPassDepthState: MTLDepthStencilState! = nil
    var pointLightStencilPassDepthState: MTLDepthStencilState! = nil
    var pointLightColourPassDepthState: MTLDepthStencilState! = nil
    var compositionPassDepthState: MTLDepthStencilState! = nil
    
    let colourAttachmentFormats = [Metal.view.colorPixelFormat, .BGRA8Unorm, .BGRA8Unorm ] //lighting, normal, diffuse
    var colourTextures = [MTLTexture]()
    var colourAttachments = [MTLRenderPassColorAttachmentDescriptor]()
    
    func setupColourAttachmentsForTexture(texture: MTLTexture, renderPassDescriptor: MTLRenderPassDescriptor) {
        if (colourTextures.first?.width != texture.width) || (colourTextures.first?.height != texture.height) {
            
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.Invalid, width: texture.width, height: texture.height, mipmapped: false)
            textureDescriptor.usage = [.RenderTarget, .ShaderRead]
            
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
        let geometryFragmentFunction = defaultLibrary.newFunctionWithName("gBufferFragmentShader")!
        let geometryVertexFunction = defaultLibrary.newFunctionWithName("forwardRendererVertexShader")!
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        
        pipelineStateDescriptor.label = "GBuffer Render"
        pipelineStateDescriptor.vertexFunction = geometryVertexFunction
        pipelineStateDescriptor.fragmentFunction = geometryFragmentFunction
        
        for (i, format) in colourAttachmentFormats.enumerate() {
            pipelineStateDescriptor.colorAttachments[i].pixelFormat = format
        }
        
        pipelineStateDescriptor.depthAttachmentPixelFormat = Metal.view.depthStencilPixelFormat
        pipelineStateDescriptor.stencilAttachmentPixelFormat = Metal.view.depthStencilPixelFormat
        pipelineStateDescriptor.sampleCount = Metal.view.sampleCount
        pipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(MTLMesh.vertexDescriptor)
        
        do {
            try geometryPassPipelineState = Metal.device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error {
            print("Failed to create geometry pipeline state, error \(error)")
            NSApp.terminate(nil)
        }
        
        
        
        
        
        pipelineStateDescriptor.label = "Point Light Mask Render"
        
        let pointLightVertex = defaultLibrary.newFunctionWithName("pointLightVertex")!
        
        pipelineStateDescriptor.vertexFunction = pointLightVertex
        pipelineStateDescriptor.fragmentFunction = nil
        
        
        let sphereDescriptor  = MTLVertexDescriptor()
        sphereDescriptor.attributes[0].format = .Float4
        sphereDescriptor.layouts[0].stride = sizeof(float4);
        pipelineStateDescriptor.vertexDescriptor = sphereDescriptor
        
        for i in 0..<colourAttachmentFormats.count {
            pipelineStateDescriptor.colorAttachments[i].writeMask = .None
        }
        
        do {
            try pointLightStencilPassPipelineState = Metal.device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error {
            print("Failed to create light stencil pass pipeline state, error \(error)")
            NSApp.terminate(nil)
        }
        
        
        pipelineStateDescriptor.label = "Point Light Colour Render"
        
        let lightFragment = defaultLibrary.newFunctionWithName("lightFrag")!
        
        pipelineStateDescriptor.fragmentFunction = lightFragment
        
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .One
        pipelineStateDescriptor.colorAttachments[0].writeMask = .All
        
        
        do {
            try pointLightColourPassPipelineState = Metal.device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error {
            print("Failed to create light colour pass pipeline state, error \(error)")
            NSApp.terminate(nil)
        }
        
        
        
        
        let compositionVertex = defaultLibrary.newFunctionWithName("compositionVertex")!
        
        pipelineStateDescriptor.vertexFunction = compositionVertex
        pipelineStateDescriptor.fragmentFunction = lightFragment
        
        let quadDescriptor  = MTLVertexDescriptor()
        quadDescriptor.attributes[0].format = .Float2
        quadDescriptor.layouts[0].stride = sizeof(float2);
        pipelineStateDescriptor.vertexDescriptor = quadDescriptor
        
        do {
            try compositionPassPipelineState = Metal.device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
        } catch let error {
            print("Failed to create geometry pipeline state, error \(error)")
            NSApp.terminate(nil)
        }
        
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthWriteEnabled = true
        depthStencilDescriptor.depthCompareFunction = .LessEqual
        self.geometryPassDepthState = Metal.device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
        
        
        depthStencilDescriptor.depthWriteEnabled = false
        
        let stencilState = MTLStencilDescriptor()
        
        stencilState.stencilCompareFunction = .Equal;
        stencilState.stencilFailureOperation = .Keep;
        stencilState.depthFailureOperation = .IncrementWrap;
        stencilState.depthStencilPassOperation = .Keep;
        depthStencilDescriptor.backFaceStencil = stencilState;
        
        stencilState.depthFailureOperation = .DecrementWrap
        depthStencilDescriptor.frontFaceStencil = stencilState
        
        self.pointLightStencilPassDepthState = Metal.device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
        
        stencilState.stencilCompareFunction = .NotEqual
        stencilState.stencilFailureOperation = .Zero
        stencilState.depthFailureOperation = .Zero
        stencilState.depthStencilPassOperation = .Zero
        depthStencilDescriptor.frontFaceStencil = stencilState
        depthStencilDescriptor.backFaceStencil = stencilState
        
        self.pointLightColourPassDepthState = Metal.device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
        
        depthStencilDescriptor.depthCompareFunction = .Always
        stencilState.stencilCompareFunction = .Always
        depthStencilDescriptor.frontFaceStencil = stencilState
        depthStencilDescriptor.backFaceStencil = stencilState
        self.compositionPassDepthState = Metal.device.newDepthStencilStateWithDescriptor(depthStencilDescriptor)
    }
    
    override func preRender(commandBuffer commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, drawable: CAMetalDrawable) -> (MTLCommandBuffer, MTLRenderCommandEncoder, MTLDrawable) {
        self.setupColourAttachmentsForTexture(drawable.texture, renderPassDescriptor: renderPassDescriptor)
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderEncoder.label = "render encoder"
        
        return (commandBuffer, renderEncoder, drawable)
    }
    
    
    override func postRender(commandBuffer commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder, drawable: MTLDrawable) {
        super.postRender(commandBuffer: commandBuffer, renderEncoder: renderEncoder, drawable: drawable)
        
    }
    
    static let meshBufferSizePerElement = ceil(sizeof(ModelMatrices), toNearestMultipleOf: 256)
    static let lightBufferSizePerElement = ceil(sizeof(LightBlock), toNearestMultipleOf: 256)
    
    func performGeometryPass(renderEncoder: MTLRenderCommandEncoder, meshes: [Mesh], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, ambientMaxIntensity : Float) {
        renderEncoder.pushDebugGroup("Geometry Pass")
        renderEncoder.setRenderPipelineState(self.geometryPassPipelineState)
        renderEncoder.setDepthStencilState(self.geometryPassDepthState)
        renderEncoder.setCullMode(.Front)
        renderEncoder.setDepthClipMode(.Clamp)
        
        let mtlTransformationBuffer = self.bufferWithCapacity(MTLDeferredRenderer.meshBufferSizePerElement * meshes.count, label: "Transformation Matrices")
        let transformationBuffer = UnsafeMutablePointer<Void>(mtlTransformationBuffer.contents()) //needs to be typed as void so we offset by bytes
        let transformationBufferStep = MTLDeferredRenderer.meshBufferSizePerElement
        
        renderEncoder.setVertexBuffer(mtlTransformationBuffer, offset: 0, atIndex: 2)
        
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
                    Material.fillTextureWithColour(textureBuffer[textureIndex++], colour: float4(material.ambientColour / ambientMaxIntensity, material.useAmbient ? 1 : 0)),
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
        
        renderEncoder.popDebugGroup()
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
    
    func performPointLightPass(encoder: MTLRenderCommandEncoder, lights : [Light], worldToCameraMatrix : Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity : Float) {
        
        encoder.pushDebugGroup("Point Lights")
        
        let pointLights = lights.filter { (light) -> Bool in
                switch light.type {
                case .Point(_):
                    return true
                default:
                    return false
            }

        }
        
        encoder.setStencilReferenceValue(0xFF)
        
        let lightTransformationStep = ceil(sizeof(float4x4), toNearestMultipleOf: 256)
        let lightTransformationBuffer = self.bufferWithCapacity(lightTransformationStep * pointLights.count, label: "Light Transformation Matrices")
        
        let lightDataStep = ceil(sizeof(LightBlock), toNearestMultipleOf: 256)
        let lightDataBuffer = self.bufferWithCapacity(lightDataStep * pointLights.count, label: "Per Light Information")
        
        for (i, light) in pointLights.enumerate() {
            let lightToCameraMatrix = self.calculatePointLightSphereToCameraTransform(light: light, worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
            let lightToClipMatrix = projectionMatrix * lightToCameraMatrix
            UnsafeMutablePointer<float4x4>(lightTransformationBuffer.contents().advancedBy(i * lightTransformationStep)).memory = lightToClipMatrix
            
            UnsafeMutablePointer<LightBlock>(lightDataBuffer.contents().advancedBy(i * lightDataStep)).memory = Light.toLightBlock([light], worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
        }
        lightTransformationBuffer.didModifyRange(NSRange(location: 0, length: pointLights.count * lightTransformationStep))
        lightDataBuffer.didModifyRange(NSRange(location: 0, length: pointLights.count * lightDataStep))
        
        encoder.setVertexBuffer(self.lightVertexBuffer, offset: 0, atIndex: 0)
        encoder.setVertexBuffer(lightTransformationBuffer, offset: 0, atIndex: 2)
        encoder.setFragmentBuffer(lightDataBuffer, offset: 0, atIndex: 0)
        
        for i in 0..<pointLights.count {
            
            encoder.pushDebugGroup("Light Stencil")
            
            encoder.setFragmentBufferOffset(i * lightDataStep, atIndex: 0)
            
            encoder.setCullMode(.Front)
            
            encoder.setRenderPipelineState(self.pointLightStencilPassPipelineState)
            encoder.setDepthStencilState(self.pointLightStencilPassDepthState)
            
            encoder.setVertexBufferOffset(i * lightTransformationStep, atIndex: 2)
            encoder.drawIndexedPrimitives(.Triangle, indexCount: 60, indexType: .UInt16, indexBuffer: self.lightIndexBuffer, indexBufferOffset: 0)
            
            encoder.popDebugGroup()
            
            encoder.pushDebugGroup("Light Volume")
            
            encoder.setCullMode(.Back)
            
            encoder.setRenderPipelineState(self.pointLightColourPassPipelineState)
            encoder.setDepthStencilState(self.pointLightColourPassDepthState)
            
            encoder.setFragmentBufferOffset(lightDataStep * i, atIndex: 0)
            encoder.drawIndexedPrimitives(.Triangle, indexCount: 60, indexType: .UInt16, indexBuffer: self.lightIndexBuffer, indexBufferOffset: 0)
            
            encoder.popDebugGroup()
        }
        
        encoder.popDebugGroup()
    }

    
    func performDirectionalLightPass(renderEncoder: MTLRenderCommandEncoder, lights: [Light], worldToCameraMatrix : Matrix4, hdrMaxIntensity : Float) {
        renderEncoder.pushDebugGroup("Composition Pass")
        
        renderEncoder.setRenderPipelineState(self.compositionPassPipelineState)
        renderEncoder.setCullMode(.None)
        
        let filteredLights = lights.filter { (light) -> Bool in
            switch light.type {
            case .Ambient:
                return true
            case .Directional(_):
                return true
            default:
                return false
            }
        }
        
        let mtlLightBuffer = self.bufferWithCapacity(sizeof(LightBlock), label: "Directional Light Block")
        let lightBuffer = UnsafeMutablePointer<LightBlock>(mtlLightBuffer.contents())
        
        let lightBlock = Light.toLightBlock(filteredLights, worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
        lightBuffer.memory = lightBlock
        mtlLightBuffer.didModifyRange(NSMakeRange(0, sizeof(LightBlock)))
        
        renderEncoder.setFragmentBuffer(mtlLightBuffer, offset: 0, atIndex: 0)
        
        renderEncoder.setDepthStencilState(self.compositionPassDepthState)
        
        //Need to enable blending.
        var i = 0
        for texture in self.colourTextures {
            renderEncoder.setFragmentTexture(texture, atIndex: i)
            i++
        }
        renderEncoder.setFragmentTexture(Metal.view.depthStencilTexture, atIndex: i)
        
        renderEncoder.setVertexBuffer(self.quadBuffer, offset: 0, atIndex: 0)
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.popDebugGroup()
    }
    
    override func render(commandBuffer commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder, drawable: MTLDrawable, meshes: [Mesh], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float) {
        
        self.performGeometryPass(renderEncoder, meshes: meshes, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: projectionMatrix, ambientMaxIntensity: hdrMaxIntensity)
        
        var halfSizeNearPlane = self.computeHalfSizeNearPlane(zNear: MTLRenderer.CameraNear, windowDimensions: self.sizeInPixels, projectionMatrix: projectionMatrix)
        renderEncoder.setVertexBytes(&halfSizeNearPlane, length: sizeof(float2), atIndex: 1)
        
        var depthRange = float2(Float(MTLRenderer.DepthRangeNear), Float(MTLRenderer.DepthRangeFar))
        renderEncoder.setFragmentBytes(&depthRange, length: sizeof(float2), atIndex: 1)
        
        var matrixTerms = float3(projectionMatrix[3][2], projectionMatrix[2][3], projectionMatrix[2][2]);
        renderEncoder.setFragmentBytes(&matrixTerms, length: sizeof(float3), atIndex: 2)
        
     // self.performPointLightPass(renderEncoder, lights: lights, worldToCameraMatrix: worldToCameraMatrix, projectionMatrix: projectionMatrix, hdrMaxIntensity: hdrMaxIntensity)
        
        self.performDirectionalLightPass(renderEncoder, lights: lights, worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity)
    }
    
    func computeHalfSizeNearPlane(zNear zNear: Float, windowDimensions : WindowDimension, projectionMatrix: Matrix4) -> float2 {
        let cameraAspect = windowDimensions.aspect;
        let tanHalfFoV = 1/(projectionMatrix[0][0] * cameraAspect);
        let y = tanHalfFoV * zNear;
        let x = y * cameraAspect;
        return float2(x, y)
    }
   
}