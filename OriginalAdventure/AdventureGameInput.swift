//
//  AdventureGameInput.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 18/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class AdventureGameInput : Input {
    
    override init() {
        super.init()
        
        self.registerToPerform(AdventureGameInput.eventMoveForwardKeyPressed, onHeld: UnicodeScalar("W"))
        self.registerToPerform(AdventureGameInput.eventMoveLeftKeyPressed, onHeld: UnicodeScalar("A"))
        self.registerToPerform(AdventureGameInput.eventMoveRightKeyPressed, onHeld: UnicodeScalar("D"))
        self.registerToPerform(AdventureGameInput.eventMoveBackKeyPressed, onHeld: UnicodeScalar("S"))
        
        [AdventureGameInput.eventMoveBackKeyPressed, AdventureGameInput.eventMoveForwardKeyPressed, AdventureGameInput.eventMoveLeftKeyPressed, AdventureGameInput.eventMoveRightKeyPressed].forEach { $0.addAction(self.moveKeyPressed); }
    }
    
    static let eventMoveForwardKeyPressed = Event<Input>(name: "MoveForwardKeyPressed")
    static let eventMoveLeftKeyPressed = Event<Input>(name: "MoveLeftKeyPressed")
    static let eventMoveRightKeyPressed = Event<Input>(name: "MoveRightKeyPressed")
    static let eventMoveBackKeyPressed = Event<Input>(name: "MoveBackKeyPressed")

    static let eventMoveInDirection = Event<Input>(name: "MoveInDirection")
    
    func moveKeyPressed(eventObject: Input, data: [EventDataKey : Any]) {
        let elapsedTime = data[.ElapsedTime] as! Float;
        let direction : Vector3?;
        let event = data[.Event] as! Event<Input>
        
        if (event === AdventureGameInput.eventMoveForwardKeyPressed) {
            direction = Vector3(0, 0, -1);
        } else if (event === AdventureGameInput.eventMoveBackKeyPressed) {
            direction = Vector3(0, 0, 1);
        } else if (event === AdventureGameInput.eventMoveLeftKeyPressed) {
            direction = Vector3(-1, 0, 0);
        } else if (event === AdventureGameInput.eventMoveRightKeyPressed) {
            direction = Vector3(1, 0, 0);
        } else {
            direction = nil
        }
        
        if let direction = direction {
            AdventureGameInput.eventMoveInDirection.trigger(onObject: self, data: [.Direction: direction, .ElapsedTime : elapsedTime])
        }
    }
}