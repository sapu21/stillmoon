import AVFoundation
import Observation

/// Runs the back camera with the flash on and reduces every frame to its average color.
/// Frames are never stored; only `PulseFrame` averages leave the capture queue.
nonisolated final class PulseCaptureEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.stillmoon.pulse")
    private var device: AVCaptureDevice?
    private let onFrame: @Sendable (PulseFrame, Double) -> Void

    init(onFrame: @escaping @Sendable (PulseFrame, Double) -> Void) {
        self.onFrame = onFrame
    }

    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)?.hasTorch == true
    }

    func start() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { throw PulseCameraError.unavailable }
        self.device = device
        session.beginConfiguration()
        session.sessionPreset = .low
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw PulseCameraError.unavailable }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw PulseCameraError.unavailable }
        session.addOutput(output)
        session.commitConfiguration()

        try device.lockForConfiguration()
        let frameDuration = CMTime(value: 1, timescale: 30)
        if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }) {
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
        }
        device.unlockForConfiguration()

        queue.async { [session] in session.startRunning() }
        queue.async { [weak self] in self?.setTorch(on: true) }
    }

    /// Captures self strongly: the queued work must run even after the owner lets go of the engine.
    func stop() {
        queue.async { self.setTorch(on: false); self.session.stopRunning() }
    }

    deinit {
        // Backstop: never leave the flash on.
        if let device, (try? device.lockForConfiguration()) != nil {
            device.torchMode = .off
            device.unlockForConfiguration()
        }
    }

    private func setTorch(on: Bool) {
        guard let device, (try? device.lockForConfiguration()) != nil else { return }
        if on { try? device.setTorchModeOn(level: 0.6) } else { device.torchMode = .off }
        device.unlockForConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        // Center half of the frame, every 4th pixel: plenty for an average.
        for y in stride(from: height / 4, to: height * 3 / 4, by: 4) {
            for x in stride(from: width / 4, to: width * 3 / 4, by: 4) {
                let p = pixels + y * rowBytes + x * 4 // BGRA
                b += Double(p[0]); g += Double(p[1]); r += Double(p[2]); n += 1
            }
        }
        guard n > 0 else { return }
        onFrame(PulseFrame(r: r / n, g: g / n, b: b / n), time)
    }
}

enum PulseCameraError: Error { case unavailable, denied }

/// A 45 s fingertip reading for the calm check.
@Observable final class PulseCamera {
    enum State: Equatable {
        case idle
        /// Waiting for a fingertip, or letting exposure settle once it is there.
        case preparing(covering: Bool)
        case measuring(progress: Double, covering: Bool)
        case finished(PulseResult)
        case failed(String)
    }

    static let seconds = 45.0
    static var isAvailable: Bool { PulseCaptureEngine.isAvailable }

    private(set) var state: State = .idle
    @ObservationIgnored private var engine: PulseCaptureEngine?
    @ObservationIgnored private var recording = PulseRecording(seconds: seconds)
    @ObservationIgnored private var starting = false

    func start() async {
        guard !starting else { return }
        starting = true
        defer { starting = false }
        stop()
        recording = PulseRecording(seconds: Self.seconds)
        guard await Self.cameraAllowed() else {
            state = .failed("Camera access is off. You can turn it on in the Settings app, under Privacy & Security, Camera.")
            return
        }
        let engine = PulseCaptureEngine { [weak self] frame, time in
            Task { @MainActor in self?.receive(frame, at: time) }
        }
        do {
            try engine.start()
            self.engine = engine
            state = .preparing(covering: false)
        } catch {
            state = .failed("The camera couldn't start. Please try again.")
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        switch state {
        case .preparing, .measuring: state = .idle
        default: break
        }
    }

    private func receive(_ frame: PulseFrame, at time: Double) {
        guard engine != nil else { return }
        let covering = PulseAnalyzer.isCovering(frame)
        switch recording.add(frame, at: time) {
        case .waitingForFinger, .settling, .interrupted:
            state = .preparing(covering: covering)
        case .measuring(let progress):
            state = .measuring(progress: progress, covering: covering)
        case .done(let result):
            engine?.stop()
            engine = nil
            state = .finished(result)
        }
    }

    private static func cameraAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }
}
