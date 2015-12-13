//
//  Octree.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 13/12/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

enum Extent : Int {
    case minX_minY_minZ = 0b000
    case minX_minY_maxZ = 0b001
    case minX_maxY_minZ = 0b010
    case minX_maxY_maxZ = 0b011
    case maxX_minY_minZ = 0b100
    case maxX_minY_maxZ = 0b101
    case maxX_maxY_minZ = 0b110
    case maxX_maxY_maxZ = 0b111
    case LastElement
}

class OctreeNode<T> {
    
    private var _nodes = [T]()
    let boundingVolume : BoundingBox
    var children = [OctreeNode<T>?](count: Extent.LastElement.rawValue, repeatedValue: nil)
    
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
    
    func nodeAtExtent(extent: Extent) -> OctreeNode<T> {
        return self.nodeAtIndex(extent.rawValue)
    }
    
    private func nodeAtIndex(index: Int) -> OctreeNode<T> {
        if let node = self.children[index] {
            return node
        } else {
            let node = OctreeNode<T>(boundingVolume: _subVolumes[index])
            self.children[index] = node
            return node
        }
    }
    
    func append(element: T, boundingBox: BoundingBox) {
        for (i, subVolume) in _subVolumes.enumerate() {
            if subVolume.contains(boundingBox) {
                self.nodeAtIndex(i).append(element, boundingBox: boundingBox)
                return
            }
        }
        
        _nodes.append(element)
    }
    
    func traverse(@noescape function: ([T]) -> ()) {
        function(_nodes)
        for child in children {
            child?.traverse(function)
        }
    }
}