//
//  Matrix4.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 20/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import simd
import OpenGL.GL3

class Reference<T> {
    var value: T
    
    init(_ value: T) {
        self.value = value
    }
}

struct WindowDimension {
    let width : Int32
    let height : Int32
    
    var aspect : Float {
        return Float(self.width) / Float(self.height)
    }
    
    static let defaultDimension = WindowDimension(width: 800, height: 600)
}

typealias Vector2 = float2

typealias Matrix4 = float4x4

extension Matrix4 {
    static let Identity = Matrix4(1)
    
    var matrix3 : Matrix3 {
        return Matrix3([[self[0][0], self[0][1], self[0][2]] as Vector3,
                        [self[1][0], self[1][1], self[1][2]] as Vector3,
                        [self[2][0], self[2][1], self[2][2]] as Vector3])
    }
    
    init(withTranslation translation : Vector3) {
        self.init(1)
        self[3] = Vector4(translation.x, translation.y, translation.z, 1)
    }
    
    init(withScale scale: Vector3) {
        self.init(diagonal: Vector4(scale, 1))
    }
    
    init(withQuaternion quaternion: Quaternion) {
        let normalised = normalize(quaternion)
        
        let (x, y, z, w) = (normalised.x, normalised.y, normalised.z, normalised.w)
        let (_2x, _2y, _2z, _2w) = (x + x, y + y, z + z, w + w)
        
        self.init([[1.0 - _2y * y - _2z * z,
            _2x * y + _2w * z,
            _2x * z - _2w * y,
            0.0] as Vector4,
            [_2x * y - _2w * z,
            1.0 - _2x * x - _2z * z,
            _2y * z + _2w * x,
            0.0] as Vector4,
           [ _2x * z + _2w * y,
            _2y * z - _2w * x,
            1.0 - _2x * x - _2y * y,
            0.0] as Vector4,
            [0.0,
            0.0,
            0.0,
            1.0] as Vector4]);
    }
    
    init(perspectiveWithFieldOfView fovRadians: Float, aspect: Float, nearZ : Float, farZ : Float) {
        let cotan = 1.0 / tan(fovRadians / 2.0)
        
        self.init([
            [cotan / aspect, 0.0, 0.0, 0.0] as Vector4,
            [0.0, cotan, 0.0, 0.0] as Vector4,
            [0.0, 0.0, (farZ + nearZ) / (nearZ - farZ), -1.0] as Vector4,
            [0.0, 0.0, (2.0 * farZ * nearZ) / (nearZ - farZ), 0.0] as Vector4
            ])
    }
    
    func translate(vector: Vector3) -> Matrix4 {
        return self * Matrix4(withTranslation: vector)
    }
}

typealias Matrix3 = float3x3

extension Matrix3 {
    
}

typealias Vector3 = float3

extension Vector3 : Equatable {
    static let Zero = Vector3()
    static let One = Vector3(1)
}

func *(lhs: Vector3, rhs: Vector3) -> Vector3 {
    return Vector3(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
}

func /(lhs: Vector3, rhs: Float) -> Vector3 {
    return Vector3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
}

public func ==(lhs: float3, rhs: float3) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
}

typealias Vector4 = float4

extension Vector4 : Equatable {
    static let ZeroPosition = Vector4(0, 0, 0, 1)
    static let Zero = Vector4(0)
    
    var xyz : Vector3 {
        return Vector3(self.x, self.y, self.z)
    }
    
    init(_ vector: Vector3, _ w: Float) {
        self.init(vector.x, vector.y, vector.z, w)
    }
}

public func ==(lhs: float4, rhs: float4) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z && lhs.w == rhs.w
}


struct Quaternion : ArrayLiteralConvertible, Equatable {
    let q : float4
    
    var x : Float { return q.x }
    var y : Float { return q.y }
    var z : Float { return q.z }
    var w : Float { return q.w }
    
    static let Identity = Quaternion(0, 0, 0, 1)
    
    init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.q = float4(x, y, z, w)
    }
    
    init(arrayLiteral elements: Float...) {
        self.init(elements[0], elements[1], elements[2], elements[3])
    }
    
    init(_ q : float4) {
        self.q = q
    }
    
    var conjugate : Quaternion {
        return [-self.x, -self.y, -self.z, self.w]
    }
}

func ==(lhs: Quaternion, rhs: Quaternion) -> Bool {
    return lhs.q == rhs.q
}

/// Unit vector pointing in the same direction as `x`.
@warn_unused_result
func normalize(x: Quaternion) -> Quaternion {
    return Quaternion(normalize(x.q))
}

func *(lhs: Quaternion, rhs: Quaternion) -> Quaternion {
    return Quaternion(QuaternionMultiply(lhs.q, rhs.q))
}

func *=(inout lhs: Quaternion, rhs: Quaternion) {
    lhs = Quaternion(QuaternionMultiply(lhs.q, rhs.q))
}

func *(lhs: Quaternion, rhs: Float) -> Quaternion {
    return Quaternion(lhs.q * rhs)
}

func *(lhs: Matrix4, rhs: Quaternion) -> Matrix4 {
    return lhs * Matrix4(withQuaternion: rhs)
}