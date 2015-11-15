//
//  CameraNode.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 19/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Cocoa

class Camera : TransformNode {
    var fieldOfView : Float = Float(M_PI/3)
    var hdrMaxIntensity : Float = 1
}
