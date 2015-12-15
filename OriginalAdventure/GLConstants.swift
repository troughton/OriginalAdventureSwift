//
//  GLConstants.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

typealias RendererType = GLDeferredRenderer
typealias MeshType = GLMesh

let isGL = true

func CurrentTime() -> Double {
    return glfwGetTime()
}
