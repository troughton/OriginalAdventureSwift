//
//  SceneNode.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 18/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import simd

struct SceneNodeType : Hashable, Equatable {
    let type : SceneNode.Type;
    
    init(type : SceneNode.Type) {
        self.type = type;
    }

    var hashValue : Int {
        return String(self.type).hashValue
    }
}

func ==(lhs: SceneNodeType, rhs: SceneNodeType) -> Bool {
    return lhs.type == rhs.type
}

class SceneNode : Hashable {
    private var _parent : SceneNode?
    var parent : SceneNode? {
        get {
            return _parent
        }
        set(newParent) {
            if let parent = self.parent {
                if parent == newParent {
                    return;
                } else if !self.isDynamic {
                    //throw an exception
                }
                parent.children.removeAtIndex(parent.children.indexOf(self)!)
            }
            
            if let newParent = newParent {
                newParent.children.append(self)
            }
            
            _parent = newParent
        }
    }
    
    var children = [SceneNode]()
    let isDynamic : Bool
    
    var isEnabled : Bool = true
    
    let id : String
    
    var idsToNodes : Reference<[String : SceneNode]>;
    private var _nodesOfType : Reference<[SceneNodeType : [SceneNode]]>
    
    init(rootNodeWithId id : String) {
        self.id = id;
        self.idsToNodes = Reference([String : SceneNode]());
        self.isDynamic = false;
        
        _nodesOfType = Reference([SceneNodeType : [SceneNode]]());
        
        self.idsToNodes.value[id] = self;
        self.parent = nil;
        
    }
    
    init(id : String, parent : SceneNode, isDynamic : Bool = false) {
        self.idsToNodes = parent.idsToNodes
        _nodesOfType = parent._nodesOfType
        
        self.isDynamic = isDynamic || parent.isDynamic
        
        self.id = id
        self.idsToNodes.value[id] = self;
        
        self.parent = parent
        
        self.addNodeWithTypeToDictionary(type: self.dynamicType, node: self)
    }
    
    private func addNodeWithTypeToDictionary<T : SceneNode>(type type : T.Type, node : T) {
        self.withAllNodesOfType(type) { (nodes) -> Void in
            nodes.append(node)
            return
        }
    }
    
    func withAllNodesOfType<T : SceneNode, Result>(type : T.Type, @noescape _ f : (inout [T]) -> Result) -> Result {
        let sceneNodeType = SceneNodeType(type: type);
        let optionalNodes = _nodesOfType.value[sceneNodeType] as! [T]?
        var nodes = optionalNodes ?? [T]()
        let retVal = f(&nodes)
        _nodesOfType.value[sceneNodeType] = nodes;
        return retVal
    }
    
    func allNodesOfType<T : SceneNode>(type : T.Type) -> [T] {
        return self.withAllNodesOfType(type) { (nodes) -> [T] in
            let retVal = nodes
            return retVal
        }
    }
    
    func enabledNodesOfType<T : SceneNode>(type : T.Type) -> [T] {
        return self.withAllNodesOfType(type) { (nodes) -> [T] in
            let retVal = nodes.filter { $0.isEnabled }
            return retVal
        }
    }
    
    var siblings : [SceneNode] {
        if let parent = self.parent {
            return parent.children.filter({ (element) -> Bool in
                element != self
            })
        } else {
            return [];
        }
    }
    
    func transformDidChange() {}
    
    func nodeWithID(id : String) -> SceneNode? {
        return self.idsToNodes.value[id]
    }
    
    func traverse(traversalFunc : SceneNode -> ()) {
        traversalFunc(self)
        for child in self.children {
            child.traverse(traversalFunc)
        }
    }
    
    var positionInWorldSpace : Vector3 {
        return (self.nodeToWorldSpaceTransform * Vector4.ZeroPosition).xyz
    }
    
    var nodeToWorldSpaceTransform : Matrix4 {
        return self.parent?.nodeToWorldSpaceTransform ?? Matrix4.Identity
    }
    
    var worldToNodeSpaceTransform : Matrix4 {
        return self.parent?.worldToNodeSpaceTransform ?? Matrix4.Identity
    }
    
    var hashValue : Int {
        return self.id.hashValue
    }
}

func ==(lhs: SceneNode, rhs: SceneNode) -> Bool {
    return lhs.id == rhs.id
}