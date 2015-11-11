//
//  AppDelegate.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 18/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Cocoa

func errorCallback(error : Int32, description : UnsafePointer<Int8>) {
    fputs(description, stderr);
}

func keyCallback(window: COpaquePointer, key: Int32, scancode: Int32, action: Int32, mods: Int32)
{
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
        glfwSetWindowShouldClose(window, GL_TRUE);
    }
}

func main() {
    var game : Game = OriginalAdventure()
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
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
    glfwWindowHint(GLFW_SAMPLES, 0);
    glfwWindowHint(GLFW_SRGB_CAPABLE, GL_TRUE);
    
    window = glfwCreateWindow(WindowDimension.defaultDimension.width, WindowDimension.defaultDimension.height, game.title, nil, nil);
    if (window == nil) {
        glfwTerminate();
        exit(EXIT_FAILURE);
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);
    
    glfwSetKeyCallback(window, keyCallback);
    
    glfwShowWindow(window);
    
    game.size = WindowDimension.defaultDimension
    game.setupRendering()
    
    while (glfwWindowShouldClose(window) == 0) {
        
        var error = glGetError()
        if error != 0 {
            assertionFailure("OpenGL error \(error)")
        }
        let currentTime = glfwGetTime()
        
        game.update(delta: currentTime - timeLastUpdate)
        
        timeLastUpdate = glfwGetTime()
        glfwSwapBuffers(window);
        
        glfwPollEvents();
    }
    
    glfwDestroyWindow(window);
    
    glfwTerminate();
    exit(EXIT_SUCCESS);
}

main()
