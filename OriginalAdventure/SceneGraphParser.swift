//
//  SceneGraphParser.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 14/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

enum SceneGraphParserError : ErrorType {
    case UnableToLoadURL(NSURL)
    case ParseFailure
    case MissingAttribute(String, String)
    case InvalidAttribute(String)
}

protocol SceneGraphParserExtension {
    func parseElement(element elementName: String, withID id: String?, attributes attributeDict: [String : String], parent: SceneNode, sceneGraphParser: SceneGraphParser) throws -> SceneNode
    
    func isNodeType(elementName: String) -> Bool
}

class SceneGraphParserDefaultExtension : SceneGraphParserExtension {
    func parseElement(element elementName: String, withID id: String?, attributes attributeDict: [String : String], parent: SceneNode, sceneGraphParser: SceneGraphParser) -> SceneNode {
        return SceneNode(id: id ?? "", parent: parent)
    }
    
    func isNodeType(elementName: String) -> Bool {
        return false
    }
}

class SceneGraphParser : NSObject {
    
    typealias AfterParseFunction = Void -> Void
    
    private let _sceneGraph : SceneNode
    private var _currentNode : SceneNode
    private var _afterParseFunctions = [AfterParseFunction]()
    
    private let _parserExtension : SceneGraphParserExtension
    
    enum SceneGraphTag : String {
        case TransformNode
        case GameObject
        case Mesh = "MeshNode";
        case AmbientLight
        case DirectionalLight
        case PointLight
        case Camera
        case Behaviour
        case Root = "root"
        
        var isNodeType : Bool {
            switch self {
            case .Behaviour:
                return false
            case .Root:
                return false
            default:
                return true
            }
        }
    }
    
    enum AttributeName : String {
        case Identifier = "id"
    }
    
    private init(sceneGraph : SceneNode, parserExtension : SceneGraphParserExtension = SceneGraphParserDefaultExtension()) {
        _sceneGraph = sceneGraph
        _currentNode = _sceneGraph
        
        _parserExtension = parserExtension
        
    }
    
    private convenience init(parserExtension : SceneGraphParserExtension = SceneGraphParserDefaultExtension()) {
        self.init(sceneGraph: SceneNode(rootNodeWithId: "root"), parserExtension: parserExtension)
    }
    
    private static func parse(withParser parser: NSXMLParser, parserExtension : SceneGraphParserExtension) throws -> SceneNode {
        let delegate = SceneGraphParser(parserExtension: parserExtension)
        parser.delegate = delegate
        guard parser.parse() else { throw SceneGraphParserError.ParseFailure }
        for function in delegate._afterParseFunctions {
            function()
        }
        return delegate._sceneGraph
    }
    
    static func parseFileAtURL(url : NSURL, parserExtension : SceneGraphParserExtension = SceneGraphParserDefaultExtension()) throws -> SceneNode {
        guard let xmlParser = NSXMLParser(contentsOfURL: url) else {
            throw SceneGraphParserError.UnableToLoadURL(url)
        }
        return try SceneGraphParser.parse(withParser: xmlParser, parserExtension: parserExtension)
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
    
    func meshFromAttributes(attributes: [String : String]) throws -> Mesh? {
        
        guard let fileName = attributes["fileName"] else { throw SceneGraphParserError.MissingAttribute("Mesh", "fileName") }
        
        let directory = attributes["directory"];
        let textureRepeat = try Vector3(fromString: attributes["textureRepeat"]) ?? Vector3.One
        let materialDirectory = attributes["materialDirectory"]
        let materialFileName = attributes["materialFileName"]
        let materialName = attributes["materialName"]
        
        var materialOverride : Material? = nil
        if let materialFileName = materialFileName {
            materialOverride = MaterialLibrary.library(inDirectory: materialDirectory, withName: materialFileName).materials[materialName!]
        }
        return MeshType.meshesFromFile(inDirectory: directory, fileName: fileName).meshes.first.flatMap({ (var mesh) -> Mesh in
            mesh.textureRepeat = textureRepeat
            mesh.materialOverride = materialOverride
            return mesh
        })
    }
    
    func parseMeshNode(id: String, attributes: [String : String], parent: SceneNode) throws -> GameObject {
        let isCollidable = Bool(fromString: attributes["isCollidable"]) ?? false
        
        let node = try _sceneGraph.nodeWithID(id) as! GameObject? ?? {
            let retVal = GameObject(id: id, parent: parent)
            retVal.mesh = try self.meshFromAttributes(attributes)
            return retVal
        }()
        
        if node.isDynamic {
            node.parent = _currentNode
        }
        
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
    
    func parsePointLight(id: String, attributes: [String : String], parent: SceneNode) throws -> Light {
        
        let isDynamic = Bool(fromString: attributes["isDynamic"]) ?? false
        let colour = try Vector3(fromString: attributes["colour"]) ?? Vector3.One
        let intensity = Float(fromString: attributes["intensity"]) ?? 1.0
        let falloff = try LightFalloff(fromString: attributes["falloff"]) ?? LightFalloff.Quadratic
        
        let node = _sceneGraph.nodeWithID(id) as! Light? ?? Light(id: id, parent: parent, isDynamic: isDynamic, type: .Point(falloff), colour: colour, intensity: intensity)
        
        if node.isDynamic {
            node.colour = colour
            node.intensity = intensity
        }
        
        return node;
    }
    
    func parseDirectionalLight(id: String, attributes: [String : String]) throws -> Light {
        let isDynamic = Bool(fromString: attributes["isDynamic"]) ?? false
        let colour = try Vector3(fromString: attributes["colour"]) ?? Vector3.One
        let intensity = Float(fromString: attributes["intensity"]) ?? 1.0
        
        guard let fromDirection = try Vector3(fromString: attributes["fromDirection"]) else { throw SceneGraphParserError.MissingAttribute("DirectionalLight", "fromDirectional") }
        
        let node = _sceneGraph.nodeWithID(id) as! Light? ?? Light(id: id, parent: _currentNode, isDynamic: isDynamic, type: .Directional(fromDirection), colour: colour, intensity: intensity)
        
        if node.isDynamic {
            node.colour = colour
            node.intensity = intensity
        }
        
        return node;

    }
    
    func parseCamera(id: String, attributes: [String : String]) throws -> Camera {
        let camera = _sceneGraph.nodeWithID(id) as! Camera? ?? Camera(id: id, parent: _currentNode)
        
        if let fieldOfView = Float(fromString: attributes["fieldOfView"]) {
            camera.fieldOfView = fieldOfView
        }
        if let hdrMaxIntensity = Float(fromString: attributes["hdrMaxIntensity"]) {
            camera.hdrMaxIntensity = hdrMaxIntensity
        }
        return camera
    }
    
    func parseGameObject(id: String, attributes: [String : String]) -> GameObject {
        return GameObject(id: id, parent: _currentNode)
    }
    
    func parseBehaviour(attributes attributes: [String : String]) throws -> Behaviour {
        throw SceneGraphParserError.InvalidAttribute("behaviourName")
    }
}

extension SceneGraphParser : NSXMLParserDelegate {
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        do {
            let id = attributeDict[AttributeName.Identifier.rawValue]
            
            if let tag = SceneGraphTag(rawValue: elementName) {
                
                if tag.isNodeType {
                    guard id != nil else { throw SceneGraphParserError.MissingAttribute(elementName, "id") };
                }
                
                switch tag {
                case .TransformNode:
                    _currentNode = try self.parseTransformNode(id!, attributes: attributeDict)
                case .Mesh:
                    _currentNode = try self.parseMeshNode(id!, attributes: attributeDict, parent: _currentNode)
                case .AmbientLight:
                    _currentNode = try self.parseAmbientLight(id!, attributes: attributeDict)
                case .PointLight:
                    _currentNode = try self.parsePointLight(id!, attributes: attributeDict, parent: _currentNode)
                case .DirectionalLight:
                    _currentNode = try self.parseDirectionalLight(id!, attributes: attributeDict)
                case .Camera:
                    _currentNode = try self.parseCamera(id!, attributes: attributeDict)
                case .GameObject:
                    _currentNode = self.parseGameObject(id!, attributes: attributeDict)
                case .Behaviour:
                    try self.parseBehaviour(attributes: attributeDict)
                case .Root:
                    break
                }
            } else {
                _currentNode = try _parserExtension.parseElement(element: elementName, withID: id, attributes: attributeDict, parent: _currentNode, sceneGraphParser: self)
            }

        } catch let error {
            assertionFailure("Error parsing scene graph: \(error)")
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let isNodeType : Bool
        if let tag = SceneGraphTag(rawValue: elementName) {
            isNodeType = tag.isNodeType
        } else {
            isNodeType = _parserExtension.isNodeType(elementName)
        }
        if isNodeType {

            _currentNode = _currentNode.parent!
        }
    }
}