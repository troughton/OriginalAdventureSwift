//
//  MDLVertexAttributeExtensions.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 9/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Swift
import ModelIO
import OpenGL.GL3

extension MDLVertexFormat {
    
    var numberOfComponents : GLint {
        return GLint(self.rawValue & 0b111)
    }
    
    var isNormalised : Bool {
        switch MDLVertexFormat(rawValue: self.rawValue & ~0b1111)! {
        case .UCharNormalizedBits:
            return true
        case .CharNormalizedBits:
            return true
        case .UShortNormalizedBits:
            return true
        case .ShortNormalizedBits:
            return true
        default:
            return false
        }
    }
    
    var glType : GLenum {
        
        switch self {
        case .Int1010102Normalized:
            return GLenum(GL_INT_2_10_10_10_REV)
        case .UInt1010102Normalized:
            return GLenum(GL_UNSIGNED_INT_10_10_10_2)
        default: break
        }
        
        var type : GLint = 0;
        switch MDLVertexFormat(rawValue: self.rawValue & ~0b1111)! {
        case .UCharBits:
            fallthrough
        case .UCharNormalizedBits:
            type = GL_UNSIGNED_BYTE;
        case .CharBits:
            fallthrough
        case .CharNormalizedBits:
            type = GL_BYTE
        case .UShortBits:
            fallthrough
        case .UShortNormalizedBits:
            type = GL_UNSIGNED_SHORT
        case .ShortBits:
            fallthrough
        case .ShortNormalizedBits:
            type = GL_SHORT
        case .UIntBits:
            type = GL_UNSIGNED_INT
        case .IntBits:
            type = GL_INT
        case .HalfBits:
            type = GL_HALF_FLOAT
        case .FloatBits:
            type = GL_FLOAT
        default:
            break
        }
        
        return GLenum(type)
    }
}

extension MDLIndexBitDepth {
    var glType : GLenum {
        switch self {
        case .UInt8:
            return GLenum(GL_UNSIGNED_BYTE)
        case .UInt16:
            return GLenum(GL_UNSIGNED_SHORT)
        case .UInt32:
            return GLenum(GL_UNSIGNED_INT)
        case .Invalid:
            assertionFailure("The index type has not been initialised")
            return 0
        }
    }
}

extension MDLGeometryType {
    var glType : GLenum {
        switch self {
        case .TypeLines:
            return GLenum(GL_LINES)
        case .TypePoints:
            return GLenum(GL_POINTS)
        case .TypeQuads:
            return GLenum(GL_QUADS)
        case .TypeTriangles:
            return GLenum(GL_TRIANGLES)
        case .TypeTriangleStrips:
            return GLenum(GL_TRIANGLE_STRIP)
        case .TypeVariableTopology:
            assertionFailure("Variable topologies are unsupported")
            return 0
        }
    }
}