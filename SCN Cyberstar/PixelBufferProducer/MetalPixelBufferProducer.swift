//
//  MetalPixelBufferProducer.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 23.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage

#if !targetEnvironment(simulator)

extension MetalPixelBufferProducer {
    enum Error: Swift.Error {
        case lastDrawable
        case lockBaseAddress(errorCode: CVReturn)
        case getBaseAddress
        case emptySource
        case unlockBaseAddress(errorCode: CVReturn)
        case framebufferOnly
    }
}

final class MetalPixelBufferProducer {
    
    lazy var recommendedPixelBufferAttributes: [String : Any] = {
        var attributes: [String : Any] = [
            kCVPixelBufferWidthKey as String: metalLayer.drawableSize.width,
            kCVPixelBufferHeightKey as String: metalLayer.drawableSize.height,
            kCVPixelBufferPixelFormatTypeKey as String: metalLayer.pixelFormat.pixelFormatType,
            kCVPixelBufferIOSurfacePropertiesKey as String : [:]
        ]
        
        if let iccData = metalLayer.pixelFormat.iccData {
            attributes[kCVBufferPropagatedAttachmentsKey as String] = [
                kCVImageBufferICCProfileKey: iccData
            ]
        }
        
        return attributes
    }()
    
    var emptyBufferSize: Int = 0
    
    var emptyBuffer: UnsafeMutableRawPointer?
    
    let metalLayer: CAMetalRecordableLayer
    
    init(metalLayer: CAMetalRecordableLayer) {
        self.metalLayer = metalLayer
    }
    
    deinit {
        emptyBuffer.map({ free($0) })
    }
    
    func writeIn(pixelBuffer: inout CVPixelBuffer) throws {
        
        guard let lastDrawable = metalLayer.lastDrawable else {
            throw Error.lastDrawable
        }
        
        let texture = lastDrawable.texture
        guard !texture.isFramebufferOnly else {
            throw Error.framebufferOnly
        }
        
        var errorCode = CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard errorCode == kCVReturnSuccess else {
            throw Error.lockBaseAddress(errorCode: errorCode)
        }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw Error.getBaseAddress
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        texture.getBytes(baseAddress,
                         bytesPerRow: bytesPerRow,
                         from: MTLRegionMake2D(0,
                                               0,
                                               CVPixelBufferGetWidth(pixelBuffer),
                                               height),
                         mipmapLevel: 0)
        
        guard !isEmpty(baseAddress, size: bytesPerRow * height) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            throw Error.emptySource
        }
        
        errorCode = CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        guard errorCode == kCVReturnSuccess else {
            throw Error.unlockBaseAddress(errorCode: errorCode)
        }
    }
    
    func isEmpty(_ buffer: UnsafeMutableRawPointer, size: Int) -> Bool {
        if emptyBufferSize != size || emptyBuffer == nil {
            emptyBufferSize = size
            emptyBuffer.map({ free($0) })
            emptyBuffer = calloc(size, 1)
        }
        
        guard let emptyBuffer = emptyBuffer else {
            return false
        }
        
        return memcmp(buffer, emptyBuffer, size) == 0
    }
}

#endif
