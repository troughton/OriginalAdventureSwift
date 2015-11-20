//
//  Input.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 18/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

protocol InputSource {
    var hashValue: Int { get }
    
    func isEqualTo(other: InputSource) -> Bool
}

enum MouseButton : InputSource {
    case Left
    case Right
    
    func isEqualTo(other: InputSource) -> Bool {
        if let other = other as? MouseButton {
            return self == other
        } else {
            return false
        }
    }
}

extension UnicodeScalar : InputSource {
    func isEqualTo(other: InputSource) -> Bool {
        if let other = other as? UnicodeScalar {
            return self == other
        } else {
            return false
        }
    }
}

struct InputSourceWrapper : Hashable {
    let value : InputSource
    
    init(_ value: InputSource) {
        self.value = value
    }
    
    var hashValue : Int {
        return value.hashValue
    }
}

func ==(lhs: InputSourceWrapper, rhs: InputSourceWrapper) -> Bool {
    return lhs.value.isEqualTo(rhs.value)
}



class Input : Equatable {
    private var onPressMappings = [InputSourceWrapper : Event<Input>]();
    private var onHeldMappings = [InputSourceWrapper : Event<Input>]();
    private var onReleasedMappings = [InputSourceWrapper : Event<Input>]();
    
    func registerToPerform(event: Event<Input>, onPress input: InputSource) {
        self.onPressMappings[InputSourceWrapper(input)] = event
    }
    
    func registerToPerform(event: Event<Input>, onHeld input: InputSource) {
        self.onHeldMappings[InputSourceWrapper(input)] = event
    }
    
    func registerToPerform(event: Event<Input>, onRelease input: InputSource) {
        self.onReleasedMappings[InputSourceWrapper(input)] = event
    }
    
    func pressKey(key : InputSource) {
        if let event = onPressMappings[InputSourceWrapper(key)] {
            event.trigger(onObject: self, data: [.Event : event])
        }
    }
    
    func checkHeldKeys(isKeyPressed: (InputSource) -> Bool, elapsedTime: Float) {
        onHeldMappings.filter { (character, event) -> Bool in
            isKeyPressed(character.value)
            }
            .map { (character, event) -> Event<Input> in
                event
            }
            .forEach { (event) -> () in
                event.trigger(onObject: self, data: [.Event : event, .ElapsedTime : elapsedTime])
        }
        
    }
    
    
    func releaseKey(key: InputSource) {
        if let event = onReleasedMappings[InputSourceWrapper(key)] {
            event.trigger(onObject: self, data: [.Event : event])
        }
    }

}

func ==(lhs: Input, rhs: Input) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}