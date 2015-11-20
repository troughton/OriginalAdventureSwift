//
//  AnimableProperty.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 17/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

public class AnimableProperty : Hashable, Equatable {
    var directValue : AnimationFloat {
        didSet {
            AnimableProperty.eventValueChanged.trigger(onObject: self)
        }
    }
    var value : AnimationFloat {
        get {
            return directValue
        }
        set(newValue) {
            if self.animation != nil {
                assertionFailure("Tried to modify value on \(self) to \(newValue) when the value is being modified by an animation")
            } else {
                self.directValue = value
            }
        }
    }

    var animation : Animation? = nil {
        willSet(animation) {
            if animation != self.animation {
                self.animation?.cancel()
            }
        }
        
        didSet(animation) {
            if let animation = animation {
                Animation.eventAnimationDidComplete.filter(animation).addAction(actionAnimationDidFinish)
            }
        }
    }
    
    static let eventValueChanged = Event<AnimableProperty>(name: "ValueChanged");
    
    func actionAnimationDidFinish(animation: Animation, data: [EventDataKey : Any]) -> Void {
        if let propertyAnimation = self.animation {
            if propertyAnimation == animation { self.animation = nil }
        }
    }
    
    init(value : AnimationFloat) {
        self.directValue = value
    }
    
    var isAnimating : Bool {
        return self.animation != nil
    }
    
    public var hashValue : Int {
        return ObjectIdentifier(self).hashValue
    }
}

public func ==(lhs: AnimableProperty, rhs: AnimableProperty) -> Bool {
    return lhs.hashValue == rhs.hashValue
}