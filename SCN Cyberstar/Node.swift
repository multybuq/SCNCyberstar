//
//  Node.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 20.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import GLTFSCN

class Node: SCNNode {
    
    private let url: URL
    private var animation: [GLTFSCNAnimationTargetPair]?
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func add(to sceneView: SCNView, at position: simd_float3) {
        simdPosition = position
        let buffer = GLTFDefaultBufferAllocator()
        let asset = GLTFAsset(url: url, bufferAllocator: buffer)
        let gltfAsset = SCNScene.asset(from: asset, options: [:])
        if let node = gltfAsset.defaultScene?.rootNode {
            let b = node.boundingBox
            let side = max(b.max.x - b.min.x, b.max.y - b.min.y, b.max.z - b.min.z)
            var scale = 0.75/side
            if let distance = sceneView.pointOfView?.simdPosition.distance(to: position) {
                scale = distance * scale
            }
            node.simdScale = simd_float3.zero
            self.addChildNode(node)
            sceneView.prepare([self]) { (success) in
                sceneView.scene?.rootNode.addChildNode(self)
                node.runAction(SCNAction.scale(to: CGFloat(scale), duration: 0.15))
                if let first = gltfAsset.animations.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }).last {
                    self.animation = first.value
                    first.value.forEach { (pair) in
                       // pair.animation.beginTime = 0.0
                        pair.target.addAnimation(pair.animation, forKey: nil)
                    }
                }
            }
        }
    }
    
    func play() {
        if let animation = animation {
            animation.forEach { (pair) in
                pair.target.animationKeys.forEach { (key) in
                    pair.target.animationPlayer(forKey: key)?.paused = false
                }
            }
        }
    }
    
    func pause() {
        if let animation = animation {
            animation.forEach { (pair) in
                pair.target.animationKeys.forEach { (key) in
                    pair.target.animationPlayer(forKey: key)?.paused = true
                }
            }
        }
    }
    
    func setAnimationSpeed(_ speed: Float) {
        if let animation = animation {
            animation.forEach { (pair) in
                pair.target.animationKeys.forEach { (key) in
                    pair.target.animationPlayer(forKey: key)?.speed = CGFloat(speed)
                }
            }
        }
    }
}
