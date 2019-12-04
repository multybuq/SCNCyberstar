//
//  MetalViewController.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 26.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import UIKit
import Metal
import MetalKit
import ARKit
//import GLTFMTL

extension MTKView : RenderDestinationProvider {
}

class MetalViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {
    
    @IBOutlet weak var toast: UIVisualEffectView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var controlsView: UIVisualEffectView!
    @IBOutlet weak var pixelBufferImageView: UIImageView!
    
    var session: ARSession!
    var renderer: Renderer!
    var asset: GLTFAsset?
    let nodesQueue = DispatchQueue(label: "com.dreval.scncyberstar.nodesQueue")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        session = ARSession()
        session.delegate = self
        
        // Set the view to use the default device
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self
            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }
            
            // Configure the renderer to draw to the view
            renderer = Renderer(session: session, metalDevice: view.device!, renderDestination: view)
            renderer.drawRectResized(size: view.bounds.size)
        }
        
        toast.layer.masksToBounds = true
        toast.layer.cornerRadius = 8.0
        controlsView.layer.masksToBounds = true
        controlsView.layer.cornerRadius = 8.0
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(MetalViewController.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        session.pause()
    }
    
    private func startSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }
    
    @objc
    func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Create anchor using the camera's current position
        if let currentFrame = session.currentFrame {
            
            // Create a transform with a translation of 0.2 meters in front of the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -0.6
            let transform = simd_mul(currentFrame.camera.transform, translation)
            
            // Add a new anchor to the session
            let anchor = ARAnchor(transform: transform)
            session.add(anchor: anchor)
        }
    }
    
    // MARK: - MTKViewDelegate
    
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.update()
    }
    
    private func updateStackView(enabled: Bool) {
        if stackView.isUserInteractionEnabled != enabled {
            stackView.isUserInteractionEnabled = enabled
            UIView.animate(withDuration: 0.2) {
                self.stackView.alpha = enabled ? 1.0 : 0.5
            }
        }
    }
    
    private func loadModel(url: URL) {
        controlsView.isHidden = false
        stackView.isHidden = true
        nodesQueue.async {
            self.asset = GLTFAsset(url: url, bufferAllocator: self.renderer.gltfBufferAllocator)
            
            let node = GLTFNode()
            node.translation = simd_float3(0, 0, 1)
            node.rotationQuaternion = simd_quaternion(1.0, 0, 0, 0)
            let dirLight = GLTFKHRLight()
            node.light = dirLight
            self.asset?.defaultScene?.addNode(node)
            self.asset?.addLight(dirLight)
            
            let light = GLTFKHRLight()
            light.type = .ambient
            light.intensity = 0.2
            self.asset?.addLight(light)
            self.asset?.defaultScene?.ambientLight = light
            self.renderer.gltfAsset = self.asset
        }
    }
}

//MARK: IBActions
extension MetalViewController {
    @IBAction func loadRobot() {
        if let modelUrl = Bundle.main.url(forResource: "art.scnassets/Tesla", withExtension: "glb") {
            loadModel(url: modelUrl)
        }
    }
    
    @IBAction func loadPig() {
        if let modelUrl = Bundle.main.url(forResource: "art.scnassets/Piggy", withExtension: "glb") {
            loadModel(url: modelUrl)
        }
    }
    
    @IBAction func loadHand() {
        if let modelUrl = Bundle.main.url(forResource: "art.scnassets/Mone", withExtension: "glb") {
            loadModel(url: modelUrl)
        }
    }
    
    @IBAction func sliderValueChanged(sender: UISlider) {
        let speed = sender.value
        nodesQueue.async {

        }
    }
    
    @IBAction func reset() {

        controlsView.isHidden = true
        stackView.isHidden = false
    }
    
    @IBAction func playback(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        if sender.isSelected {
            //pause animation here
            nodesQueue.async {

            }
        } else {
            //play animation here
            nodesQueue.async {

            }
        }
    }
}

extension MetalViewController: ARSessionObserver {
    func sessionWasInterrupted(_ session: ARSession) {
        showToast("Session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        startSession()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        showToast("Session failed: \(error.localizedDescription)")
        startSession()
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        var message: String? = nil
        
        switch camera.trackingState {
        case .notAvailable:
            message = "Tracking not available"
        case .limited(.initializing):
            message = "Initializing AR session"
        case .limited(.excessiveMotion):
            message = "Too much motion"
        case .limited(.insufficientFeatures):
            message = "Not enough surface details"
        case .normal:
            message = "Move to find a horizontal surface"
            stackView.isHidden = false
            updateStackView(enabled: true)
        default:
            message = "Camera changed tracking state"
        }
        
        message != nil ? showToast(message!) : hideToast()
    }
}

extension MetalViewController {
    func showToast(_ text: String) {
        label.text = text
        guard toast.alpha == 0 else {
            return
        }
        UIView.animate(withDuration: 0.25, animations: {
            self.toast.alpha = 1
        })
    }
    
    func hideToast() {
        UIView.animate(withDuration: 0.25, animations: {
            self.toast.alpha = 0
        })
    }
}
