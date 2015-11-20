//
//  File.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 23/10/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

protocol Game {
    /**
    * @return The name to display in the title bar.
    */
    var title : String { get }
    
    var size : WindowDimension! { get set }
    
    var sizeInPixels : WindowDimension! { get set }
    
    func setupRendering()
    
    /**
    * Called every frame to update the game.
    */
    func update(delta delta: Double)
    
    var input : Input { get }
    
    func onMouseMove(delta x: Float, _ y: Float)
    
//    /**
//    * @return The instance of KeyInput that the GameDelegate should pass events to.
//    */
//    KeyInput keyInput();
//    
//    /**
//    * @return The instance of MouseInput that the GameDelegate should pass mouse press/held/released events to.
//    */
//    MouseInput mouseInput();
//    
//    /**
//    * Called when the mouse moves.
//    * @param deltaX The x delta movement.
//    * @param deltaY The y delta movement.
//    */
//    void onMouseDeltaChange(float deltaX, float deltaY);

}