//
//  OptionalStringInitialisable.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 15/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation


enum StringInitialisationError : ErrorType {
    case InsufficientElements(String)
    case InvalidFormat(String)
}


extension Vector3 {
    
    init?(fromString string: String?) throws {
        guard let string = string else { return nil }
        
        let scanner = NSScanner(string: string)
        scanner.charactersToBeSkipped = NSCharacterSet(charactersInString: "1234567890-.").invertedSet
        try self.init(fromScanner: scanner)
    }
    
    init(fromScanner scanner: NSScanner) throws {
        var array = [Float]()
        for _ in 0..<3 {
            var nextFloat : Float = 0
            guard scanner.scanFloat(&nextFloat) else {
                throw StringInitialisationError.InsufficientElements("A Vector3 requires three floats.")
            }
            array.append(nextFloat)
        }
        self.init(x: array[0], y: array[1], z: array[2])
    }
}

extension Quaternion {
    
    init?(fromString string: String?) throws {
        guard let string = string else { return nil }
        
        let scanner = NSScanner(string: string)
        scanner.charactersToBeSkipped = NSCharacterSet(charactersInString: "1234567890-.").invertedSet
        try self.init(fromScanner: scanner)
    }
    
    init(fromScanner scanner: NSScanner) throws {
        var array = [Float]()
        for _ in 0..<4 {
            var nextFloat : Float = 0
            guard scanner.scanFloat(&nextFloat) else {
                throw StringInitialisationError.InsufficientElements("A Quaternion requires four floats.")
            }
            array.append(nextFloat)
        }
        self.init(array[0], array[1], array[2], array[3])
    }
}

extension Bool {
    init?(fromString string: String?) {
        guard let string = (string as NSString?) else { return nil }
        self = string.boolValue
    }
}

extension Float {
    init?(fromString string: String?) {
        guard let string = (string as NSString?) else { return nil }
        self = string.floatValue
    }
}

extension LightFalloff {
    init?(fromString string: String?) throws {
        guard let string = string else { return nil }
        switch string {
            case "None":
            self = LightFalloff.None
            case "Linear":
            self = LightFalloff.Linear
            case "Quadratic":
            self = LightFalloff.Quadratic
        default:
            throw StringInitialisationError.InvalidFormat("The falloff \(string) is not of a recognised format.")
        }
    }
}