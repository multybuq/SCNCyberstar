/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SceneKit node giving the user hints about the status of ARKit world tracking.
*/

import Foundation
import ARKit

class FocusSquare: SCNNode {
   
    enum State: Equatable {
        case initializing
        case detecting(hitTestResult: ARHitTestResult, camera: ARCamera?)
    }
        
    //-------------------
    // MARK: - Properties
    //-------------------
    
    /// The most recent position of the focus square based on the current state.
    var lastPosition: simd_float3? {
        switch state {
        case .initializing: return nil
        case .detecting(let hitTestResult, _): return hitTestResult.worldTransform.translation
        }
    }
    
    var state: State = .initializing {
        didSet {
            guard state != oldValue else { return }
            
            switch state {
            case .initializing:
                displayAsBillboard()
                
            case let .detecting(hitTestResult, camera):
                if let planeAnchor = hitTestResult.anchor as? ARPlaneAnchor {
                    performCloseAnimation(flash: !anchorsOfVisitedPlanes.contains(planeAnchor))
                    displayAsClosed(for: hitTestResult, planeAnchor: planeAnchor, camera: camera)
                    currentPlaneAnchor = planeAnchor
                } else {
                    performOpenAnimation()
                    displayAsOpen(for: hitTestResult, camera: camera)
                    currentPlaneAnchor = nil
                }
            }
        }
    }
    
    /// Indicates whether the segments of the focus square are disconnected.
    public var isOpen = false
    
    /// Indicates if the square is currently being animated.
    private var isAnimating = false
    
    /// Indicates if the square is currently changing its alignment.
    private var isChangingAlignment = false
    
    /// The focus square's current alignment.
    private var currentAlignment: ARPlaneAnchor.Alignment?
    
    /// The current plane anchor if the focus square is on a plane.
    private(set) var currentPlaneAnchor: ARPlaneAnchor?
    
    /// The focus square's most recent positions.
    private var recentFocusSquarePositions: [simd_float3] = []
    
    /// The focus square's most recent alignments.
    private(set) var recentFocusSquareAlignments: [ARPlaneAnchor.Alignment] = []
    
    /// Previously visited plane anchors.
    private var anchorsOfVisitedPlanes: Set<ARAnchor> = []
    
    /// List of the segments in the focus square.
    private var segments: [FocusSquare.Segment] = []

    /// The primary node that controls the position of other `FocusSquare` nodes.
    private let positioningNode = SCNNode()
    
    // Original size of the focus square in meters.
    static let size: Float = 0.17
    
    // Thickness of the focus square lines in meters.
    static let thickness: Float = 0.018
    
    // Scale factor for the focus square when it is closed, w.r.t. the original size.
    static let scaleForClosedSquare: Float = 0.97
    
    // Side length of the focus square segments when it is open (w.r.t. to a 1x1 square).
    static let sideLengthForOpenSegments: CGFloat = 0.2
    
    // Duration of the open/close animation
    static let animationDuration = 0.7
    
    static let primaryColor = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1)
    
    // Color of the focus square fill.
    static let fillColor = #colorLiteral(red: 1, green: 0.9254901961, blue: 0.4117647059, alpha: 1)
    
    //-----------------------
    // MARK: - Initialization
    //-----------------------
    
    override init() {
        super.init()
        opacity = 0.0
        
        /*
         The focus square consists of eight segments as follows, which can be individually animated.
         
             s1  s2
             _   _
         s3 |     | s4
         
         s5 |     | s6
             -   -
             s7  s8
         */
        let s1 = Segment(name: "s1", corner: .topLeft, alignment: .horizontal)
        let s2 = Segment(name: "s2", corner: .topRight, alignment: .horizontal)
        let s3 = Segment(name: "s3", corner: .topLeft, alignment: .vertical)
        let s4 = Segment(name: "s4", corner: .topRight, alignment: .vertical)
        let s5 = Segment(name: "s5", corner: .bottomLeft, alignment: .vertical)
        let s6 = Segment(name: "s6", corner: .bottomRight, alignment: .vertical)
        let s7 = Segment(name: "s7", corner: .bottomLeft, alignment: .horizontal)
        let s8 = Segment(name: "s8", corner: .bottomRight, alignment: .horizontal)
        segments = [s1, s2, s3, s4, s5, s6, s7, s8]
        
        let sl: Float = 0.5  // segment length
        let c: Float = FocusSquare.thickness / 2 // correction to align lines perfectly
        s1.simdPosition += [-(sl / 2 - c), -(sl - c), 0]
        s2.simdPosition += [sl / 2 - c, -(sl - c), 0]
        s3.simdPosition += [-sl, -sl / 2, 0]
        s4.simdPosition += [sl, -sl / 2, 0]
        s5.simdPosition += [-sl, sl / 2, 0]
        s6.simdPosition += [sl, sl / 2, 0]
        s7.simdPosition += [-(sl / 2 - c), sl - c, 0]
        s8.simdPosition += [sl / 2 - c, sl - c, 0]
        
        positioningNode.eulerAngles.x = .pi / 2 // Horizontal
        positioningNode.simdScale = [1.0, 1.0, 1.0] * (FocusSquare.size * FocusSquare.scaleForClosedSquare)
        for segment in segments {
            positioningNode.addChildNode(segment)
        }
        positioningNode.addChildNode(fillPlane)
        
        // Always render focus square on top of other content.
        displayNodeHierarchyOnTop(true)
        
        addChildNode(positioningNode)
        
        // Start the focus square as a billboard.
        displayAsBillboard()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }
    
    //----------------------
    // MARK: - Visualization
    //----------------------
    
    /// Hides the focus square.
    func hide() {
        guard action(forKey: "hide") == nil else { return }
        
        displayNodeHierarchyOnTop(false)
        runAction(.fadeOut(duration: 0.5), forKey: "hide")
    }
    
    /// Unhides the focus square.
    func unhide() {
        guard action(forKey: "unhide") == nil else { return }
        
        displayNodeHierarchyOnTop(true)
        runAction(.fadeIn(duration: 0.5), forKey: "unhide")
    }
    
    /// Displays the focus square parallel to the camera plane.
    private func displayAsBillboard() {
        simdTransform = matrix_identity_float4x4
        eulerAngles.x = .pi / 2
        simdPosition = simd_float3(0, 0, -0.8)
        unhide()
        performOpenAnimation()
    }

    /// Called when a surface has been detected.
    private func displayAsOpen(for hitTestResult: ARHitTestResult, camera: ARCamera?) {
      
        let position = hitTestResult.worldTransform.translation
        recentFocusSquarePositions.append(position)
        updateTransform(for: position, hitTestResult: hitTestResult, camera: camera)
    }
    
    /// Called when a plane has been detected.
    private func displayAsClosed(for hitTestResult: ARHitTestResult, planeAnchor: ARPlaneAnchor, camera: ARCamera?) {
        
        anchorsOfVisitedPlanes.insert(planeAnchor)
        let position = hitTestResult.worldTransform.translation
        recentFocusSquarePositions.append(position)
        updateTransform(for: position, hitTestResult: hitTestResult, camera: camera)
        
    }
    
    //-----------------------
    // MARK: - Helper Methods
    //-----------------------

    /// Update the transform of the focus square to be aligned with the camera.
    private func updateTransform(for position: simd_float3, hitTestResult: ARHitTestResult, camera: ARCamera?) {
        // Average using several most recent positions.
        recentFocusSquarePositions = Array(recentFocusSquarePositions.suffix(10))
        
        // Move to average of recent positions to avoid jitter.
        let average = recentFocusSquarePositions.reduce(simd_float3(repeating: 0), { $0 + $1 }) / Float(recentFocusSquarePositions.count)
        self.simdPosition = average
        self.simdScale = simd_float3(repeating: scaleBasedOnDistance(camera: camera))
        
        // Correct y rotation of camera square.
        guard let camera = camera else { return }
        let tilt = abs(camera.eulerAngles.x)
        let threshold1: Float = .pi / 2 * 0.65
        let threshold2: Float = .pi / 2 * 0.75
        let yaw = atan2f(camera.transform.columns.0.x, camera.transform.columns.1.x)
        var angle: Float = 0
        
        switch tilt {
        case 0..<threshold1:
            angle = camera.eulerAngles.y
            
        case threshold1..<threshold2:
            let relativeInRange = abs((tilt - threshold1) / (threshold2 - threshold1))
            let normalizedY = normalize(camera.eulerAngles.y, forMinimalRotationTo: yaw)
            angle = normalizedY * (1 - relativeInRange) + yaw * relativeInRange
            
        default:
            angle = yaw
        }
        
        if state != .initializing {
            updateAlignment(for: hitTestResult, yRotationAngle: angle)
        }
    }
    
    private func updateAlignment(for hitTestResult: ARHitTestResult, yRotationAngle angle: Float) {
        // Abort if an animation is currently in progress.
        if isChangingAlignment {
            return
        }
        
        var shouldAnimateAlignmentChange = false
        
        let tempNode = SCNNode()
        tempNode.simdRotation = simd_float4(0, 1, 0, angle)
        
        // Determine current alignment
        var alignment: ARPlaneAnchor.Alignment?
        if let planeAnchor = hitTestResult.anchor as? ARPlaneAnchor {
            alignment = planeAnchor.alignment
        } else if hitTestResult.type == .estimatedHorizontalPlane {
            alignment = .horizontal
        } else if hitTestResult.type == .estimatedVerticalPlane {
            alignment = .vertical
        }
        
        // add to list of recent alignments
        if alignment != nil {
            recentFocusSquareAlignments.append(alignment!)
        }
        
        // Average using several most recent alignments.
        recentFocusSquareAlignments = Array(recentFocusSquareAlignments.suffix(20))
        
        let horizontalHistory = recentFocusSquareAlignments.filter({ $0 == .horizontal }).count
        let verticalHistory = recentFocusSquareAlignments.filter({ $0 == .vertical }).count
        
        // Alignment is same as most of the history - change it
        if alignment == .horizontal && horizontalHistory > 15 ||
            alignment == .vertical && verticalHistory > 10 ||
            hitTestResult.anchor is ARPlaneAnchor {
            if alignment != currentAlignment {
                shouldAnimateAlignmentChange = true
                currentAlignment = alignment
                recentFocusSquareAlignments.removeAll()
            }
        } else {
            // Alignment is different than most of the history - ignore it
            alignment = currentAlignment
            return
        }
        
        if alignment == .vertical {
            tempNode.simdOrientation = hitTestResult.worldTransform.orientation
            shouldAnimateAlignmentChange = true
        }
        
        // Change the focus square's alignment
        if shouldAnimateAlignmentChange {
            performAlignmentAnimation(to: tempNode.simdOrientation)
        } else {
            simdOrientation = tempNode.simdOrientation
        }
    }
    
    private func normalize(_ angle: Float, forMinimalRotationTo ref: Float) -> Float {
        // Normalize angle in steps of 90 degrees such that the rotation to the other angle is minimal
        var normalized = angle
        while abs(normalized - ref) > .pi / 4 {
            if angle > ref {
                normalized -= .pi / 2
            } else {
                normalized += .pi / 2
            }
        }
        return normalized
    }

    /**
     Reduce visual size change with distance by scaling up when close and down when far away.
     
     These adjustments result in a scale of 1.0x for a distance of 0.7 m or less
     (estimated distance when looking at a table), and a scale of 1.2x
     for a distance 1.5 m distance (estimated distance when looking at the floor).
     */
    private func scaleBasedOnDistance(camera: ARCamera?) -> Float {
        guard let camera = camera else { return 1.0 }

        let distanceFromCamera = simd_length(simdWorldPosition - camera.transform.translation)
        if distanceFromCamera < 0.7 {
            return distanceFromCamera / 0.7
        } else {
            return 0.25 * distanceFromCamera + 0.825
        }
    }
    
   // MARK: Animations
   
   private func performOpenAnimation() {
       guard !isOpen, !isAnimating else { return }
       isOpen = true
       isAnimating = true

       // Open animation
       SCNTransaction.begin()
       SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
       SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
       positioningNode.opacity = 1.0
       for segment in segments {
           segment.open()
       }
       SCNTransaction.completionBlock = {
           self.positioningNode.runAction(pulseAction(), forKey: "pulse")
           // This is a safe operation because `SCNTransaction`'s completion block is called back on the main thread.
           self.isAnimating = false
       }
       SCNTransaction.commit()
       
       // Add a scale/bounce animation.
       SCNTransaction.begin()
       SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
       SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
       positioningNode.simdScale = [1.0, 1.0, 1.0] * FocusSquare.size
       SCNTransaction.commit()
   }

   private func performCloseAnimation(flash: Bool = false) {
       guard isOpen, !isAnimating else { return }
       isOpen = false
       isAnimating = true
       
       positioningNode.removeAction(forKey: "pulse")
       positioningNode.opacity = 1.0
       
       // Close animation
       SCNTransaction.begin()
       SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
       SCNTransaction.animationDuration = FocusSquare.animationDuration / 2
       positioningNode.opacity = 0.99
       SCNTransaction.completionBlock = {
           SCNTransaction.begin()
           SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
           SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
           for segment in self.segments {
               segment.close()
           }
           SCNTransaction.completionBlock = { self.isAnimating = false }
           SCNTransaction.commit()
       }
       SCNTransaction.commit()
       
       // Scale/bounce animation
       positioningNode.addAnimation(scaleAnimation(for: "transform.scale.x"), forKey: "transform.scale.x")
       positioningNode.addAnimation(scaleAnimation(for: "transform.scale.y"), forKey: "transform.scale.y")
       positioningNode.addAnimation(scaleAnimation(for: "transform.scale.z"), forKey: "transform.scale.z")
       
       if flash {
           let waitAction = SCNAction.wait(duration: FocusSquare.animationDuration * 0.75)
           let fadeInAction = SCNAction.fadeOpacity(to: 0.25, duration: FocusSquare.animationDuration * 0.125)
           let fadeOutAction = SCNAction.fadeOpacity(to: 0.0, duration: FocusSquare.animationDuration * 0.125)
           fillPlane.runAction(SCNAction.sequence([waitAction, fadeInAction, fadeOutAction]))
           
           let flashSquareAction = flashAnimation(duration: FocusSquare.animationDuration * 0.25)
           for segment in segments {
               segment.runAction(.sequence([waitAction, flashSquareAction]))
           }
        }
   }
   
   // MARK: Convenience Methods
   
   private func scaleAnimation(for keyPath: String) -> CAKeyframeAnimation {
       let scaleAnimation = CAKeyframeAnimation(keyPath: keyPath)
       
       let easeOut = CAMediaTimingFunction(name: .easeOut)
       let easeInOut = CAMediaTimingFunction(name: .easeInEaseOut)
       let linear = CAMediaTimingFunction(name: .linear)
       
       let size = FocusSquare.size
       let ts = FocusSquare.size * FocusSquare.scaleForClosedSquare
       let values = [size, size * 1.15, size * 1.15, ts * 0.97, ts]
       let keyTimes: [NSNumber] = [0.00, 0.25, 0.50, 0.75, 1.00]
       let timingFunctions = [easeOut, linear, easeOut, easeInOut]
       
       scaleAnimation.values = values
       scaleAnimation.keyTimes = keyTimes
       scaleAnimation.timingFunctions = timingFunctions
       scaleAnimation.duration = FocusSquare.animationDuration
       
       return scaleAnimation
   }
    
    private func performAlignmentAnimation(to newOrientation: simd_quatf) {
        isChangingAlignment = true
        SCNTransaction.begin()
        SCNTransaction.completionBlock = {
            self.isChangingAlignment = false
        }
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        simdOrientation = newOrientation
        SCNTransaction.commit()
    }
    

    /// Sets the rendering order of the `positioningNode` to show on top or under other scene content.
    func displayNodeHierarchyOnTop(_ isOnTop: Bool) {
        // Recursivley traverses the node's children to update the rendering order depending on the `isOnTop` parameter.
        func updateRenderOrder(for node: SCNNode) {
            node.renderingOrder = isOnTop ? 2 : 0
            
            for material in node.geometry?.materials ?? [] {
                material.readsFromDepthBuffer = !isOnTop
            }
            
            for child in node.childNodes {
                updateRenderOrder(for: child)
            }
        }
        
        updateRenderOrder(for: positioningNode)
    }
    
    private lazy var fillPlane: SCNNode = {
        let correctionFactor = FocusSquare.thickness / 2 // correction to align lines perfectly
        let length = CGFloat(1.0 - FocusSquare.thickness * 2 + correctionFactor)
        
        let plane = SCNPlane(width: length, height: length)
        let node = SCNNode(geometry: plane)
        node.name = "fillPlane"
        node.opacity = 0.0

        let material = plane.firstMaterial!
        material.diffuse.contents = FocusSquare.fillColor
        material.isDoubleSided = true
        material.ambient.contents = UIColor.black
        material.lightingModel = .constant
        material.emission.contents = FocusSquare.fillColor

        return node
    }()
}

// MARK: - Animations and Actions

private func pulseAction() -> SCNAction {
    let pulseOutAction = SCNAction.fadeOpacity(to: 0.4, duration: 0.5)
    let pulseInAction = SCNAction.fadeOpacity(to: 1.0, duration: 0.5)
    pulseOutAction.timingMode = .easeInEaseOut
    pulseInAction.timingMode = .easeInEaseOut
    
    return SCNAction.repeatForever(SCNAction.sequence([pulseOutAction, pulseInAction]))
}

private func flashAnimation(duration: TimeInterval) -> SCNAction {
    let action = SCNAction.customAction(duration: duration) { (node, elapsedTime) -> Void in
        // animate color from HSB 48/100/100 to 48/30/100 and back
        let elapsedTimePercentage = elapsedTime / CGFloat(duration)
        let saturation = 2.8 * (elapsedTimePercentage - 0.5) * (elapsedTimePercentage - 0.5) + 0.3
        if let material = node.geometry?.firstMaterial {
            material.diffuse.contents = UIColor(hue: 0.1333, saturation: saturation, brightness: 1.0, alpha: 1.0)
        }
    }
    return action
}
