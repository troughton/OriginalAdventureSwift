//
//  AnimationSystem.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 17/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class AnimationSystem {
    
    private static var _animations = [Animation]();
    
    static var currentTime : AnimationFloat {
        return AnimationFloat(CurrentTime());
    }
    
    static func addAnimation(animation: Animation) {
        _animations.append(animation);
    }
    
    /**
    * Updates the animation system, changing the values of all AnimableProperties.
    */
    static func update() {
        let currentTime = AnimationSystem.currentTime;
    
        var animationsToRemove = [Int]();
    
        for (index, animation) in _animations.enumerate() {
            animation.update(currentTime: currentTime)
            if animation.isComplete {
                animationsToRemove.append(index)
            }
        }
        
        for index in animationsToRemove.reverse() {
            _animations.removeAtIndex(index)
        }
    }
}

