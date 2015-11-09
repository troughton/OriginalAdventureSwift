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
    func renderWithVertexArrays(vertexArrays : VertexArrays)
    func render()
    
    var boundingBox : BoundingBox? { get }
    
}

var _loadedMeshes = [String : Mesh]()

let _bufferAllocator = GLKMeshBufferAllocator()
extension Mesh {
    static func meshFromFile(withPath path : String? = nil, fileName: String) -> Mesh {
        var mesh = _loadedMeshes[fileName];
        
        if (mesh == nil) {
            
            do {
                let asset = MDLAsset(URL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource(fileName, ofType: nil, inDirectory: path)!),
                    vertexDescriptor: nil, bufferAllocator: _bufferAllocator)
            
                var mdlMeshes : NSArray? = nil
            
                let glkMeshes = try GLKMesh.newMeshesFromAsset(asset, sourceMeshes: &mdlMeshes)
            
                mesh = MeshType(mesh: glkMeshes[0], asset: mdlMeshes![0] as! MDLMesh)
            
            } catch let error {
                assertionFailure("Could not load mesh file in directory \(path) named \(fileName): \(error)");
            }
            
            _loadedMeshes[fileName] = mesh;
        }
        
        return mesh!;
    }
}

typealias MeshType = GLMesh<Float, Int>

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
    var mesh : Mesh?
    
    override var isEnabled : Bool {
        get {
            return super.isEnabled
        }
        set(enabled) {
            super.isEnabled = enabled
            
            mesh?.isEnabled = enabled
            light?.isEnabled = enabled
            mesh?.isEnabled = enabled
        }
    }
}
