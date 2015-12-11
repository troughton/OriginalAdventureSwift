//
//  OpenCloseBehaviour.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 8/12/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class OpenCloseBehaviour : Behaviour {
    var isOpen = false
    
    let hinge : TransformNode
    
    let openRotation : Quaternion
    let closedRotation : Quaternion
    
    init(gameObject: GameObject, hinge: TransformNode, openRotation: Quaternion, closedRotation : Quaternion) {
        self.hinge = hinge
        self.openRotation = openRotation
        self.closedRotation = closedRotation
        
        super.init(gameObject: gameObject)
    }
}