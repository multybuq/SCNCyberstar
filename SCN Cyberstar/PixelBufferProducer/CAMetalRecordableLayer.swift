//
//  CAMetalRecordableLayer.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 23.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import Foundation
import UIKit

#if !targetEnvironment(simulator)

open class CAMetalRecordableLayer: UIKit.CAMetalLayer {
    
    lazy var lastFramebufferOnly: Bool = framebufferOnly
    
    open override var framebufferOnly: Bool {
        get {
            return super.framebufferOnly
        }
        set {
            if recording {
                lastFramebufferOnly = newValue
            }
            else {
                super.framebufferOnly = newValue
            }
        }
    }
    
    var recording: Bool = false
    
    open var lastDrawable: CAMetalDrawable?
    
    open override func nextDrawable() -> CAMetalDrawable? {
        lastDrawable = super.nextDrawable()
        return lastDrawable
    }
    
    func startRecording() {
        guard !recording else { return }
        lastFramebufferOnly = framebufferOnly
        framebufferOnly = false
        recording = true
    }
    
    func stopRecording() {
        guard recording else { return }
        recording = false
        framebufferOnly = lastFramebufferOnly
    }
}

#endif
