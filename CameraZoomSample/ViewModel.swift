//
//  ViewModel.swift
//  CameraZoomSample
//
//  Created by paku on 2024/04/11.
//

import Combine
import SwiftUI
import AVFoundation

class ViewModel: NSObject, ObservableObject {
    
    @Published var image: UIImage?
    @Published var imageAspectRatio: CGFloat?
    
    @Published var linearZoomFactor: Float = 1.0
    @Published var standardZoomFactor: CGFloat = 1.0
    
    private let captureSession = AVCaptureSession()
    private var device: AVCaptureDevice?
    
    @Published var minFactor: CGFloat = 1.0
    @Published var maxFactor: CGFloat = 10.0

    // イメージをキャプチャするためのフラグ
    private var capturesImage = false
    var previewLayer: CALayer?
    var cancellables: [AnyCancellable] = []
    
    override init() {
        super.init()
        prepareCamera()
        configureSession()
        subscribePublisher()
    }
    
    private func prepareCamera() {
        captureSession.sessionPreset = .photo
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        
        // 最初に見つかったデバイスを選択する
        self.device = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .back).devices.first
        
        guard let device else {
            print("no available device!")
            return
        }
        
        // iPhone 15 pro maxの場合、Zoom Factor Range: 1.0 - 123.75
        // 123.75は デジタルズームまでの最大値
        print("Zoom Factor Range: \(device.minAvailableVideoZoomFactor) - \(device.maxAvailableVideoZoomFactor)")
        // [2, 10]
        // 超広角1.0からなので 2で広角カメラ、10で望遠カメラに切り替わる
        print("Zoom Factor Switch: \(device.virtualDeviceSwitchOverVideoZoomFactors)")
        
        for actualDevice in device.constituentDevices {
            // iPhone 15 pro maxの場合以下が取得される
            // 1 Back Ultra Wide Camera, AVCaptureDeviceTypeBuiltInUltraWideCamera
            // 2 Back Camera, AVCaptureDeviceTypeBuiltInWideAngleCamera
            // 3 Back Telephoto Camera, AVCaptureDeviceTypeBuiltInTelephotoCamera
            print("candidate name: \(actualDevice.localizedName), deviceType: \(actualDevice.deviceType)")
        }
        
        standardZoomFactor = 1
        
        for (index, actualDevice) in device.constituentDevices.enumerated() {
            // 超広角の次の広角のzoomFactorを取得し、standardZoomFactorとして設定(zoomFactor: 2)
            // おそらく超広角がなければ拡大していない 1が取得されるはず
            if (actualDevice.deviceType != .builtInUltraWideCamera) {
                if index > 0 && index <= device.virtualDeviceSwitchOverVideoZoomFactors.count {
                    standardZoomFactor = CGFloat(truncating: device.virtualDeviceSwitchOverVideoZoomFactors[index - 1])
                }
                break
            }
        }
        
        self.minFactor = device.minAvailableVideoZoomFactor
        // 最大倍数を15に設定
        self.maxFactor = min(device.maxAvailableVideoZoomFactor, 15.0)
    }
    
    private func configureSession() {
        guard let device else {
            return
        }
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: device)

            captureSession.addInput(captureDeviceInput)
        } catch {
            //errorText = error.localizedDescription
            return
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = previewLayer

        let dataOutput = AVCaptureVideoDataOutput()
        // ピクセルのフォーマットとして32ビットBGRAを使用
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]

        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }
        // キャプチャセッションの設定を確定
        captureSession.commitConfiguration()
        // 出力設定: デリゲート、画像をキャプチャするキュー
        let queue = DispatchQueue(label: "videoqueue")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
    }
    
    private func subscribePublisher() {
        $linearZoomFactor
            .receive(on: DispatchQueue.main)
            .sink { scale in
                self.zoom(linearFactor: scale)
            }
            .store(in: &cancellables)
    }
    
    func zoom(linearFactor: Float) {
        guard let device else {
            return
        }

        do {
            try device.lockForConfiguration()
            device.cancelVideoZoomRamp()
            device.ramp(toVideoZoomFactor: CGFloat(linearFactor), withRate: 5)
            device.unlockForConfiguration()
        }  catch {
            print("Error Zooming")
        }
    }
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            self?.captureSession.startRunning()
            
            self?.linearZoomFactor = Float(self?.standardZoomFactor ?? 1.0)
        }
    }
    
    func captureImageOnce() {
        capturesImage = true
    }
}

extension ViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if imageAspectRatio == nil {
            updateImageAspectRatio(buffer: sampleBuffer)
        }
        
        // カメラボタンをタップすると 以下の処理が実行される
        // ボタンをタップした瞬間のフレームで画像を取得して画面に表示する
        guard capturesImage else {
            return
        }
        if let image = getImageFromSampleBuffer(buffer: sampleBuffer) {
            DispatchQueue.main.async {
                self.image = image
            }
        }
        capturesImage = false
    }

    private func updateImageAspectRatio(buffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        DispatchQueue.main.async {
            self.imageAspectRatio = CGFloat(height) / CGFloat(width)
        }
    }

    private func getImageFromSampleBuffer(buffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return nil
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

        guard let image = context.createCGImage(ciImage, from: imageRect) else {
            return nil
        }
        return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .right)
    }
}

