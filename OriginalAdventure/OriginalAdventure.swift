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
    var sceneGraph : SceneNode! = nil
    var camera : Camera! = nil
    
    init() {
        
    }
    
    deinit {
        
    }
    
    func setupRendering() {
        self.sceneGraph = try! SceneGraphParser.parseFileAtURL(NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("SceneGraph", ofType: "xml")!), parserExtension: OriginalAdventureSceneGraphParser())
        let spawnPoint = self.sceneGraph.nodeWithID(SpawnPointBehaviour.SpawnPointID).flatMap { $0 as? GameObject }
        let player = spawnPoint?.behaviourOfType(SpawnPointBehaviour)?.spawnPlayerWithId("player")
        self.camera = player?.camera
        self.camera.hdrMaxIntensity = 16
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
        _renderer.render(sceneGraph.allNodesOfType(GameObject),
            lights: sceneGraph.allNodesOfType(Light),
            worldToCameraMatrix: self.camera.worldToNodeSpaceTransform,
            fieldOfView: self.camera.fieldOfView,
            hdrMaxIntensity: self.camera.hdrMaxIntensity)
        
    }
    
}