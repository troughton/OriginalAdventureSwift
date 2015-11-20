//
//  TransformNode.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 18/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import simd

class TransformNode : SceneNode {
    
    override var parent : SceneNode? {
        willSet(newParent) {
            if parent != nil && parent != newParent {
                self.checkForModificationOfStaticNode()
            }
        }
        didSet {
            self.transformDidChange()
        }
    }
 
    var translation : Vector3 {
        willSet {
            self.checkForModificationOfStaticNode()
        }
        didSet {
            self.setNeedsRecalculateTransform()
        }
    }
    var rotation : Quaternion {
        willSet {
            self.checkForModificationOfStaticNode()
        }
        didSet {
            self.setNeedsRecalculateTransform()
        }
    }
    var scale : Vector3 {
        willSet {
            self.checkForModificationOfStaticNode()
        }
        didSet {
            self.setNeedsRecalculateTransform()
        }
    }
    
    private var _nodeToWorldTransform : Matrix4?; //formed by translating, scaling, then rotating.
    private var _worldToNodeTransform : Matrix4?;

    override init(rootNodeWithId id: String) {
        self.translation = Vector3.Zero;
        self.rotation = Quaternion.Identity;
        self.scale = Vector3.One;
        
        super.init(rootNodeWithId: id);
    }
    
    init(id: String, parent: SceneNode, isDynamic: Bool = false, translation : Vector3 = Vector3.Zero, rotation : Quaternion = Quaternion.Identity, scale : Vector3 = Vector3.One) {
        self.translation = translation;
        self.rotation = rotation;
        self.scale = scale;
        
        super.init(id: id, parent: parent, isDynamic: isDynamic)
    
    }
    
    override func transformDidChange() {
        super.transformDidChange()
        _nodeToWorldTransform = nil
        _worldToNodeTransform = nil
    }
    
    func setNeedsRecalculateTransform() {
        self.traverse {
            sceneNode in sceneNode.transformDidChange()
        }
    }
    
    /**
    * @return a matrix that converts from local space to world space (i.e. the space of the root node.)
    */
    private func calculateNodeToWorldTransform() -> Matrix4 {
        var transform = self.parent?.nodeToWorldSpaceTransform ?? Matrix4.Identity
        
        transform = transform.translate(self.translation)
        transform = transform * self.rotation
        transform = transform * Matrix4(withScale: self.scale)
    
        return transform;
    }
    
    /**
    * @return a matrix that converts from world space (i.e. the space of the root node) to local space.
    */
    private func calculateWorldToNodeTransform() -> Matrix4 {
        let parentTransform = self.parent?.worldToNodeSpaceTransform ?? Matrix4.Identity
        var transform = Matrix4(withScale: [1/self.scale.x, 1/self.scale.y, 1/self.scale.z])
        transform = transform * self.rotation.conjugate
        transform = transform.translate(-translation)
        
        return transform * parentTransform;
    }
    
    override var nodeToWorldSpaceTransform : Matrix4 {
        get {
            if let transform = _nodeToWorldTransform {
                return transform
            } else {
                let transform = self.calculateNodeToWorldTransform()
                _nodeToWorldTransform = transform
                return transform
            }
        }
    }
    
    override var worldToNodeSpaceTransform : Matrix4 {
        get {
            if let transform = _worldToNodeTransform {
                return transform
            } else {
                let transform = self.calculateWorldToNodeTransform()
                _worldToNodeTransform = transform
                return transform
            }
        }
    }
    
    func checkForModificationOfStaticNode() {
        assert(self.isDynamic, "Cannot modify a non-dynamic node")
    }
    
    /**
    * Translates this node by translation, specified in its parent's coordinate space.
    * @param translation the translation, specified in this node's parent's coordinate space.
    */
    func translateBy(translation : Vector3) {
        self.translation += translation
    }
    
    func rotateBy(rotation : Quaternion) {
        self.rotation *= rotation
    }
    
    func scaleBy(scale : Vector3) {
        self.scale *= scale
    }
}