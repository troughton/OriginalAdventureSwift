//
//  PlayerBehaviour.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 15/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class PlayerBehaviour : Behaviour {
    
    private let _playerSpeed : Float = 600; //units per second
    
    override init(gameObject: GameObject) {
        super.init(gameObject: gameObject)
        
        self.gameObject.camera = Camera(id: gameObject.id + "CameraTranslation", parent: gameObject, translation: Vector3(0, 60, 0))
    }
    
    /**
     * Moves the player in the direction specified by the EventDataKeys.Direction key in the data dictionary.
     */
    func moveInDirection(eventObject: Input, data: [EventDataKey : Any]) {
        let direction = data[.Direction] as! Vector3
        let elapsedTime = data[.ElapsedTime] as! Float;
        self.move(direction * (_playerSpeed * elapsedTime));
    };
    
    
    //static let eventPlayerMoved = Event<PlayerBehaviour>(name: "PlayerMoved");
    static let eventPlayerSlotSelected = Event<PlayerBehaviour>(name: "PlayerSlotSelected");
    
    
    private func move(vector: Vector3) {
        
        let translation = self.gameObject.rotation * vector;
        let lateralTranslation = normalize(Vector3(translation.x, 0, translation.z)) * length(vector);
        
        var successfullyMoved = self.attemptMoveDirect(Vector3(lateralTranslation.x, 0, 0));
        successfullyMoved = self.attemptMoveDirect(Vector3(0, 0, lateralTranslation.z)) || successfullyMoved;
        
//        if (successfullyMoved) {
//            PlayerBehaviour.eventPlayerMoved.trigger(onObject: self, data: self.gameObject.translation);
//        }
    }
    
    private func attemptMoveDirect(translation: Vector3) -> Bool {
        
        let startingTranslation = self.gameObject.translation;
        
        self.gameObject.translateBy(translation);
        
        guard let collider = self.gameObject.collider else { return true; }
        
        let canMove = !collider.isColliding()
        
        if(!canMove) {
            self.gameObject.translation = startingTranslation;
        }
        
        return canMove;
    }
    
    func lookInDirection(angleX: Float, angleY: Float) {
        
        let rotation = Quaternion(angle: angleX, axis: 0, -1, 0) * Quaternion(angle: angleY, axis: -1, 0, 0);
        self.gameObject.rotation = rotation;
        
//        PlayerBehaviour.eventPlayerMoved.trigger(this,
//            Collections.singletonMap(EventDataKeys.Quaternion, rotatedNode.rotation()));
    }
    
//    @Override
//    public List<Interaction> possibleInteractions(final MeshNode meshNode, final Player otherPlayer) {
//    if (otherPlayer.inventory().selectedItem().isPresent() && !this.inventory().isFull()) {
//    return Collections.singletonList(new Interaction(InteractionType.Give, this, meshNode));
//    } else {
//    return Collections.singletonList(new Interaction(InteractionType.DisplayName, this, meshNode));
//    }
//    }
//    
//    @Override
//    public void performInteraction(final Interaction interaction, final MeshNode meshNode, final Player otherPlayer) {
//    switch (interaction.interactionType) {
//    case Give:
//    otherPlayer.inventory().selectedItem().ifPresent(item -> {
//    item.moveToContainer(this.inventory());
//    item.eventPlayerDroppedItem.trigger(otherPlayer, Collections.emptyMap());
//    item.eventPlayerPickedUpItem.trigger(this, Collections.emptyMap());
//    });
//    break;
//    }
//    }
}