//
//  Geometry.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 13/12/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation


///Beware: here be floating point accuracy dragons
struct FrustumPlane {
    let normalVector : Vector3
    let constant : Float
    
    var normalised : FrustumPlane {
        let magnitude = length(normalVector)
        return FrustumPlane(normalVector: self.normalVector / magnitude, constant: self.constant / magnitude)
    }
    
    func distanceTo(point: Vector3) -> Float {
        return reduce_add(self.normalVector * point) + self.constant
    }
    
    init(normalVector: Vector3, constant: Float) {
        self.normalVector = normalVector
        self.constant = constant
    }
    
    init(withPoints points: [Vector3]) {
        assert(points.count > 2)
        
        let pointDoubles = points.map { double3(Double($0.x), Double($0.y), Double($0.z)) }
        
        let normalDouble = normalize(cross(pointDoubles[1] - pointDoubles[0], pointDoubles[2] - pointDoubles[0]))
        let normal = Vector3(Float(normalDouble.x), Float(normalDouble.y), Float(normalDouble.z))
        let constant = -reduce_add(points[0] * normal)
        
        self.init(normalVector: normal, constant: constant)
        
        assert({
            for point in points {
                if self.distanceTo(point) != 0 {
                    return false
                }
            }
            return true
            }(), "All the points must lie on the resultant plane")
    }
}

struct Frustum {
    
    enum PlaneDirection {
        case Far
        case Near
        case Left
        case Right
        case Top
        case Bottom
        
        var extentsOfPlane : [Extent] { //ordered anti-clockwise as viewed from the inside of the frustum
            switch self {
            case Far:
                return [.MaxX_MaxY_MaxZ, .MinX_MaxY_MaxZ, .MinX_MinY_MaxZ, .MaxX_MinY_MaxZ]
            case Near:
                return [.MaxX_MaxY_MinZ, .MaxX_MinY_MinZ, .MinX_MinY_MinZ, .MinX_MaxY_MinZ]
            case Left:
                return [.MinX_MaxY_MaxZ, .MinX_MaxY_MinZ, .MinX_MinY_MinZ, .MinX_MinY_MaxZ]
            case Right:
                return [.MaxX_MaxY_MaxZ, .MaxX_MinY_MaxZ, .MaxX_MinY_MinZ, .MaxX_MaxY_MinZ]
            case Top:
                return [.MaxX_MaxY_MaxZ, .MaxX_MaxY_MinZ, .MinX_MaxY_MinZ, .MinX_MaxY_MaxZ]
            case Bottom:
                return [.MaxX_MinY_MaxZ, .MinX_MinY_MaxZ, .MinX_MinY_MinZ, .MaxX_MinY_MinZ]
            }
        }
        
        static let frustumPlanes : [PlaneDirection] = [.Near, .Far, .Left, .Right, .Top, .Bottom]
    }
    
    let planes : [PlaneDirection : FrustumPlane]
    
    init(worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4) {
        let vp = projectionMatrix * worldToCameraMatrix
        
        var planes = [PlaneDirection : FrustumPlane]()
        
        planes[.Left] = FrustumPlane(normalVector: Vector3((vp[0][3] + vp[0][0]), (vp[1][3] + vp[1][0]), (vp[2][3] + vp[2][0])), constant: (vp[3][3] + vp[3][0]))
        
        planes[.Right] = FrustumPlane(normalVector: Vector3((vp[0][3] - vp[0][0]), (vp[1][3] - vp[1][0]), (vp[2][3] - vp[2][0])), constant: (vp[3][3] - vp[3][0]))
        
        planes[.Top] = FrustumPlane(normalVector: Vector3((vp[0][3] - vp[0][0]), (vp[1][3] - vp[1][0]), (vp[2][3] - vp[2][0])), constant: (vp[3][3] - vp[3][0]))
        
        planes[.Bottom] = FrustumPlane(normalVector: Vector3((vp[0][3] + vp[0][1]), (vp[1][3] + vp[1][1]), (vp[2][3] + vp[2][1])), constant: (vp[3][3] + vp[3][1]))
            
        planes[.Near] = isGL ?
            FrustumPlane(normalVector: Vector3((vp[0][3] + vp[0][2]), (vp[1][3] + vp[1][2]), (vp[2][3] + vp[2][2])), constant: (vp[3][3] + vp[3][2]))
            :
            FrustumPlane(normalVector: Vector3(vp[0][2], vp[1][2], vp[2][2]), constant: vp[3][2]);
        
        planes[.Far] = FrustumPlane(normalVector: Vector3((vp[0][3] - vp[0][2]), (vp[1][3] - vp[1][2]), (vp[2][3] - vp[2][2])), constant: (vp[3][3] - vp[3][2]));
        
        self.planes = planes
    }
    
    func enclosesPoint(point: Vector3) -> Bool {
        for plane in planes.values {
            if plane.distanceTo(point) < 0 {
                return false
            }
        }
        return true
    }
    
    func containsBox(boundingBox: BoundingBox) -> Bool {
        
        for (_, plane) in planes {
            var shouldContinue = false
            for extent in Extent.values {
                if plane.distanceTo(boundingBox.pointAtExtent(extent)) > 0 {
                    shouldContinue = true
                    break
                }
            }
            if !shouldContinue { return false }
        }
        
        return true
    }
    
    func containsSphere(centre: Vector3, radius: Float) -> Bool {
        for plane in planes.values {
            let distance = plane.distanceTo(centre)
            if distance <= -radius {
                return false
            }
        }
        return true
    }
    
}