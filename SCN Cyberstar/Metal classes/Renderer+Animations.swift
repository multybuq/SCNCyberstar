//
//  Renderer+Animations.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 07.12.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import Foundation

extension Renderer {
    func pause() {
        self.animationIsPaused = true
    }
    
    func play() {
        self.animationIsPaused = false
    }
    
    func setSpeed(speed: Float) {
        self.timestep = Double(speed)/60.0
    }
}
