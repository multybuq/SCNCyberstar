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
    let nodesQueue = DispatchQueue(label: "com.dreval.scncyberstar.nodesQueue")
    var pixelProducer: PixelBufferProducer?

    var screenCenter: CGPoint {
        return CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }
    
    var anchor: ARAnchor?
    
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
            
            if let layer = view.layer as? CAMetalLayer {
                layer.framebufferOnly = false
                try? pixelProducer = PixelBufferProducer(view)
            }
        }
        
        toast.layer.masksToBounds = true
        toast.layer.cornerRadius = 8.0
        controlsView.layer.masksToBounds = true
        controlsView.layer.cornerRadius = 8.0
        updateStackView(enabled: false)
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
    
    // MARK: - MTKViewDelegate
    
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        hitTest(point: screenCenter)
        renderer.update()
        
        if let producer = pixelProducer {
            producer.queue.async {
                if let buffer = producer.producePixelBuffer() {
                    let image = UIImage(ciImage: CIImage(cvImageBuffer: buffer))
                    DispatchQueue.main.async {
                        self.pixelBufferImageView.image = image
                    }
                }
            }
        }
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
            let asset = GLTFAsset(url: url, bufferAllocator: self.renderer.gltfBufferAllocator)
            self.renderer.gltfAsset = asset
        }
    }
}

//MARK: IBActions
extension MetalViewController {
    @IBAction func loadRobot() {
        if let modelUrl = Bundle.main.url(forResource: "art.scnassets/1", withExtension: "glb") {
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
            self.renderer.setSpeed(speed: speed)
        }
    }
    
    @IBAction func reset() {
        controlsView.isHidden = true
        stackView.isHidden = false
        nodesQueue.async {
            self.renderer.gltfAsset = nil
        }
    }
    
    @IBAction func playback(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        if sender.isSelected {
            //pause animation here
            nodesQueue.async {
                self.renderer.pause()
            }
        } else {
            //play animation here
            nodesQueue.async {
                self.renderer.play()
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

extension MetalViewController {
    func hitTest(point: CGPoint) {
        if let frame = session.currentFrame {
            let unitPoint = CGPoint(x: point.x / view.bounds.width, y: point.y / view.bounds.height)
            let transform = frame.displayTransform(for: .portrait, viewportSize: view.bounds.size)
            let frameUnitPoint = unitPoint.applying(transform.inverted())
            let hitTestResults = frame.hitTest(frameUnitPoint, types: [.existingPlane, .estimatedHorizontalPlane])
            if let result = hitTestResults.first {
                /// Uncomment it if you want to place model to existing plane only
               // updateStackView(enabled: result.type == .existingPlane)
                
                renderer.focusSquareTransform = result.worldTransform
            }
        }
    }
}
