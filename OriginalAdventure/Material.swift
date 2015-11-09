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
    
    static let defaultMaterial = Material(diffuseColour: Vector3.One, specularColour: Vector3.One, specularity: 0.5, ambientColour: Vector3.Zero, opacity: 1.0)
    
    var ambientColour : Vector3
    var diffuseColour : Vector3
    var specularColour : Vector3
    var opacity : Float
    var specularity : Float
    
    var useAmbient = true
    
    var diffuseMap : GLKTextureInfo?
    var ambientMap : GLKTextureInfo?
    var specularColourMap : GLKTextureInfo?
    var specularityMap : GLKTextureInfo?
    var normalMap : GLKTextureInfo?
    
    func bindTextures() { }
    
    func bindSamplers() { }
    
    func unbindTextures() { }
    
    func unbindSamplers() { }
    
    init(diffuseColour: Vector3, specularColour: Vector3, specularity: Float, ambientColour: Vector3, opacity : Float) {
        self.diffuseColour = diffuseColour
        self.specularColour = specularColour
        self.specularity = specularity
        self.ambientColour = ambientColour
        self.opacity = opacity
    }
    
    init(fromModelIO mdlMaterial: MDLMaterial) {
        self = Material.defaultMaterial
    }
}