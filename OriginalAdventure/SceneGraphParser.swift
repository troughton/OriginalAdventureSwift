//
//  SceneGraphParser.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 14/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

private enum SceneGraphParserError : ErrorType {
    case UnableToLoadURL(NSURL)
    case ParseFailure
    case MissingAttribute(SceneGraphParser.SceneGraphTag, String)
}

class SceneGraphParser : NSObject {
    
    typealias AfterParseFunction = Void -> Void
    
    private let _sceneGraph : SceneNode
    private var _currentNode : SceneNode
    private var _afterParseFunctions = [AfterParseFunction]()
    
    enum SceneGraphTag : String {
        case TransformNode
        case GameObject
        case Mesh = "MeshNode";
        case Region
        case AmbientLight
        case DirectionalLight
        case PointLight
        case Camera
        case Player
        case Puzzle
        case Container
        case Lever
        case Door
        case Inventory
        case SpawnNode
    }
    
    enum AttributeName : String {
        case Identifier = "id"
    }
    
    private init(sceneGraph : SceneNode) {
        _sceneGraph = sceneGraph
        _currentNode = _sceneGraph
    }
    
    private override convenience init() {
        self.init(sceneGraph: SceneNode(rootNodeWithId: "root"))
    }
    
    private static func parse(withParser parser: NSXMLParser) throws -> SceneNode {
        let delegate = SceneGraphParser()
        parser.delegate = delegate
        guard parser.parse() else { throw SceneGraphParserError.ParseFailure }
        for function in delegate._afterParseFunctions {
            function()
        }
        return delegate._sceneGraph
    }
    
    static func parseFileAtURL(url : NSURL) throws -> SceneNode {
        guard let xmlParser = NSXMLParser(contentsOfURL: url) else {
            throw SceneGraphParserError.UnableToLoadURL(url)
        }
        return try SceneGraphParser.parse(withParser: xmlParser)
    }
}

extension SceneGraphParser {
    func parseTransformNode(id: String, attributes: [String : String]) throws -> TransformNode {
        
        let translation = try Vector3(fromString: attributes["translation"]) ?? Vector3.Zero
        let rotation =  try Quaternion(fromString: attributes["rotation"]) ?? Quaternion.Identity
        let scale = try Vector3(fromString: attributes["scale"]) ?? Vector3.One
        
        let isDynamic = Bool(fromString: attributes["isDynamic"]) ?? false
        
        let node = _sceneGraph.nodeWithID(id) as! TransformNode? ?? TransformNode(id: id, parent: _currentNode, isDynamic: isDynamic, translation: translation, rotation: rotation, scale: scale);
        
        if (node.isDynamic) {
            node.translation = translation;
            node.rotation = rotation;
            node.scale = scale;
            node.parent = _currentNode
        }
        
        return node
    }
    
    func parseMeshNode(id: String, attributes: [String : String]) throws -> GameObject {
        let isCollidable = Bool(fromString: attributes["isCollidable"]) ?? false
        
        guard let fileName = attributes["fileName"] else { throw SceneGraphParserError.MissingAttribute(.Mesh, "fileName") }
        
        let node = try _sceneGraph.nodeWithID(id) as! GameObject? ?? {
            
            let directory = attributes["directory"];
            let textureRepeat = try Vector3(fromString: attributes["textureRepeat"]) ?? Vector3.One
            let materialDirectory = attributes["materialDirectory"]
            let materialFileName = attributes["materialFileName"]
            let materialName = attributes["materialName"]
            let retVal = GameObject(id: id, parent: _currentNode)
            
            var materialOverride : Material? = nil
            if let materialFileName = materialFileName {
               materialOverride = MaterialLibrary.library(inDirectory: materialDirectory, withName: materialFileName).materials[materialName!]
            }
            retVal.meshes = MeshType.meshesFromFile(inDirectory: directory, fileName: fileName).meshes.map({ (var mesh) -> Mesh in
                mesh.textureRepeat = textureRepeat
                mesh.materialOverride = materialOverride
                return mesh
            })
            
            
            return retVal
        }()
        
        if node.isDynamic {
            node.parent = _currentNode
        }
        
        return node
    }
    
    func parseSpawnNode(id: String, attributes : [String : String]) -> GameObject {
        let node = GameObject(id: id, parent: _currentNode)
        _ = SpawnPointBehaviour(gameObject: node)
        return node
    }
    
    func parseAmbientLight(id: String, attributes: [String : String]) throws -> Light {
        
        let isDynamic = Bool(fromString: attributes["isDynamic"]) ?? false
        let colour = try Vector3(fromString: attributes["colour"]) ?? Vector3.One
        let intensity = Float(fromString: attributes["intensity"]) ?? 1.0
        
        let node = _sceneGraph.nodeWithID(id) as! Light? ?? Light(id: id, parent: _currentNode, isDynamic: isDynamic, type: .Ambient, colour: colour, intensity: intensity)
        
        if node.isDynamic {
            node.colour = colour
            node.intensity = intensity
        }
        
        return node
    }
    
    func parsePointLight(id: String, attributes: [String : String]) throws -> Light {
        
        let isDynamic = Bool(fromString: attributes["isDynamic"]) ?? false
        let colour = try Vector3(fromString: attributes["colour"]) ?? Vector3.One
        let intensity = Float(fromString: attributes["intensity"]) ?? 1.0
        guard let falloff = try LightFalloff(fromString: attributes["falloff"]) else { throw SceneGraphParserError.MissingAttribute(.PointLight, "falloff") }
        
        let node = _sceneGraph.nodeWithID(id) as! Light? ?? Light(id: id, parent: _currentNode, isDynamic: isDynamic, type: .Point(falloff), colour: colour, intensity: intensity)
        
        if node.isDynamic {
            node.colour = colour
            node.intensity = intensity
        }
        
        return node;
    }
}

extension SceneGraphParser : NSXMLParserDelegate {
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        do {
            if let tag = SceneGraphTag(rawValue: elementName) {
                print("Found tag \(tag)")
                
                guard let id = attributeDict[AttributeName.Identifier.rawValue] else { throw SceneGraphParserError.MissingAttribute(tag, "id") };
                
                switch tag {
                case .TransformNode:
                    _currentNode = try self.parseTransformNode(id, attributes: attributeDict)
                case .Mesh:
                    _currentNode = try self.parseMeshNode(id, attributes: attributeDict)
                case .SpawnNode:
                    _currentNode = self.parseSpawnNode(id, attributes: attributeDict)
                case .AmbientLight:
                    _currentNode = try self.parseAmbientLight(id, attributes: attributeDict)
                case .PointLight:
                    _currentNode = try self.parsePointLight(id, attributes: attributeDict)
                default:
                    _currentNode = SceneNode(id: id, parent: _currentNode)
                }
            } else {
                _currentNode = SceneNode(id: attributeDict["id"] ?? "n/a", parent: _currentNode)
                print("Warning: Unknown element type \(elementName) encountered")
            }

        } catch let error {
            assertionFailure("Error parsing scene graph: \(error)")
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        _currentNode = _currentNode.parent!
    }
}