//
//  Extensions.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 20.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import ARKit

extension ARSCNView{
    
    func smartHitTest(_ point: CGPoint,
                      infinitePlane: Bool = false,
                      objectPosition: simd_float3? = nil,
                      allowedAlignments: [ARPlaneAnchor.Alignment] = [.horizontal, .vertical]) -> ARHitTestResult? {
        
        // Perform the hit test.
        let results = hitTest(point, types: [.existingPlaneUsingGeometry, .estimatedVerticalPlane, .estimatedHorizontalPlane])
        
        // 1. Check for a result on an existing plane using geometry.
        if let existingPlaneUsingGeometryResult = results.first(where: { $0.type == .existingPlaneUsingGeometry }),
            let planeAnchor = existingPlaneUsingGeometryResult.anchor as? ARPlaneAnchor, allowedAlignments.contains(planeAnchor.alignment) {
            return existingPlaneUsingGeometryResult
        }
        
        if infinitePlane {
            
            // 2. Check for a result on an existing plane, assuming its dimensions are infinite.
            //    Loop through all hits against infinite existing planes and either return the
            //    nearest one (vertical planes) or return the nearest one which is within 5 cm
            //    of the object's position.
            let infinitePlaneResults = hitTest(point, types: .existingPlane)
            
            for infinitePlaneResult in infinitePlaneResults {
                if let planeAnchor = infinitePlaneResult.anchor as? ARPlaneAnchor, allowedAlignments.contains(planeAnchor.alignment) {
                    if planeAnchor.alignment == .vertical {
                        // Return the first vertical plane hit test result.
                        return infinitePlaneResult
                    } else {
                        // For horizontal planes we only want to return a hit test result
                        // if it is close to the current object's position.
                        if let objectY = objectPosition?.y {
                            let planeY = infinitePlaneResult.worldTransform.translation.y
                            if objectY > planeY - 0.05 && objectY < planeY + 0.05 {
                                return infinitePlaneResult
                            }
                        } else {
                            return infinitePlaneResult
                        }
                    }
                }
            }
        }
        
        // 3. As a final fallback, check for a result on estimated planes.
        let vResult = results.first(where: { $0.type == .estimatedVerticalPlane })
        let hResult = results.first(where: { $0.type == .estimatedHorizontalPlane })
        switch (allowedAlignments.contains(.horizontal), allowedAlignments.contains(.vertical)) {
        case (true, false):
            return hResult
        case (false, true):
            // Allow fallback to horizontal because we assume that objects meant for vertical placement
            // (like a picture) can always be placed on a horizontal surface, too.
            return vResult ?? hResult
        case (true, true):
            if hResult != nil && vResult != nil {
                return hResult!.distance < vResult!.distance ? hResult! : vResult!
            } else {
                return hResult ?? vResult
            }
        default:
            return nil
        }
    }
}

extension float4x4 {
    /**
     Treats matrix as a (right-hand column-major convention) transform matrix
     and factors out the translation component of the transform.
    */
    var translation: simd_float3 {
        get {
            let translation = columns.3
            return simd_float3(translation.x, translation.y, translation.z)
        }
        set(newValue) {
            columns.3 = simd_float4(newValue.x, newValue.y, newValue.z, columns.3.w)
        }
    }
    
    /**
     Factors out the orientation component of the transform.
    */
    var orientation: simd_quatf {
        return simd_quaternion(self)
    }
    
    /**
     Creates a transform matrix with a uniform scale factor in all directions.
     */
    init(uniformScale scale: Float) {
        self = matrix_identity_float4x4
        columns.0.x = scale
        columns.1.y = scale
        columns.2.z = scale
    }
}

// MARK: - CGPoint extensions

extension CGPoint {
    /// Extracts the screen space point from a vector returned by SCNView.projectPoint(_:).
    init(_ vector: SCNVector3) {
        self.init(x: CGFloat(vector.x), y: CGFloat(vector.y))
    }

    /// Returns the length of a point when considered as a vector. (Used with gesture recognizers.)
    var length: CGFloat {
        return sqrt(x * x + y * y)
    }
}

extension simd_float3 {
    func distance(to anotherVector: simd_float3) -> Float {
        let direction = simd_float3(self.x - anotherVector.x, self.y - anotherVector.y, self.z - anotherVector.z)
        let f = sqrtf(direction.x*direction.x + direction.y*direction.y + direction.z*direction.z)
        return f
    }
}
