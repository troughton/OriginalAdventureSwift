//
//  GameViewController.swift
//  OriginalAdventureMetal
//
//  Created by Thomas Roughton on 22/11/15.
//  Copyright (c) 2015 Thomas Roughton. All rights reserved.
//

import Cocoa
import MetalKit

struct MetalState {
    var device: MTLDevice! = nil
    var view: MTKView! = nil
}

var Metal : MetalState = MetalState()

class GameViewController: NSViewController, MTKViewDelegate {
    
    var game : Game = OriginalAdventure()
    var timeLastUpdate : Double = 0
    
    var inputView : MTKInputView! = nil

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        Metal.device = MTLCreateSystemDefaultDevice()
        guard Metal.device != nil else { // Fallback to a blank NSView, an application could also fallback to OpenGL here.
            print("Metal is not supported on this device")
            self.view = NSView(frame: self.view.frame)
            return
        }

        // setup view properties
        self.inputView = self.view as! MTKInputView
        inputView.delegate = self
        inputView.device = Metal.device
        inputView.sampleCount = 1
        inputView.colorPixelFormat = .BGRA8Unorm_sRGB
        inputView.depthStencilPixelFormat = .Depth32Float_Stencil8
        
        Metal.view = inputView
        
        game.setupRendering()
        game.size = WindowDimension(width: Int32(view.bounds.size.width), height: Int32(view.bounds.size.height))
        
        inputView.game = game
        inputView.window?.makeFirstResponder(inputView)
    }
    
    func drawInMTKView(view: MTKView) {
        
        AnimationSystem.update()
        
        let currentTime = CurrentTime()
        let elapsedTime = currentTime - timeLastUpdate
        
        game.input.checkHeldKeys({ (inputSource) -> Bool in
            if let key = inputSource as? UnicodeScalar {
                return self.inputView.keysPressed.contains(key);
            } else {
                return false;
            }
            }, elapsedTime: Float(elapsedTime))
        
        game.update(delta: elapsedTime)
        
        timeLastUpdate = currentTime
        
    }
    
    
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        game.size = WindowDimension(width: Int32(size.width), height: Int32(size.height))
    }
}
