//
//  MTKInputView.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 24/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import MetalKit

let keyMappings : [UInt16 : UnicodeScalar] = [13 : "W", 0 : "A", 1 : "S", 2 : "D"]

class MTKInputView: MTKView {
    var game : Game! = nil
    
    var keysPressed = Set<UnicodeScalar>()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.window?.acceptsMouseMovedEvents = true
    }
    
    override func acceptsFirstMouse(theEvent: NSEvent?) -> Bool {
        return true
    }
    
    override var acceptsFirstResponder : Bool { return true }
    
    override func keyDown(theEvent: NSEvent) {
        guard let key = keyMappings[theEvent.keyCode] else { return };
        self.game.input.pressKey(key)
        keysPressed.insert(key)
    }
    
    override func keyUp(theEvent: NSEvent) {
        guard let key = keyMappings[theEvent.keyCode] else { return };
        self.game.input.releaseKey(key)
        keysPressed.remove(key)
    }

    override func mouseMoved(theEvent: NSEvent) {
        self.game.onMouseMove(delta: Float(theEvent.deltaX), Float(theEvent.deltaY))
    }
    
}