// CameraManager.swift
// Usa VNCoreMLRequest con el modelo NexoClass1 entrenado en Create ML
// en paralelo con VNRecognizeTextRequest para lectura de etiquetas.

import AVFoundation
import SwiftUI
import Vision
import Combine

// MARK: - UIView para preview de cámara

class _CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> _CameraPreviewUIView {
        let view = _CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: _CameraPreviewUIView, context: Context) {}
}

// MARK: - CameraManager

final class CameraManager: NSObject, ObservableObject {

    @Published var detectedMaterial  : NEXOMaterial? = nil
    @Published var detectedOCRText   : String?       = nil
    @Published var capturedImageData : Data?          = nil
    @Published var isAnalyzing       : Bool           = false
    @Published var errorMessage      : String?        = nil

    let session     = AVCaptureSession()
    private let out = AVCapturePhotoOutput()

    override init() {
        super.init()
        configureSession()
    }

    // MARK: - Session setup

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            DispatchQueue.main.async { self.errorMessage = "No se pudo acceder a la cámara." }
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        if session.canAddOutput(out) { session.addOutput(out) }
        session.commitConfiguration()
    }

    func start() { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    func stop()  { DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning()  } }

    func capture() {
        guard !isAnalyzing else { return }
        DispatchQueue.main.async { self.isAnalyzing = true; self.errorMessage = nil }
        out.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    // MARK: - Análisis de imagen (Vision + Core ML)

    private func analyze(data: Data) {
        guard let ci = CIImage(data: data) else {
            DispatchQueue.main.async { self.isAnalyzing = false }
            return
        }

        let handler = VNImageRequestHandler(ciImage: ci, options: [:])

        // ── 1. Clasificación con Core ML (VNCoreMLRequest + NexoClass1) ──────
        guard let coreMLModel = try? VNCoreMLModel(for: NexoClass1().model) else {
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.errorMessage = "No se pudo cargar el modelo de clasificación."
            }
            return
        }

        let classifyRequest = VNCoreMLRequest(model: coreMLModel) { [weak self] req, _ in
            guard let self else { return }
            let results = req.results as? [VNClassificationObservation] ?? []

            // Toma la clase con mayor confianza
            let found = results.first.flatMap { obs in
                NEXOMaterial.from(visionLabel: obs.identifier)
            }

            DispatchQueue.main.async {
                self.isAnalyzing = false
                if let found {
                    self.detectedMaterial = found
                } else {
                    self.errorMessage = "No reconocí este residuo. Acércate más o mejora la iluminación."
                }
            }
        }
        classifyRequest.imageCropAndScaleOption = .centerCrop

        // ── 2. Reconocimiento de texto (VNRecognizeTextRequest) ──────────────
        let textRequest = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self else { return }
            let observations = req.results as? [VNRecognizedTextObservation] ?? []
            let strings = observations.compactMap { obs -> String? in
                guard let top = obs.topCandidates(1).first,
                      top.confidence > 0.5 else { return nil }
                return top.string
            }
            let fullText = strings.joined(separator: " ")
            let keywords: [String] = [
                "PET", "HDPE", "LDPE", "PP", "PS", "PVC",
                "Li-ion", "Li-Po", "mAh", "rechargeable", "recargable",
                "compostable", "biodegradable", "reciclable",
                "1", "2", "3", "4", "5", "6", "7"
            ]
            let detected = keywords.filter { fullText.uppercased().contains($0.uppercased()) }
            DispatchQueue.main.async {
                if !detected.isEmpty { self.detectedOCRText = detected.joined(separator: ", ") }
            }
        }
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["es-MX", "en-US"]
        textRequest.usesLanguageCorrection = true
        if #available(iOS 16.0, *) {
            textRequest.revision = VNRecognizeTextRequestRevision3
        }

        // ── Ejecutar ambos en paralelo ────────────────────────────────────────
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([classifyRequest, textRequest])
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.isAnalyzing = false }
            return
        }
        DispatchQueue.main.async { self.capturedImageData = data }
        analyze(data: data)
    }
}
