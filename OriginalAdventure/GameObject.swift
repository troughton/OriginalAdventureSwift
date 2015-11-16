//
//  GameObject.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 20/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Cocoa
import ModelIO

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

struct CollisionNode : Enableable {
    var isEnabled : Bool
}

class GameObject: TransformNode {
    var collisionNode : CollisionNode?
    var light : Light? {
        didSet {
            light?.parent = self
        }
    }
    var meshes = [Mesh]()
    var behaviours = [Behaviour]()
    var camera : Camera?
    
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
    
    func behaviourOfType<B : Behaviour>(type : B.Type) -> B? {
        return self.behaviours.flatMap { $0 as? B }.first
    }
}
