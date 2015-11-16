//
//  GLRenderer.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 29/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

protocol Renderer  {
    
    var size : WindowDimension { get set }
    var sizeInPixels : WindowDimension { get set }
    
    func render(nodes: [GameObject], lights: [Light], worldToCameraMatrix: Matrix4, fieldOfView: Float, hdrMaxIntensity: Float)
    
    func render(nodes: [GameObject], lights: [Light], worldToCameraMatrix: Matrix4, projectionMatrix: Matrix4, hdrMaxIntensity: Float)
}