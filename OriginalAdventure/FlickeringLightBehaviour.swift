//
//  FlickeringLightBehaviour.swift
//  OriginalAdventure
//
//  Created by Thomas Roughton on 16/11/15.
//  Copyright © 2015 Thomas Roughton. All rights reserved.
//

import Foundation

class FlickeringLightBehaviour : Behaviour, Hashable {
 
    private let LightAnimationTime : AnimationFloat = 0.3;
    
    var isOn = true
    
    private var _intensityVariation : Float = 0
    
    var intensityVariation : Float {
        get {
            return _intensityVariation
        }
        set(newVariation) {
            _intensityVariation = newVariation
            self.applyLightParameters()
        }
    }
    
    private var _isAnimatingToggle = false;
    
    private var _lightIntensity : AnimableProperty = AnimableProperty(value: 0);
    
    private var _baseIntensity : Float = 0
    
    var intensity : Float {
        get {
            return _baseIntensity
        }
        set(newValue) {
            _baseIntensity = newValue
            self.applyLightParameters()
        }
    }
    
    static let eventLightToggled = Event<FlickeringLightBehaviour>(name: "LightToggled");
    
    func animateToggleLight(triggeringObject : SceneNode, data: Any...) {
        let turnOn = data[0] as! Bool
        if  (!self.isOn && turnOn) {
            _isAnimatingToggle = true;
            let animation = Animation(animableProperty: _lightIntensity, duration: AnimationFloat(LightAnimationTime), toValue: AnimationFloat(_baseIntensity));
            Animation.eventAnimationDidComplete.filter(animation).addAction({ (eventObject) -> () in
                self.applyLightParameters()
                self._isAnimatingToggle = false
            })
            self.isOn = true;
            
            self.gameObject.isEnabled = true
            
            FlickeringLightBehaviour.eventLightToggled.trigger(onObject: self)
        } else if (self.isOn && !turnOn) {
            _isAnimatingToggle = true;
            let animation = Animation(animableProperty: _lightIntensity, duration: LightAnimationTime, toValue: 0);
            self.isOn = false;
            Animation.eventAnimationDidComplete.filter(animation).addAction({ (eventObject) -> () in
                self.gameObject.isEnabled = false;
                self._isAnimatingToggle = false
            })
            FlickeringLightBehaviour.eventLightToggled.trigger(onObject: self)
        }
    }
    
    override init(gameObject: GameObject) {
        
        super.init(gameObject: gameObject)
        
        guard let light = gameObject.light else { assertionFailure("A flickering light requires that its game object has a light."); return }
        
        _baseIntensity = light.intensity;
        _lightIntensity = AnimableProperty(value: AnimationFloat(light.intensity));
        
        AnimableProperty.eventValueChanged.filter(_lightIntensity).addAction { (eventObject) -> () in
            light.intensity = Float(self._lightIntensity.value)
            self.setMaterialColour(&gameObject.mesh!.materialOverride!, colour: light.colour, intensity: Float(self._lightIntensity.value))
        }
        
        gameObject.mesh!.materialOverride = self.setupMaterial(light.colour, intensity: _baseIntensity);
        
        self.applyLightParameters()
    }
    
    private func setMaterialColour(inout material: Material, colour: Vector3, intensity: Float) {
        material.diffuseColour = colour * 0.25
        material.ambientColour = colour * intensity;
    }
    
    private func setupMaterial(colour: Vector3, intensity: Float) -> Material {
        var material = Material.defaultMaterial
        self.setMaterialColour(&material, colour: colour, intensity: intensity);
        material.specularColour = Vector3.Zero;
        material.useAmbient = true;
        return material;
    }
    
    func applyLightParameters() {
        if (self.isOn) {
            let lowIntensity = _baseIntensity - intensityVariation / 2;
            let highIntensity = _baseIntensity + intensityVariation / 2;
            
            _lightIntensity.animation = nil;
            _ = Animation(randomAnimationWithProperty: _lightIntensity, from: AnimationFloat(lowIntensity), to: AnimationFloat(highIntensity));
        }
    }

    var hashValue : Int {
        return ObjectIdentifier(self).hashValue
    }
}

func ==(lhs: FlickeringLightBehaviour, rhs: FlickeringLightBehaviour) -> Bool {
    return lhs.hashValue == rhs.hashValue
}