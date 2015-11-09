//
//  Light.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 19/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Cocoa
import OpenGL.GL3
import simd

struct LightFalloff {
    let constant : Float
    let linear : Float
    let quadratic : Float
    
    static let None = LightFalloff(constant: 1, linear: 0, quadratic: 0)
    static let Quadratic = LightFalloff(constant: 1, linear: 0, quadratic: 1)
}

typealias Colour = Vector3
typealias Intensity = Float

enum Light : Enableable {
    case Ambient(Bool, Colour, Intensity)
    case Directional(Bool, Colour, Intensity, Vector3)
    case Point(GameObject, Bool, Colour, Intensity, LightFalloff)
    
    var colourVector : Colour {
        switch self {
        case let .Ambient(_, colour, intensity):
            return colour * intensity
        case let .Directional(_, colour, intensity, _):
            return colour * intensity
        case let .Point(_, _, colour, intensity, _):
            return colour * intensity
        }
    }
    
    var falloff : LightFalloff {
        switch self {
        case let .Point(_, _, _, _, falloff):
            return falloff
        default:
            return LightFalloff.None
        }
    }
    
    var parent : GameObject? {
        get {
            switch self {
                case let .Point(parent, _, _, _, _):
                    return parent
            default:
                return nil
            }
        }
        set(parent) {
            switch self {
            case let .Point(_, enabled, colour, intensity, falloff):
                self = .Point(parent!, enabled, colour, intensity, falloff)
            default:
                break
            }
        }
    }
    
    var isEnabled : Bool {
        get {
            switch self {
            case let .Ambient(enabled, _, _):
                return enabled
            case let .Directional(enabled, _, _, _):
                return enabled
            case let .Point(_, enabled, _, _, _):
                return enabled
            }
        }
        set(enabled) {
            switch self {
            case let .Ambient(_, colour, intensity):
                self = .Ambient(enabled, colour, intensity)
            case let .Directional(_, colour, intensity, fromDirection):
                self = .Directional(enabled, colour, intensity, fromDirection)
            case let .Point(parent, _, colour, intensity, falloff):
                self = .Point(parent, enabled, colour, intensity, falloff)
            }
        }
    }
}
