//
//  Mesh.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 12/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import GLKit

protocol Mesh : Enableable {
    func renderWithShader(shader: Shader, hdrMaxIntensity: Float)
    func render()
    
    var boundingBox : BoundingBox { get }
    var materialOverride : Material? { get set }
    var textureRepeat : Vector3 { get set }
    var parent : GameObject! { get set }
}

var _loadedMeshes = [String : ([Mesh], BoundingBox)]()

extension Mesh {
    
    private static func loadMaterialsFromOBJAtPath(objPath: String, containingDirectory directory: String?) throws -> [MaterialLibrary] {
        
        var libraries = [MaterialLibrary]()
        
        let objFile = try String(contentsOfFile: objPath)
        
        let scanner = NSScanner(string: objFile)
        
        while scanner.scanUpToString("mtllib", intoString: nil) {
            scanner.scanString("mtllib", intoString: nil)
        
            var fileName : NSString? = nil
            if scanner.scanUpToCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &fileName) {
                libraries.append(MaterialLibrary.library(inDirectory: directory, withName: fileName as! String))
            }
        }
        return libraries
    }
    
    
    static func meshesFromFile(inDirectory directory : String? = nil, fileName: String) -> (meshes: [Mesh], boundingBox: BoundingBox) {
        var meshes = _loadedMeshes[fileName];
        
        if (meshes == nil) {
            autoreleasepool {
                do {
                    var meshesArray = [Mesh]()
                    
                    let path = NSBundle.mainBundle().pathForResource(fileName, ofType: nil, inDirectory: directory)!
                    
                    let materialLibraries = try loadMaterialsFromOBJAtPath(path, containingDirectory: directory)
                    
                    let asset = MDLAsset(URL: NSURL(fileURLWithPath: path), vertexDescriptor: nil, bufferAllocator: GLKMeshBufferAllocator())
                    
                    for mdlObject in (0..<asset.count).map({asset[$0]}) {
                        if let mesh = mdlObject as? MDLMesh {
                            if mesh.vertexDescriptor.attributeNamed(MDLVertexAttributeNormal) == nil {
                                mesh.addNormalsWithAttributeNamed(nil, creaseThreshold: 0.8)
                            }
                            if mesh.vertexDescriptor.attributeNamed(MDLVertexAttributeTangent) == nil && mesh.vertexDescriptor.attributeNamed(MDLVertexAttributeTextureCoordinate) != nil {
                                mesh.addTangentBasisForTextureCoordinateAttributeNamed(MDLVertexAttributeTextureCoordinate, normalAttributeNamed: MDLVertexAttributeNormal, tangentAttributeNamed: MDLVertexAttributeTangent)
                            }
                        }
                    }
                    
                    var mdlMeshes : NSArray? = nil
                    let glkMeshes = try GLKMesh.newMeshesFromAsset(asset, sourceMeshes: &mdlMeshes)
                    
                    for (glkMesh, mdlMesh) in zip(glkMeshes, mdlMeshes!) {
                        
                        meshesArray.append(MeshType(glkMesh: glkMesh, mdlMesh: mdlMesh as! MDLMesh, materialLibraries: materialLibraries))
                    }
                    
                    let tuple = (meshesArray, BoundingBox(minPoint: asset.boundingBox.minBounds, maxPoint: asset.boundingBox.maxBounds))
                    meshes = tuple
                    
                    _loadedMeshes[fileName] = tuple;
                } catch let error {
                    assertionFailure("Error loading mesh with name \(fileName): \(error)")
                }
            }
        }
        
        return meshes!;
    }
}

typealias MeshType = GLMesh