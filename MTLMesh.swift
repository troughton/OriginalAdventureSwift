//
//  MTLMesh.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import MetalKit

extension Mesh {
    
    
    static func meshesFromFile(inDirectory directory : String? = nil, fileName: String) -> [Mesh] {
        var meshes = _loadedMeshes[fileName];
        
        if (meshes == nil) {
            autoreleasepool {
                do {
                    meshes = [Mesh]()
                    
                    let path = NSBundle.mainBundle().pathForResource(fileName, ofType: nil, inDirectory: directory)!
                    
                    let materialLibraries = try MeshType.loadMaterialsFromOBJAtPath(path, containingDirectory: directory)
                    
                    let asset = MDLAsset(URL: NSURL(fileURLWithPath: path), vertexDescriptor: nil, bufferAllocator: MTKMeshBufferAllocator(device: Metal.device))
                    
                    for mdlObject in (0..<asset.count).map({asset[$0]}) {
                        if let mesh = mdlObject as? MDLMesh {
                            if mesh.vertexDescriptor.attributeNamed(MDLVertexAttributeNormal) == nil {
                                mesh.addNormalsWithAttributeNamed(nil, creaseThreshold: 0.8)
                            }
                            if mesh.vertexDescriptor.attributeNamed(MDLVertexAttributeTangent) == nil && mesh.vertexDescriptor.attributeNamed(MDLVertexAttributeTextureCoordinate) != nil {
                                mesh.addTangentBasisForTextureCoordinateAttributeNamed(MDLVertexAttributeTextureCoordinate, normalAttributeNamed: MDLVertexAttributeNormal, tangentAttributeNamed: MDLVertexAttributeTangent)
                            }
                            mesh.vertexDescriptor.setPackedOffsets()
                            mesh.vertexDescriptor.setPackedStrides()
                        }
                    }
                    
                    var mdlMeshes : NSArray? = nil
                    let mtkMeshes = try MTKMesh.newMeshesFromAsset(asset, device: Metal.device, sourceMeshes: &mdlMeshes)
                    
                    for (mtkMesh, mdlMesh) in zip(mtkMeshes, mdlMeshes!) {
                        
                        meshes!.append(MeshType(mtkMesh: mtkMesh, mdlMesh: mdlMesh as! MDLMesh, materialLibraries: materialLibraries))
                    }
                    
                    _loadedMeshes[fileName] = meshes;
                } catch let error {
                    assertionFailure("Error loading mesh with name \(fileName): \(error)")
                }
            }
        }
        
        return meshes!;
    }
}

extension MTKSubmesh {
    func render(commandEncoder: MTLRenderCommandEncoder) {
        commandEncoder.drawIndexedPrimitives(self.primitiveType, indexCount: self.indexCount, indexType: self.indexType, indexBuffer: self.indexBuffer.buffer, indexBufferOffset: self.indexBuffer.offset)
    }
}

struct MTLMesh: Mesh {
    
    static let vertexDescriptor : MDLVertexDescriptor = {
        let vertexDescriptor = MDLVertexDescriptor()
        let positionAttribute = vertexDescriptor.attributes[0] as! MDLVertexAttribute
        positionAttribute.format = .Float3
        positionAttribute.offset = 0
        positionAttribute.bufferIndex = 0
        positionAttribute.name = MDLVertexAttributePosition
        
        let normalAttribute = vertexDescriptor.attributes[1] as! MDLVertexAttribute
        normalAttribute.format = .Float3
        normalAttribute.offset = 12
        normalAttribute.bufferIndex = 0
        normalAttribute.name = MDLVertexAttributeNormal
        
        let textureCoordinate = vertexDescriptor.attributes[2] as! MDLVertexAttribute
        textureCoordinate.format = .Float2
        textureCoordinate.offset = 24
        textureCoordinate.bufferIndex = 0
        textureCoordinate.name = MDLVertexAttributeTextureCoordinate
        
        let tangentAttribute = vertexDescriptor.attributes[3] as! MDLVertexAttribute
        tangentAttribute.format = .Float3
        tangentAttribute.offset = 0
        tangentAttribute.bufferIndex = 1
        tangentAttribute.name = MDLVertexAttributeTangent
        
        let layout = vertexDescriptor.layouts[0] as! MDLVertexBufferLayout
        layout.stride = 32
        let layout2 = vertexDescriptor.layouts[1] as! MDLVertexBufferLayout
        layout2.stride = 12
        
        return vertexDescriptor
    }()
    
    var isEnabled = true
    var materialOverride : Material? = nil
    var textureRepeat = Vector3.One
    var worldSpaceTransform = Matrix4.Identity
    
    let boundingBox : BoundingBox
    let mtkMesh : MTKMesh
    let materials : [Material]
    
    init(mtkMesh: MTKMesh, mdlMesh: MDLMesh, materialLibraries: [MaterialLibrary]) {
        
        self.boundingBox = BoundingBox(minPoint: mdlMesh.boundingBox.minBounds, maxPoint: mdlMesh.boundingBox.maxBounds)
        
        self.mtkMesh = mtkMesh
        self.materials = zip(mtkMesh.submeshes, mdlMesh.submeshes).flatMap({ (mtkSubmesh, mdlSubmesh) -> Material in
            let mdlSubmesh = mdlSubmesh as! MDLSubmesh
            
            let material = (mdlSubmesh.material?.name).flatMap({ (materialName) -> Material? in
                for materialLibrary in materialLibraries {
                    if let material = materialLibrary.materials[materialName] {
                        return material
                    }
                }
                return nil
            }) ?? Material.defaultMaterial
            
            return material
        })
    }
    
    /**
     * Renders using the currently bound material.
     */
    func render(encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(self.mtkMesh.vertexBuffers[0].buffer, offset: self.mtkMesh.vertexBuffers[0].offset, atIndex: 0)
        encoder.setVertexBuffer(self.mtkMesh.vertexBuffers[1].buffer, offset: self.mtkMesh.vertexBuffers[1].offset, atIndex: 1)
        for submesh in mtkMesh.submeshes {
            submesh.render(encoder)
        }
    }
    
    /**
     * Renders using each primitive's own material.
     * @param shader The shader on which to set the materials.
     */
    func renderWithMaterials(encoder: MTLRenderCommandEncoder, useMaterial: (Material) -> ()) {
        if let materialOverride = self.materialOverride {
            useMaterial(materialOverride)
            self.render(encoder)
            return
        }
        
        encoder.setVertexBuffer(self.mtkMesh.vertexBuffers[0].buffer, offset: self.mtkMesh.vertexBuffers[0].offset, atIndex: 0)
        encoder.setVertexBuffer(self.mtkMesh.vertexBuffers[1].buffer, offset: self.mtkMesh.vertexBuffers[1].offset, atIndex: 1)
        for (submesh, material) in zip(mtkMesh.submeshes, materials) {
            useMaterial(material)
            submesh.render(encoder)
        }
    }
}
