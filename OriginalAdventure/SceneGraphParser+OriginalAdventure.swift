//
//  SceneGraphParser+OriginalAdventure.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 15/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class OriginalAdventureSceneGraphParser : SceneGraphParserExtension {
    enum SceneGraphTag : String {
        case Region
        case Player
        case Puzzle
        case Container
        case Lever
        case Door
        case Inventory
        case SpawnNode
        case Key
        case Chest
        case FlickeringLight
        case Note
    }
    
    func isNodeType(elementName: String) -> Bool {
        return true
    }
    
    func parseElement(element elementName: String, withID id: String?, attributes attributeDict: [String : String], parent: SceneNode, sceneGraphParser: SceneGraphParser) throws -> SceneNode {
        
        guard let id = id else { throw SceneGraphParserError.MissingAttribute(elementName, "id") }
        if let tag = SceneGraphTag(rawValue: elementName) {
            
            switch tag {
            case .SpawnNode:
                return self.parseSpawnNode(id, parent: parent, attributes: attributeDict)
            case .FlickeringLight:
                return try self.parseFlickeringLight(id, parent: parent, attributes: attributeDict, sceneGraphParser: sceneGraphParser)
            case .Chest:
                return self.parseChest(id, parent: parent, attributes: attributeDict)
            default:
                return SceneNode(id: id, parent: parent)
            }
        } else {
            assertionFailure("Unimplemented element type \(elementName) for id \(id)")
            return SceneNode(id: id, parent: parent)
        }
    }
    
    func parseSpawnNode(id: String, parent: SceneNode, attributes : [String : String]) -> GameObject {
        let node = GameObject(id: id, parent: parent)
        _ = SpawnPointBehaviour(gameObject: node)
        return node
    }
    
    func parseFlickeringLight(id: String, parent: SceneNode, attributes : [String : String], sceneGraphParser: SceneGraphParser) throws -> GameObject {
        
        let flickeringLight = parent.nodeWithID(id) as! GameObject? ?? GameObject(id: id, parent: parent, isDynamic: true)
        
        flickeringLight.mesh = try sceneGraphParser.meshFromAttributes(attributes)
        flickeringLight.light = try sceneGraphParser.parsePointLight(id + "PointLight", attributes: attributes, parent: flickeringLight)
        
        let intensityVariation = Float(fromString: attributes["intensityVariation"]) ?? 0.0
        let isOn = Bool(fromString: attributes["isOn"]) ?? true
        
        let flickeringLightBehaviour = FlickeringLightBehaviour(gameObject: flickeringLight)
        flickeringLightBehaviour.intensityVariation = intensityVariation
        flickeringLightBehaviour.isOn = isOn
        
        return flickeringLight;
    }
    
    func parseChest(id: String, parent: SceneNode, attributes: [String : String]) -> GameObject {
        
        let chestObject = parent.nodeWithID(id) as! GameObject? ?? GameObject(id: id, parent: parent, isDynamic: true)
        
        let chestMesh = MeshType.meshesFromFile(inDirectory: "Chest", fileName: "Chest.obj").first
        chestObject.mesh = chestMesh
        chestObject.respondToInteractionsOnMesh(chestMesh!)
        
        try! chestObject.makeCollidable()
        
        let closedRotation = Quaternion(angle: Float(M_PI / 180.0 * 68.0), axis: 1, 0, 0)
        
        let hingeOffset = Vector3(0, chestMesh!.boundingBox.height - 0.05, 0);
        
        let hingeId = id + "ChestHinge";
        
        let hingeTransform = chestObject.nodeWithID(hingeId) as! TransformNode? ?? TransformNode(id: hingeId, parent: chestObject, isDynamic: true, translation: hingeOffset, rotation: closedRotation)
        
        let lidId = id + "ChestLid";
        let lidObject = hingeTransform.nodeWithID(lidId) as! GameObject? ?? GameObject(id: lidId, parent: hingeTransform, isDynamic: true, translation: -hingeOffset)
        
        let lidMesh = MeshType.meshesFromFile(inDirectory: "Chest", fileName: "ChestLid.obj").first
        lidObject.mesh = lidMesh
        chestObject.respondToInteractionsOnMesh(lidMesh!)
        
        _ = OpenCloseBehaviour(gameObject: chestObject, hinge: hingeTransform, openRotation: Quaternion.Identity, closedRotation: closedRotation)
        
        return chestObject
    }
}