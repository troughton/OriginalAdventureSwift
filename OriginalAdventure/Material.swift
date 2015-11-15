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
    var specularColourMap : TextureSampler?
    var specularityMap : TextureSampler?
    var normalMap : TextureSampler?
    
    func bindSamplers() {
        self.diffuseMap?.bindTexture()
        self.ambientMap?.bindTexture()
        self.specularColourMap?.bindTexture()
        self.specularityMap?.bindTexture()
        self.normalMap?.bindTexture()
        
    }
    
    func unbindSamplers() {
        self.diffuseMap?.unbindTexture()
        self.ambientMap?.unbindTexture()
        self.specularColourMap?.unbindTexture()
        self.specularityMap?.unbindTexture()
        self.normalMap?.unbindTexture()
    }
    
    init(diffuseColour: Vector3 = Vector3.One, specularColour: Vector3 = Vector3.Zero, specularity: Float = 0.5, ambientColour: Vector3 = Vector3.Zero, opacity : Float = 1.0) {
        self.diffuseColour = diffuseColour
        self.specularColour = specularColour
        self.specularity = specularity
        self.ambientColour = ambientColour
        self.opacity = opacity
    }
    
    struct TextureMapFlag : OptionSetType {
        let rawValue: Int
        
        static let None = TextureMapFlag(rawValue: 0)
        static let AmbientMapEnabled = TextureMapFlag(rawValue: 1 << 0)
        static let DiffuseMapEnabled = TextureMapFlag(rawValue: 1 << 1)
        static let SpecularColourMapEnabled = TextureMapFlag(rawValue: 1 << 2)
        static let SpecularityMapEnabled = TextureMapFlag(rawValue: 1 << 3)
        static let NormalMapEnabled = TextureMapFlag(rawValue: 1 << 4)
    }
    
    private func packMapFlags() -> TextureMapFlag {
        var result = TextureMapFlag.None;
        if (self.ambientMap != nil) { result.unionInPlace(.AmbientMapEnabled) ; }
        if (self.diffuseMap != nil) { result.unionInPlace(.DiffuseMapEnabled); }
        if (self.specularColourMap != nil) { result.unionInPlace(.SpecularColourMapEnabled); }
        if (self.specularityMap != nil) { result.unionInPlace(.SpecularityMapEnabled); }
        if (self.normalMap != nil) { result.unionInPlace(.NormalMapEnabled); }
        return result;
    }
    
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
    
    * boolean useAmbientMap; //packed in an integer as 1 << 0
    * boolean useDiffuseMap; //packed in an integer as 1 << 1
    * boolean useSpecularColourMap; //packed in an integer as 1 << 2
    * boolean useSpecularityMap; //packed in an integer as 1 << 3
    * boolean useNormalMap; //packed in an integer as 1 << 4
    */
    func toStruct(hdrMaxIntensity hdrMaxIntensity : Float) -> MaterialStruct {
        var materialStruct = MaterialStruct()
        let ambientColour = self.ambientColour / hdrMaxIntensity;
        materialStruct.ambientColour = (ambientColour.x, ambientColour.y, ambientColour.z, self.useAmbient ? 1 : 0)
        
        materialStruct.diffuseColour = (self.diffuseColour.x, self.diffuseColour.y, self.diffuseColour.z, self.opacity)
        
        materialStruct.specularColour = (self.specularColour.x, self.specularColour.y, self.specularColour.z, self.specularity)
        
        materialStruct.flags = Int32(self.packMapFlags().rawValue)
    
        return materialStruct
    }
    
    static func phongSpecularToGaussian(phong: Float) -> Float {
        return 1.0/phong
    }
}