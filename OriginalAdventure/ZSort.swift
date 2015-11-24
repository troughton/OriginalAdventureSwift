//
//  ZSort.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 21/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

typealias MeshPair = (mesh: Mesh, boundingBox: BoundingBox)
func zSort(meshes: [Mesh], worldToCameraMatrix: Matrix4) -> [Mesh] {
    return meshes.lazy.map { (mesh) -> MeshPair in
        let b = mesh.boundingBox.axisAlignedBoundingBoxInSpace(worldToCameraMatrix * mesh.worldSpaceTransform)
        return (mesh: mesh, boundingBox: b)
    }.filter { (pair: MeshPair) -> Bool in
        return pair.boundingBox.minZ < 0
    }.sort { (pair1: MeshPair, pair2: MeshPair) -> Bool in
        return pair1.boundingBox.maxZ > pair2.boundingBox.maxZ
    }.map { (pair: MeshPair) -> Mesh in
        return pair.mesh
    }
}