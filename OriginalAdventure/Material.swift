//
//  Material.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 21/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import ModelIO
import GLKit

struct Material {
    
    static let defaultMaterial = Material()
    
    var ambientColour : Vector3
    var diffuseColour : Vector3
    var specularColour : Vector3
    var opacity : Float
    var specularity : Float
    
    var useAmbient = true
    
    var diffuseMap : TextureSampler?
    var ambientMap : TextureSampler?
    var specularityMap : TextureSampler?
    var normalMap : TextureSampler?
    
    func bindSamplers() {
        self.diffuseMap?.bindTexture()
        self.ambientMap?.bindTexture()
        self.specularityMap?.bindTexture()
        self.normalMap?.bindTexture()
    }
    
    func unbindSamplers() {
        self.diffuseMap?.unbindTexture()
        self.ambientMap?.unbindTexture()
        self.specularityMap?.unbindTexture()
        self.normalMap?.unbindTexture()
    }
    
    init(diffuseColour: Vector3 = Vector3(0.5, 0.5, 0.5), specularColour: Vector3 = Vector3(0.5, 0.5, 0.5), specularity: Float = 0.5, ambientColour: Vector3 = Vector3.Zero, opacity : Float = 1.0) {
        self.diffuseColour = diffuseColour
        self.specularColour = specularColour
        self.specularity = specularity
        self.ambientColour = ambientColour
        self.opacity = opacity
    }
    
    //Flags:
    //Use an ambient map if ambientColour.x is NaN
    //Use a diffuse map if diffuseColour.x is NaN
    //Use a specular map if specularity.x is NaN
    //Use a normal map if diffuseColour.y isNaN
    
    /**
    * @param hdrMaxIntensity The maximum light intensity in the scene, which the ambient colour is divided by.
    * @return This material's attributes, packed into a ByteBuffer.
    * The format is as follows:
    * struct Material {
    * //Packed into a single vec4
    * Vector3 ambientColour;
    * float ambientEnabled; //where ~0 is false and ~1 is true.
    *
    * //Packed into a single vec4
    * Vector3 diffuseColour;
    * float alpha;
    *
    * //Packed into a single vec4
    * Vector3 specularColour;
    * float specularity;
    */
    func toStruct(hdrMaxIntensity hdrMaxIntensity : Float) -> MaterialStruct {
        var materialStruct = MaterialStruct()
        let ambientColour = self.ambientColour / hdrMaxIntensity;
        materialStruct.ambientColour = float4(self.ambientMap != nil ? Float.NaN : ambientColour.x, ambientColour.y, ambientColour.z, self.useAmbient ? 1 : 0)
        
        materialStruct.diffuseColour = float4(self.diffuseMap != nil ? Float.NaN : self.diffuseColour.x, self.normalMap != nil ? Float.NaN : self.diffuseColour.y, self.diffuseColour.z, self.opacity)
        
        materialStruct.specularColour = float4(self.specularityMap != nil ? Float.NaN : self.specularColour.x, self.specularColour.y, self.specularColour.z, self.specularity)
    
        return materialStruct
    }
    
    static func phongSpecularToGaussian(phong: Float) -> Float {
        return 1.0/phong
    }
    
    static func fillTextureWithColour(texture: MTLTexture, colour: float4) -> MTLTexture {
        let bytes : [UInt8] = [UInt8(min(colour.x * 255, 255)), UInt8(min(colour.y * 255, 255)), UInt8(min(colour.z * 255, 255)), UInt8(min(colour.w * 255, 255))]
        texture.replaceRegion(MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: bytes, bytesPerRow: 4)
        
        return texture
    }
}

extension Material : Hashable {
    var hashValue : Int {
        let prime = 31;
        var result = 1;
        
        result = prime &* result &+ self.ambientColour.hashValue
        result = prime &* result &+ self.diffuseColour.hashValue
        result = prime &* result &+ self.specularColour.hashValue
        result = prime &* result &+ self.specularity.hashValue
        result = prime &* result &+ self.opacity.hashValue
        result = prime &* result &+ self.useAmbient.hashValue
        result = prime &* result &+ (self.diffuseMap?.hashValue ?? 0)
        result = prime &* result &+ (self.ambientMap?.hashValue ?? 0)
        result = prime &* result &+ (self.specularityMap?.hashValue ?? 0)
        result = prime &* result &+ (self.normalMap?.hashValue ?? 0)
        
        return result
    }
}

func ==(lhs: Material, rhs: Material) -> Bool {
    return lhs.ambientColour == rhs.ambientColour &&
    lhs.diffuseColour == rhs.diffuseColour &&
    lhs.specularColour == rhs.specularColour &&
    lhs.opacity == rhs.opacity &&
    lhs.specularity == rhs.specularity &&
    lhs.useAmbient == rhs.useAmbient &&
    lhs.diffuseMap == rhs.diffuseMap &&
    lhs.ambientMap == rhs.ambientMap &&
    lhs.specularityMap == rhs.specularityMap &&
    lhs.normalMap == rhs.normalMap
}