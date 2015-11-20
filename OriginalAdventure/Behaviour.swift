//
//  Behaviour.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 15/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class Behaviour : Equatable {
    let gameObject : GameObject
    
    init(gameObject: GameObject) {
        self.gameObject = gameObject
        gameObject.behaviours.append(self)
    }
}

func ==(lhs: Behaviour, rhs: Behaviour) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}