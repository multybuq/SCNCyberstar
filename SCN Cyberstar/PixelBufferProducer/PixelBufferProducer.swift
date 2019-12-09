//
//  PixelBufferProducer.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 24.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import Foundation
import AVFoundation
import SceneKit
import MetalKit

extension PixelBufferProducer {
    enum Error: Swift.Error {
        case metalLayer
        case commonError
        case simulator
        case pixelBuffer(errorCode: CVReturn)
        case pixelBufferFactory
    }
}

class PixelBufferProducer {
    var sceneView: SCNView?
    var mtkView: MTKView?
    let queue: DispatchQueue
    private var pixelBufferProducer: MetalPixelBufferProducer
    private lazy var pixelBufferPool: CVPixelBufferPool = {
        var unmanagedPixelBufferPool: CVPixelBufferPool?
        let errorCode = CVPixelBufferPoolCreate(nil,
                                                nil,
                                                pixelBufferProducer.recommendedPixelBufferAttributes as CFDictionary,
                                                &unmanagedPixelBufferPool)
        guard errorCode == kCVReturnSuccess, let pixelBufferPool = unmanagedPixelBufferPool else {
            fatalError("CVPixelBufferPoolCreate Error: \(errorCode)")
        }
        return pixelBufferPool
    }()
    
    public init(_ sceneView: SCNView) throws {
        self.sceneView = sceneView
        self.queue = DispatchQueue(label: "com.dreval.scncyberstar.producerQueue", qos: .userInitiated)
        switch sceneView.renderingAPI {
        case .metal:
            #if !targetEnvironment(simulator)
            guard let metalLayer = sceneView.layer as? CAMetalRecordableLayer else {
                throw Error.metalLayer
            }
            pixelBufferProducer = MetalPixelBufferProducer(metalLayer: metalLayer)
            #else
            throw Error.simulator
            #endif
        default:
            throw Error.metalLayer
        }
    }
    
    public init(_ mtkView: MTKView) throws {
        self.mtkView = mtkView
        self.queue = DispatchQueue(label: "com.dreval.scncyberstar.producerQueue", qos: .userInitiated)
        #if !targetEnvironment(simulator)
        guard let metalLayer = mtkView.layer as? CAMetalRecordableLayer else {
            throw Error.metalLayer
        }
        pixelBufferProducer = MetalPixelBufferProducer(metalLayer: metalLayer)
        #else
        throw Error.simulator
        #endif
    }
    
    func producePixelBuffer() -> CVPixelBuffer? {
        var unmanagedPixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferPoolCreatePixelBuffer(nil,
                                                        pixelBufferPool,
                                                        &unmanagedPixelBuffer)
        guard result == kCVReturnSuccess, var pixelBuffer = unmanagedPixelBuffer else {
            return nil
        }
        do {
            try pixelBufferProducer.writeIn(pixelBuffer: &pixelBuffer)
        }
        catch {
        }
        return pixelBuffer
    }
}
