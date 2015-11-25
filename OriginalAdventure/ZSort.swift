//
//  ZSort.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 21/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

typealias MeshPair = (mesh: Mesh, boundingBox: BoundingBox)
func zSort(inout meshes: [Mesh], worldToCameraMatrix: Matrix4) {
    meshes.sortInPlace { (mesh1, mesh2) -> Bool in
        let z1 = mesh1.boundingBox.maxZForBoundingBoxInSpace(worldToCameraMatrix * mesh1.worldSpaceTransform)
        let z2 = mesh2.boundingBox.maxZForBoundingBoxInSpace(worldToCameraMatrix * mesh2.worldSpaceTransform)
        return z1 > z2
    }
}