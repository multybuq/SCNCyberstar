//
//  ARSCNViewRecordable.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 23.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import Foundation
import ARKit

open class ARSCNViewRecordable: ARSCNView {

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
