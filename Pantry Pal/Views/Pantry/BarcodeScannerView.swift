//
//  BarcodeScannerView.swift
//  Pantry Pal
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ScannerViewControllerDelegate {
        let parent: BarcodeScannerView
        
        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }
        
        func didScanBarcode(_ code: String) {
            parent.scannedCode = code
            parent.isPresented = false
        }
        
        func didFailWithError(_ error: Error) {
            print("Barcode scanning failed: \(error)")
            parent.isPresented = false
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didScanBarcode(_ code: String)
    func didFailWithError(_ error: Error)
}

class ScannerViewController: UIViewController {
    weak var delegate: ScannerViewControllerDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScanner()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    private func setupScanner() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError(ScannerError.deviceNotFound)
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError(error)
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFailWithError(ScannerError.inputNotAdded)
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .upce, .code128, .code39, .code93, .aztec, .dataMatrix, .qr]
        } else {
            delegate?.didFailWithError(ScannerError.outputNotAdded)
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didScanBarcode(stringValue)
        }
    }
}

enum ScannerError: Error {
    case deviceNotFound
    case inputNotAdded
    case outputNotAdded
}
