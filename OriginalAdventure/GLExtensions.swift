//
//  File.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 7/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation
import OpenGL.GL3

public func glGenTexture() -> GLuint {
    var value : GLuint = 0
    glGenTextures(1, &value)
    return value
}