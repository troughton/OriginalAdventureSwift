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
    lazy var _renderer : Renderer = GLDeferredRenderer()
    var sceneGraph : SceneNode! = nil
    var camera : Camera! = nil
    var player : PlayerBehaviour! = nil
    
    let input : Input = AdventureGameInput()
    
    private var _viewAngle : (x: Float, y: Float) = (0, 0)
    
    init() {
        
    }
    
    deinit {
        
    }
    
    func setupInput() {
        AdventureGameInput.eventMoveInDirection.filter(self.input).addAction(player.moveInDirection)
    }
    
    func setupRendering() {
        self.sceneGraph = try! SceneGraphParser.parseFileAtURL(NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("SceneGraph", ofType: "xml")!), parserExtension: OriginalAdventureSceneGraphParser())
        let spawnPoint = self.sceneGraph.nodeWithID(SpawnPointBehaviour.SpawnPointID).flatMap { $0 as? GameObject }
        let playerObject = spawnPoint?.behaviourOfType(SpawnPointBehaviour)?.spawnPlayerWithId("player")
        self.player = playerObject?.behaviourOfType(PlayerBehaviour)
        self.camera = playerObject?.camera
        self.camera.hdrMaxIntensity = 16
        
        self.setupInput()
    }
    
    var size : WindowDimension! = nil {
        didSet {
            _renderer.size = size
        }
    }
    
    var sizeInPixels : WindowDimension! = nil {
        didSet {
            _renderer.sizeInPixels = sizeInPixels
        }
    }
    
    func onMouseMove(delta x: Float, _ y: Float) {
        let newX = (_viewAngle.x + x / Settings.MouseSensitivity) % Float(2 * M_PI);
        let newY = (_viewAngle.y + y / Settings.MouseSensitivity) % Float(2 * M_PI);
        _viewAngle = (newX, newY)
    }
    
    func update(delta delta: Double) {
        
        self.player.lookInDirection(_viewAngle.x, angleY: _viewAngle.y)
        
        _renderer.render(sceneGraph.allNodesOfType(GameObject),
            lights: sceneGraph.allNodesOfType(Light),
            worldToCameraMatrix: self.camera.worldToNodeSpaceTransform,
            fieldOfView: self.camera.fieldOfView,
            hdrMaxIntensity: self.camera.hdrMaxIntensity)
        
    }
    
}