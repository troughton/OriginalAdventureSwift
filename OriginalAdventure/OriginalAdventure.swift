//
//  OriginalAdventure.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class OriginalAdventure: Game {
 
    var title = "Original Adventure"
    lazy var _renderer : Renderer = GLForwardRenderer()
    var sceneGraph = TransformNode(rootNodeWithId: "root")
    var camera : CameraNode! = nil
    
    init() {
        
    }
    
    deinit {
        
    }
    
    func setupRendering() {
        let cameraTransform = TransformNode(id: "cameraOffset", parent: self.sceneGraph, isDynamic: false, translation: [0, 0, -500], rotation: Quaternion.Identity, scale: Vector3.One)
        self.camera = CameraNode(id: "camera", parent: cameraTransform)
        
        let meshes = MeshType.meshesFromFile(fileName: "Plane.obj")
        let gameObject = GameObject(id: "plane", parent: sceneGraph)
        gameObject.meshes = meshes
    }
    
    var size : WindowDimension! = nil {
        didSet {
            _renderer.size = size
        }
    }
    
    var sizeInPixels : WindowDimension! = nil {
        didSet {
        }
    }
    
    func update(delta delta: Double) {
        _renderer.render(sceneGraph.allNodesOfType(GameObject), lights: [], worldToCameraMatrix: self.camera.worldToNodeSpaceTransform, fieldOfView: self.camera.fieldOfView, hdrMaxIntensity: 1.0)

    }
    
}