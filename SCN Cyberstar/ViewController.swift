//
//  ViewController.swift
//  SCN Cyberstar
//
//  Created by David Dreval on 20.11.2019.
//  Copyright © 2019 Snaappy. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import GLTFSCN

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNViewRecordable!
    @IBOutlet weak var toast: UIVisualEffectView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var controlsView: UIVisualEffectView!
    @IBOutlet weak var pixelBufferImageView: UIImageView!

    var focusSquare = FocusSquare()
    var node: Node?
    var pixelProducer: PixelBufferProducer?
    
    //MARK: Queue for working with content
    let nodesQueue = DispatchQueue(label: "com.dreval.scncyberstar.nodesQueue")
    var session: ARSession {
        return sceneView.session
    }
    var screenCenter: CGPoint {
        return CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.scene = SCNScene()
        toast.layer.masksToBounds = true
        toast.layer.cornerRadius = 8.0
        controlsView.layer.masksToBounds = true
        controlsView.layer.cornerRadius = 8.0
        sceneView.scene.rootNode.addChildNode(focusSquare)
        if let layer = self.sceneView.layer as? CAMetalLayer {
            layer.framebufferOnly = false
            try? pixelProducer = PixelBufferProducer(sceneView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    private func startSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }
    
    private func updateFocusSquare(isObjectVisible: Bool) {
        if isObjectVisible {
            focusSquare.hide()
        } else {
            focusSquare.unhide()
            
            // Perform ray casting only when ARKit tracking is in a good state.
            if let camera = session.currentFrame?.camera, let result = self.sceneView.smartHitTest(screenCenter) {
                nodesQueue.async {
                    self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                    self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
                }
            } else {
                nodesQueue.async {
                    self.focusSquare.state = .initializing
                    self.sceneView.pointOfView?.addChildNode(self.focusSquare)
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
            let node = Node(url: url)
            node.add(to: self.sceneView, at: self.focusSquare.simdPosition)
            self.node = node
        }
    }
}

//MARK: IBActions
extension ViewController {
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
            self.node?.setAnimationSpeed(speed)
        }
    }
    
    @IBAction func reset() {
        node?.removeFromParentNode()
        node = nil
        controlsView.isHidden = true
        stackView.isHidden = false
    }
    
    @IBAction func playback(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        if sender.isSelected {
            //pause animation here
            nodesQueue.async {
                self.node?.pause()
            }
        } else {
            //play animation here
            nodesQueue.async {
                self.node?.play()
            }
        }
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            if let camera = self.session.currentFrame?.camera, case .normal = camera.trackingState {
                self.updateFocusSquare(isObjectVisible: self.node != nil)
                self.updateStackView(enabled: !self.focusSquare.isOpen)
            }
        }
        
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

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
    }
}

extension ViewController: ARSessionObserver {
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
        default:
            message = "Camera changed tracking state"
        }
        
        message != nil ? showToast(message!) : hideToast()
    }
}

extension ViewController {
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
