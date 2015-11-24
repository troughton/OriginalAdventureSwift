//
//  Light.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 19/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Cocoa
import simd

struct LightFalloff {
    
    static let AttenuationFactor : Float = 0.00002
    
    let constant : Float
    let linear : Float
    let quadratic : Float
    
    static let None = LightFalloff(constant: 1, linear: 0, quadratic: 0)
    static let Linear = LightFalloff(constant: 1, linear: AttenuationFactor, quadratic: 0)
    static let Quadratic = LightFalloff(constant: 1, linear: 0, quadratic: AttenuationFactor)
}

typealias Colour = Vector3

enum LightType {
    case Ambient
    case Directional(Vector3)
    case Point(LightFalloff)
}

class Light : SceneNode {
    let type : LightType
    
    var colour : Colour
    var intensity : Float
    
    init(id: String, parent: SceneNode, isDynamic: Bool = false, type: LightType, colour: Colour, intensity: Float) {
        self.type = type
        self.colour = colour
        self.intensity = intensity
        
        super.init(id: id, parent: parent, isDynamic: isDynamic)
    }
    
    var colourVector : Colour {
        return colour * intensity
    }
    
    var falloff : LightFalloff {
        switch self.type {
        case let .Point(falloff):
            return falloff
        default:
            return LightFalloff.None
        }
    }
    
    func perLightData(worldToCameraMatrix worldToCameraMatrix : Matrix4, hdrMaxIntensity: Float) -> PerLightData? {
     
        let localSpacePosition : Vector4
        switch self.type {
        case .Ambient: return nil
        case .Point(_):
            localSpacePosition = Vector4.ZeroPosition
        case let .Directional(fromDirection):
            localSpacePosition = Vector4(fromDirection, 0)
        }
        
        //The position vector will have a 0 w component if it's directional.
        let positionInCameraSpace = worldToCameraMatrix * (self.parent!.nodeToWorldSpaceTransform * localSpacePosition);
        let intensity = self.isEnabled ? self.colourVector / hdrMaxIntensity : Vector3.Zero;

        var perLightData = PerLightData()
        perLightData.positionInCameraSpace = positionInCameraSpace
        perLightData.intensity = float4(intensity.x, intensity.y, intensity.z, 0)
        perLightData.falloff = float4(self.falloff.constant, self.falloff.linear, self.falloff.quadratic, 0)
        
        return perLightData
    }
    
    static func toLightBlock(lights : [Light], worldToCameraMatrix : Matrix4, hdrMaxIntensity: Float) -> LightBlock {
        let ambientIntensity = (lights.flatMap({ (light) -> Colour? in
            switch light.type {
            case .Ambient:
                return light.colourVector
            default:
                return nil
            }
        })
            .reduce(Colour.Zero) { $0 + $1 }) / hdrMaxIntensity
        
        let lightData = lights.flatMap { $0.perLightData(worldToCameraMatrix: worldToCameraMatrix, hdrMaxIntensity: hdrMaxIntensity) }
        
        assert(lightData.count <= Int(MaxLights), "There are too many lights in the scene.")
        
        var lightBlock = LightBlock();
        lightBlock.ambientIntensity = float4(ambientIntensity.x, ambientIntensity.y, ambientIntensity.z, 0)
        withUnsafeMutablePointer(&lightBlock) { (lightBlockPointer) -> Void in
            let offsetPointer = UnsafeMutablePointer<Void>(lightBlockPointer).advancedBy(sizeof(float4))
            let perLightBuffer = UnsafeMutableBufferPointer<PerLightData>(start: UnsafeMutablePointer<PerLightData>(offsetPointer), count: Int(MaxLights))
            for i in 0..<min(lightData.count, Int(MaxLights)) {
                perLightBuffer[i] = lightData[i]
            }
        }
        return lightBlock;
    }
}
