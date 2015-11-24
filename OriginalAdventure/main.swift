//
//  AppDelegate.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 18/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Cocoa
import OpenGL.GL3

var game : Game = OriginalAdventure()
var windowSize = WindowDimension.defaultDimension
private var _mouseLocked = false

func errorCallback(error : Int32, description : UnsafePointer<Int8>) {
    fputs(description, stderr);
}

func keyCallback(window: COpaquePointer, key: Int32, scancode: Int32, action: Int32, mods: Int32) {
    
    // pass off alphabetic key input to the game
    let keyChar = UnicodeScalar(UInt32(key))
    if (action == GLFW_PRESS) {
        game.input.pressKey(keyChar);
    } else if (action == GLFW_RELEASE) {
        game.input.releaseKey(keyChar);
    }
    
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
        glfwSetWindowShouldClose(window, GL_TRUE);
    }
}

func windowSizeCallback(window: COpaquePointer, width: Int32, height: Int32) -> Void {
    windowSize = WindowDimension(width: width, height: height)
    game.size = windowSize
}

func framebufferSizeCallback(window: COpaquePointer, width: Int32, height: Int32) -> Void {
    glViewport(0, 0, width, height);
    game.sizeInPixels = WindowDimension(width: width, height: height);
}

func main() {
    let window : COpaquePointer;
    var timeLastUpdate = 0.0;
    
    glfwSetErrorCallback(errorCallback)
    
    if (glfwInit() == 0) {
        exit(EXIT_FAILURE);
    }
    
    // Configure our _window
    glfwDefaultWindowHints(); // optional, the current _window hints are already the default
    glfwWindowHint(GLFW_VISIBLE, GL_FALSE); // the _window will stay hidden after creation
    glfwWindowHint(GLFW_RESIZABLE, GL_TRUE); // the _window will be resizable
    
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
    glfwWindowHint(GLFW_SAMPLES, 0);
    glfwWindowHint(GLFW_SRGB_CAPABLE, GL_TRUE);
    
    window = glfwCreateWindow(windowSize.width, windowSize.height, game.title, nil, nil);
    if (window == nil) {
        glfwTerminate();
        exit(EXIT_FAILURE);
    }
    

    glfwMakeContextCurrent(window);
    glfwSwapInterval(0);
    
    glfwSetKeyCallback(window, keyCallback);
    glfwSetWindowSizeCallback(window, windowSizeCallback)
    glfwSetFramebufferSizeCallback(window, framebufferSizeCallback)
    
    glfwShowWindow(window);
    
    game.size = windowSize
    
    var pixelWidth : Int32 = 0
    var pixelHeight : Int32 = 0
    glfwGetFramebufferSize(window, &pixelWidth, &pixelHeight);
    game.sizeInPixels = WindowDimension(width: pixelWidth, height: pixelHeight)
    
    game.setupRendering()
    
    while (glfwWindowShouldClose(window) == 0) {
        
        AnimationSystem.update()
        let currentTime = glfwGetTime()
        let elapsedTime = currentTime - timeLastUpdate
        
        handleMouseInput(window, dimensions: windowSize);
        pollInput(window, elapsedTime: Float(elapsedTime));
        
        game.update(delta: elapsedTime)
        
        timeLastUpdate = currentTime
        glfwSwapBuffers(window);
    }
    
    glfwDestroyWindow(window);
    
    glfwTerminate();
    exit(EXIT_SUCCESS);
    
}

func pollInput(window: COpaquePointer, elapsedTime: Float) {
    glfwPollEvents();
    
    game.input.checkHeldKeys({ (input) -> Bool in
        if let character = input as? UnicodeScalar {
            return glfwGetKey(window, Int32(character.value)) == GLFW_PRESS
        } else if let button = input as? MouseButton {
            var glfwButton : Int32
            switch button {
            case .Left:
                glfwButton = GLFW_MOUSE_BUTTON_LEFT
            case .Right:
                glfwButton = GLFW_MOUSE_BUTTON_RIGHT
            }
            return glfwGetMouseButton(window, glfwButton) == GLFW_PRESS
        } else {
            return false
        }
        
        }, elapsedTime: elapsedTime)
    
}

private func unlockMouse(window: COpaquePointer) {
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
    _mouseLocked = false;
}

private func lockMouse(window: COpaquePointer, dimensions: WindowDimension) {
    // hide mouse cursor and move cursor to centre of window
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    glfwSetCursorPos(window, Double(dimensions.width / 2), Double(dimensions.height / 2));
    
    _mouseLocked = true;
}

private func handleMouseInput(window: COpaquePointer, dimensions: WindowDimension) {
    if (!_mouseLocked && glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_1) == GLFW_PRESS) {
        lockMouse(window, dimensions: dimensions);
    }
    
    if (_mouseLocked) {
        var x : Double = 0
        var y : Double = 0
        
        glfwGetCursorPos(window, &x, &y);
        
        let deltaX = x - Double(dimensions.width/2);
        let deltaY = y - Double(dimensions.height/2);
        
        game.onMouseMove(delta: Float(deltaX), Float(deltaY));
        
        glfwSetCursorPos(window, Double(dimensions.width / 2), Double(dimensions.height / 2))
    }
}

main()
