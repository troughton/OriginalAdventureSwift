//
//  AnimationCurve.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 17/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

typealias AnimationFloat = Double
typealias AnimationFunction = (progress: AnimationFloat) -> AnimationFloat

enum AnimationCurve {
    case Linear
    case Sine
    case Random
    case Custom(AnimationFunction)
    
    /**
    * Given a percentage progress, this will compute the output progress.
    * @param percentage A percentage progress in the range [0, 1].
    * @return A scaled progress in the range [0, 1].
    */
    func progressForPercentage(percentage: AnimationFloat) -> AnimationFloat {
        switch (self) {
        case Linear:
            return percentage;
        case Sine:
            return AnimationFloat(sin(Double(percentage) * M_PI_2));
        case Random:
            return 0
        case Custom(let animationFunction):
            return animationFunction(progress: percentage);
        }
    }
}

public class Animation : Hashable, Equatable {
    
    private let _animableProperty : AnimableProperty;
    
    private let _startTime : AnimationFloat;
    
    private let _initialValue : AnimationFloat;
    private let _finalValue : AnimationFloat;
    private let _duration : AnimationFloat;
    private let _repeats : Bool;
    
    private var _shouldStopRepeating = false;
    private var _hasCompletedCycleSinceStoppingRepeating = false;
    
    var isComplete = false;
    private let _curve : AnimationCurve;
    
    static var eventAnimationDidComplete = Event<Animation>(name: "AnimationDidComplete")
    static var eventAnimationDidCancel = Event<Animation>(name: "AnimationDidCancel")
    
    init(animableProperty: AnimableProperty, curve: AnimationCurve = AnimationCurve.Linear, duration: AnimationFloat, delay: AnimationFloat = 0, toValue: AnimationFloat, repeats: Bool = false) {
        _animableProperty = animableProperty;
    
        _initialValue = animableProperty.value;
    
        _finalValue = toValue;
        _startTime = AnimationSystem.currentTime + delay;
        _duration = duration;
        _repeats = repeats;
        _curve = curve;
    
        AnimationSystem.addAnimation(self);
        
        _animableProperty.animation = self;
    }
    
    /**
    * Creates a new random animation that varies between the current value and the toValue.
    * @param animableProperty The property to animate
    * @param toValue The maximum value the property can take.
    */
    convenience init(randomAnimationWithProperty animableProperty: AnimableProperty, from: AnimationFloat, to: AnimationFloat) {
        animableProperty.value = from
        self.init(animableProperty: animableProperty, curve: .Random, duration: AnimationFloat.infinity, toValue: to, repeats: true);
    }
    
    private func percentageComplete(currentTime: AnimationFloat) -> AnimationFloat {
        let elapsedTime = currentTime - _startTime;
        var percentage = elapsedTime/_duration;
    
        if (_shouldStopRepeating && percentage >= 1.0) {
            _hasCompletedCycleSinceStoppingRepeating = true;
        }
    
        let percentageThroughCycle = percentage - trunc(percentage);
        if (_repeats && !_hasCompletedCycleSinceStoppingRepeating) {
            percentage = percentageThroughCycle;
        }
        percentage = min(max(0.0, percentage), 1.0);
        return percentage;
    }
    
    private func valueAtTime(currentTime: AnimationFloat) -> AnimationFloat {
        switch _curve {
        case .Random:
                return AnimationFloat(arc4random_uniform(UInt32.max))/AnimationFloat(UInt32.max) * (_finalValue - _initialValue) + _initialValue
        default:
            let progress = _curve.progressForPercentage(self.percentageComplete(currentTime));
            return _initialValue + (_finalValue - _initialValue) * progress;
        }
    }
    
    func update(currentTime currentTime: AnimationFloat) {
        let value = self.valueAtTime(currentTime);
    
        _animableProperty.directValue = value;
    
        if (!_repeats && value == _finalValue) {
            self.isComplete = true
            Animation.eventAnimationDidComplete.trigger(onObject: self);
    }
    }
    
    /** Cancels the animation so it ceases to update any properties. */
    func cancel() {
        self.isComplete = true
        Animation.eventAnimationDidCancel.trigger(onObject: self);
    }
    
    
    /** Stops the animation from repeating again after this cycle. */
    func stopRepeating() {
        _shouldStopRepeating = true;
    }
    
    public var hashValue : Int {
        return ObjectIdentifier(self).hashValue
    }
}

public func ==(lhs: Animation, rhs: Animation) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

