//
//  SpawnPointBehaviour.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 15/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class SpawnPointBehaviour : Behaviour {
    static let SpawnPointID = "spawnPoint"
    
    func spawnPlayerWithId(id: String) -> GameObject {
        let player = GameObject(id: id, parent: self.gameObject, isDynamic: true)
        _ = PlayerBehaviour(gameObject: player)
        return player
    }
}