//
//  MetalConstants.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

typealias RendererType = MTLDeferredRenderer
typealias MeshType = MTLMesh

let isGL = false

func CurrentTime() -> Double {
    return NSDate.timeIntervalSinceReferenceDate()
}