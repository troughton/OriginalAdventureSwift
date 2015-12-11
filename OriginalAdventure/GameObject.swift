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

struct Collider : Enableable {
    let boundingBox : BoundingBox
    var isEnabled : Bool
    
    func isColliding() -> Bool {
        return false
    }
}

class GameObject: TransformNode {
    var collider : Collider?
    var light : Light? {
        didSet {
            light?.parent = self
        }
    }
    var mesh : Mesh? {
        didSet {
            mesh?.isEnabled = self.isEnabled
            mesh?.worldSpaceTransform = self.nodeToWorldSpaceTransform
        }
    }
    var behaviours = [Behaviour]()
    var camera : Camera?
    
    override var isEnabled : Bool {
        get {
            return super.isEnabled
        }
        set(enabled) {
            super.isEnabled = enabled
            
            mesh?.isEnabled = enabled
            light?.isEnabled = enabled
            collider?.isEnabled = enabled
        }
    }
    
    override func transformDidChange() {
        super.transformDidChange()
        mesh?.worldSpaceTransform = self.nodeToWorldSpaceTransform
    }
    
    func behaviourOfType<B : Behaviour>(type : B.Type) -> B? {
        return self.behaviours.flatMap { $0 as? B }.first
    }
    
    func respondToInteractionsOnMesh(mesh: Mesh) {
        
    }
    
    func makeCollidable() throws {
        
    }
}
