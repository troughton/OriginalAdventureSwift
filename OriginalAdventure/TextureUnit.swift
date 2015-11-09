//
//  TextureUnit.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 7/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import OpenGL

/** A texture unit is one of the possible units that a texture and sampler can be bound to in an OpenGL context.
* This enum makes things a little nicer than passing integer constants around.
*/
enum TextureUnit : GLuint {
    case AmbientColourUnit
    case DiffuseColourUnit
    case SpecularColourUnit
    case SpecularityUnit
    case NormalMapUnit
    
    //Units for deferred shading.
    case VertexNormalUnit
    case DepthTextureUnit
    case FinalUnit
    
    static let deferredShadingUnits : [TextureUnit] = [.VertexNormalUnit, .DiffuseColourUnit, .SpecularColourUnit]
}