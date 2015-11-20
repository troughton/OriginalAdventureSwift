//
//  Event.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 17/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import Swift

protocol EventType {
    typealias EventObjectType : AnyObject, Equatable
    typealias Action = (eventObject: EventObjectType, [EventDataKey : Any]) -> ()
    func addAction(action: Action)
}

class EventSlicePredicate<E: AnyObject where E: Equatable> : EventType {
    
    typealias EventObjectType = E
    typealias Action = (eventObject: E, data: [EventDataKey : Any]) -> ()
    
    typealias Predicate = (eventObject: E) -> Bool

    private let _predicate : Predicate
    
    private var _actions = [Action]()
    
    private init(predicate : Predicate) {
        _predicate = predicate
    }
    
    func addAction(action: Action) {
        _actions.append(action)
    }
    
    func trigger(onObject eventObject: EventObjectType, data: [EventDataKey : Any]) {
        if _predicate(eventObject: eventObject) {
            for action in _actions {
                action(eventObject: eventObject, data: data)
            }
        }
    }
}

class WeakReference<T: AnyObject> {
    weak var value : T?
    
    init(_ value: T) {
        self.value = value
    }
}

class EventSliceArray<E: AnyObject where E : Equatable> : EventType {
    
    typealias EventObjectType = E
    typealias Action = (eventObject: E, data: [EventDataKey : Any]) -> ()
    
    private let _objects : [WeakReference<E>]
    private var _actions = [Action]()
    
    private init(objects: [E]) {
        _objects = objects.map { WeakReference($0) }
    }
    
    func addAction(action: Action) {
        _actions.append(action)
    }
    
    func trigger(onObject eventObject: E, data: [EventDataKey : Any]) {
        if (_objects.flatMap { $0.value }.contains { return $0 == eventObject }) {
            for action in _actions {
                action(eventObject: eventObject, data: data)
            }
        }
    }
    
    var isValid : Bool {
        return _objects.reduce(false, combine: { (isValid, object) -> Bool in
            return isValid || object.value != nil
        })
    }
    
}

class EventSliceObject<E: AnyObject where E: Equatable> : EventType {
    
    typealias EventObjectType = E
    typealias Action = (eventObject: E, data: [EventDataKey : Any]) -> ()
    
    private let _object : WeakReference<E>
    private var _actions = [Action]()
    
    private init(passingObject: E) {
        _object = WeakReference(passingObject)
    }
    
    func addAction(action: Action) {
        _actions.append(action)
    }
    
    var isValid : Bool {
        return _object.value != nil
    }
    
    func trigger(onObject eventObject: E, data: [EventDataKey : Any]) {
        guard let value = _object.value else { return }
        if value == eventObject {
            for action in _actions {
                action(eventObject: eventObject, data: data)
            }
        }
    }
}

private var _namesToEvents = [String : Any]()

/** E defines the type of objects that the event may occur on. */
class Event<E: AnyObject where E: Equatable> : EventType {
    
    typealias EventObjectType = E
    typealias Predicate = (eventObject: E) -> Bool
    typealias Action = (eventObject: E, data: [EventDataKey : Any]) -> ()
    
    let name: String
    private var _actions = [Action]()
    
    private var _arraySlices = [EventSliceArray<E>]()
    private var _objectSlices = [EventSliceObject<E>]()
    private var _predicateSlices = [EventSlicePredicate<E>]()
    
    init(name: String) {
        self.name = name
        _namesToEvents[name] = self
    }
    
    static func eventForName(name: String) -> Event<E> {
        return _namesToEvents[name] as! Event<E>
    }
    
    func filter(usingPredicate predicate: Predicate) -> EventSlicePredicate<E> {
        let slice = EventSlicePredicate(predicate: predicate)
        _predicateSlices.append(slice)
        return slice
    }
    
    func filter(onlyObject: E) -> EventSliceObject<E> {
        let slice = EventSliceObject(passingObject: onlyObject)
        _objectSlices.append(slice)
        return slice
    }
    
    func filter(objects: [E]) -> EventSliceArray<E> {
        let slice = EventSliceArray(objects: objects)
        _arraySlices.append(slice)
        return slice
    }
    
    func addAction(action: Action) {
        _actions.append(action)
    }
    
    func trigger(onObject eventObject: E, data: [EventDataKey: Any] = [:]) {
        for action in _actions {
            action(eventObject: eventObject, data: data)
        }
        
        var slicesToRemove = [Int]()
        
        for slice in _predicateSlices{
            slice.trigger(onObject: eventObject, data: data)
        }
        
        for (index, slice) in _objectSlices.enumerate() {
            slice.trigger(onObject: eventObject, data: data)
            if !slice.isValid { slicesToRemove.append(index) }
        }
        
        for index in slicesToRemove.reverse() {
            _objectSlices.removeAtIndex(index)
        }
        
        slicesToRemove.removeAll()
        
        for (index, slice) in _arraySlices.enumerate() {
            slice.trigger(onObject: eventObject, data: data)
            if !slice.isValid { slicesToRemove.append(index) }
        }
        
        for index in slicesToRemove.reverse() {
            _arraySlices.removeAtIndex(index)
        }
    }
}