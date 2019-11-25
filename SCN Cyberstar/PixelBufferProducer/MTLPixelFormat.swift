//
//  MTLPixelFormat.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 23.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import Foundation
import AVFoundation

#if !targetEnvironment(simulator)

extension MTLPixelFormat {
    static let undocumented_bgr10_xr_srgb = MTLPixelFormat(rawValue: 551) ?? .bgr10_xr_srgb
    var colorSpace: CGColorSpace {
        var colorSpace: CGColorSpace?
        
        switch self {

        case .bgr10_xr_srgb, .undocumented_bgr10_xr_srgb:
            colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        
        default:
            colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        }
        
        return colorSpace ?? CGColorSpaceCreateDeviceRGB()
        
    }
    
    var iccData: CFData? {
        return colorSpace.copyICCData()
    }
    
    var videoColorProperties: [String: String] {
        switch self {

        case .bgr10_xr_srgb, .undocumented_bgr10_xr_srgb:
            return [ AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
                     AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                     AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2 ]
            
        default:
            return [ AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                     AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                     AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2 ]
        }
    }
    
    var pixelFormatType: OSType {
        switch self {
        case .bgr10_xr_srgb, .undocumented_bgr10_xr_srgb:
            return kCVPixelFormatType_30RGBLEPackedWideGamut
        default:
            return kCVPixelFormatType_32BGRA
        }
    }
}

#endif
