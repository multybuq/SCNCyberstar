//
//  MTKViewRecordable.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 07.12.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import Foundation
import MetalKit

open class MTKViewRecordable: MTKView {

    #if !targetEnvironment(simulator)

    override open class var layerClass: AnyClass {
        return CAMetalRecordableLayer.self
    }

    var metalLayer: CAMetalRecordableLayer? {
        return layer as? CAMetalRecordableLayer
    }

    var lastDrawable: CAMetalDrawable? {
        return metalLayer?.lastDrawable
    }
    #endif
}
