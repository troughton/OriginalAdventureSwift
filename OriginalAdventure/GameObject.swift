//
//  GameObject.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 20/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Cocoa
import ModelIO
import GLKit

protocol Enableable {
    var isEnabled : Bool { get set }
}

/**
* This enum describes the different possible sets of data that can be passed to a vertex shader.
* For instance, PositionsAndTextureCoordinates specifies that only the positions and texture coordinates should be passed.
*/
enum VertexArrays {
    case Positions
    case PositionsAndNormals
    case PositionsAndTextureCoordinates
    case PositionsNormalsAndTextureCoordinates
    case PositionsNormalsTextureCoordinatesAndTangents
}

protocol Mesh : Enableable {
    func renderWithShader(shader: Shader, hdrMaxIntensity: Float)
    func render()
    
    var boundingBox : BoundingBox { get }
    
}

var _loadedMeshes = [String : [Mesh]]()

extension Mesh {
    static func meshesFromFile(withPath path : String? = nil, fileName: String) -> [Mesh] {
        var meshes = _loadedMeshes[fileName];
        
            if (meshes == nil) {
                autoreleasepool {
                do {
                    meshes = [Mesh]()
                    let asset = MDLAsset(URL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource(fileName, ofType: nil, inDirectory: path)!), vertexDescriptor: nil, bufferAllocator: GLKMeshBufferAllocator())
                
                    var mdlMeshes : NSArray? = nil
                    let glkMeshes = try GLKMesh.newMeshesFromAsset(asset, sourceMeshes: &mdlMeshes)
                    
                for (glkMesh, mdlMesh) in zip(glkMeshes, mdlMeshes!) {
                    meshes!.append(MeshType(glkMesh: glkMesh, mdlMesh: mdlMesh as! MDLMesh))
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

typealias MeshType = GLMesh

struct CollisionNode : Enableable {
    var isEnabled : Bool
}

class GameObject: SceneNode {
    var collisionNode : CollisionNode?
    var light : Light? {
        didSet {
            light?.parent = self
        }
    }
    var meshes = [Mesh]()
    
    override var isEnabled : Bool {
        get {
            return super.isEnabled
        }
        set(enabled) {
            super.isEnabled = enabled
            
            for var mesh in meshes {
                mesh.isEnabled = enabled
            }
            light?.isEnabled = enabled
            collisionNode?.isEnabled = enabled
        }
    }
}
