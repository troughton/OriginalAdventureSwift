//
//  PlayerBehaviour.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 15/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class PlayerBehaviour : Behaviour {
    
    override init(gameObject: GameObject) {
        super.init(gameObject: gameObject)
        
        self.gameObject.camera = Camera(id: gameObject.id + "CameraTranslation", parent: gameObject, translation: Vector3(0, 100, 0))
    }
}