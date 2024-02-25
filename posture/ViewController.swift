//
//  ViewController.swift
//  posture
//
//  Created by Ojasvi Sethi on 13/02/24.
//

import UIKit
import Vision
import AVKit
import simd


struct Pose {
    var name: String
    var point: CGPoint
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let a = CGRect(x: 0, y: 0, width: 100, height: 100)
    
    
    var arrow = UIImageView()
    var bgView = UIView()
    var resultTextView = UITextView()
    var resultTextView2 = UITextView()
    var referenceYaw: Float?
    var currentYaw: Float?
    var referenceButton = UIButton(type: .system)
    

    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        let captureSession = AVCaptureSession()
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {return}
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {return}
      
        captureSession.addInput(input)
        
        DispatchQueue.global().async {
            captureSession.startRunning()
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        
        previewLayer.frame = view.frame
        

        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)

        if let videoDevice = AVCaptureDevice.default(for: .video) {
            do {
                try videoDevice.lockForConfiguration()
                // Set the frame rate to capture one frame every 10 seconds
                videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 2)
                videoDevice.unlockForConfiguration()
            } catch {
                print("Error setting frame rate: \(error.localizedDescription)")
            }
        }

        
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height
        
        bgView = UIView(frame: CGRect(x: 10, y: 10, width: screenW, height: screenH-10))
        bgView.backgroundColor = .red.withAlphaComponent(0.05)
        view.addSubview(bgView)
        
        arrow = UIImageView(image: UIImage(systemName: "arrowshape.right.fill"))
        arrow.tintColor = .green
      
        
        arrow.frame = CGRect(x: screenH/4, y: screenW/2, width: 50, height: 50)
        bgView.addSubview(arrow)
        resultTextView = UITextView(frame: CGRect(x: 10, y: screenH - 150, width: screenW - 20, height: 140))
        resultTextView.backgroundColor = .clear
        resultTextView.textColor = .white
        resultTextView.font = UIFont.systemFont(ofSize: 16)
        resultTextView.isEditable = false
        bgView.addSubview(resultTextView)
        referenceButton.setTitle("Set Reference", for: .normal)
        referenceButton.backgroundColor = .blue  // Set the background color as needed
        referenceButton.setTitleColor(.white, for: .normal)
        referenceButton.layer.cornerRadius = 8  // Optional: Add
        referenceButton.addTarget(self, action: #selector(setReferenceLevel), for: .touchUpInside)
        bgView.addSubview(referenceButton)
        referenceButton.frame = CGRect(x: 10, y: screenH - 200, width: 120, height: 40)

        
        
        animateRightArrow()
    }
    


    @objc func setReferenceLevel() {
        self.referenceYaw = self.currentYaw
                print("Reference Yaw Set: \(self.referenceYaw ?? 0.0)")
            }

    
    func animateRightArrow()    {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.4) {
                self.arrow.transform = CGAffineTransform(translationX: 100, y: 0)
            } completion: { _ in
                UIView.animate(withDuration: 0.4)   {
                    self.arrow.transform = .identity
                } completion: { _ in
                    self.animateRightArrow()
                }
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)


        // Create a request to detect a body pose in 3D space.
        let request = VNDetectHumanBodyPose3DRequest()


        do {
            // Perform the body pose request.
            try requestHandler.perform([request])


            // Get the observation.
            if let observation = request.results?.first {
                let leftShoulder = try observation.recognizedPoint(.leftShoulder)
                let rightShoulder = try observation.recognizedPoint(.rightShoulder)
                let spine = try observation.recognizedPoint(.spine)
                let centerShoulder = try observation.recognizedPoint(.centerShoulder)
                let topHead = try observation.recognizedPoint(.topHead)
                let centerHead = try observation.recognizedPoint(.centerHead)
                print(leftShoulder)
                print(topHead)
                print(centerHead)
                print(centerShoulder)
                print(rightShoulder)
                print(spine)


                var angleVector: simd_float3 = simd_float3()


                // Get the position relative to the parent shoulder joint.
                let childPosition = centerShoulder.localPosition
                let translationChild = simd_make_float3(childPosition.columns.3[0],
                                                        childPosition.columns.3[1],
                                                        childPosition.columns.3[2])


                // The rotation around the x-axis.
                let pitch = (Float.pi / 2)


                // The rotation around the y-axis.
                let yaw = acos(translationChild.z / simd_length(translationChild))


                // The rotation around the z-axis.
                let roll = atan2((translationChild.y), (translationChild.x))


                // The angle between the elbow and shoulder joint.
                angleVector = simd_float3(pitch, yaw, roll)
                print(yaw,referenceYaw)
                self.currentYaw = yaw
                var yawDifference : Float?
                if let referenceYaw = self.referenceYaw {
                    if let currentYaw = currentYaw{
                        yawDifference = currentYaw - referenceYaw
                    }

                    if yawDifference != nil {
                        if yawDifference! > 0.2 {
                            DispatchQueue.main.async {
                                self.resultTextView.text = "leaning forward"
                                print("leaningb forward",yawDifference!,self.currentYaw!,referenceYaw)
                            }
                        }
                    }
                }
            }
        } catch {
            print("Unable to perform the request: \(error).")
        }
        
    }

}

