//
//  Octree.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 13/12/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

enum Extent : Int {
    case MinX_MinY_MinZ = 0b000
    case MinX_MinY_MaxZ = 0b001
    case MinX_MaxY_MinZ = 0b010
    case MinX_MaxY_MaxZ = 0b011
    case MaxX_MinY_MinZ = 0b100
    case MaxX_MinY_MaxZ = 0b101
    case MaxX_MaxY_MinZ = 0b110
    case MaxX_MaxY_MaxZ = 0b111
    case LastElement
    
    static let MaxXFlag = 0b100
    static let MaxYFlag = 0b010
    static let MaxZFlag = 0b001
    
    static let values = (0..<Extent.LastElement.rawValue).map { rawValue -> Extent in return Extent(rawValue: rawValue)! }
}

class OctreeNode<T> {
    
    var values = [T]()
    let boundingVolume : BoundingBox
    private var children = [OctreeNode<T>?](count: Extent.LastElement.rawValue, repeatedValue: nil)
    
    lazy var boundingSphere : (centre: Vector3, radius: Float) = {
        let diameter = max(self.boundingVolume.width, self.boundingVolume.height, self.boundingVolume.depth)
        return (self.boundingVolume.centre, diameter/2)
    }()
    
    private let _subVolumes : [BoundingBox]
    
    private static func computeSubVolumesForBox(boundingBox: BoundingBox) -> [BoundingBox] {
        var volumes = [BoundingBox?](count: Extent.LastElement.rawValue, repeatedValue: nil)
        
        let centre = boundingBox.centre
        
        for xToggle in 0..<2 {
            for yToggle in 0..<2 {
                for zToggle in 0..<2 {
                    let x = xToggle == 0 ? boundingBox.minPoint.x : boundingBox.maxPoint.x;
                    let y = yToggle == 0 ? boundingBox.minPoint.y : boundingBox.maxPoint.y;
                    let z = zToggle == 0 ? boundingBox.minPoint.z : boundingBox.maxPoint.z;
                    
                    let index = xToggle << 2 | yToggle << 1 | zToggle
                    
                    volumes[index] = (
                        BoundingBox(
                            minPoint: Vector3(min(x, centre.x), min(y, centre.y), min(z, centre.z)),
                            maxPoint: Vector3(max(x, centre.x), max(y, centre.y), max(z, centre.z))
                        )
                    )
                }
            }
        }
        
        return volumes.flatMap { $0 }
    }
    
    init(boundingVolume: BoundingBox) {
        self.boundingVolume = boundingVolume
        
        _subVolumes = OctreeNode.computeSubVolumesForBox(boundingVolume)
    }
    
    subscript(extent: Extent) -> OctreeNode<T>? {
        return self[extent.rawValue]
    }
    
    private subscript(index: Int) -> OctreeNode<T>? {
        return self.children[index]
    }
    
    
    func append(element: T, boundingBox: BoundingBox) {
        for (i, subVolume) in _subVolumes.enumerate() {
            if subVolume.contains(boundingBox) {
                (self[i] ?? {
                    let node = OctreeNode<T>(boundingVolume: _subVolumes[i])
                    self.children[i] = node
                    return node
                }())
                .append(element, boundingBox: boundingBox)
                return
            }
        }
        
        values.append(element)
    }
    
    func traverse(@noescape function: ([T]) -> ()) {
        function(values)
        for child in children {
            child?.traverse(function)
        }
    }
}

extension OctreeNode where T : Mesh {
    
}