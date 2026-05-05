// FichaView.swift — Success overlay + auto-close al compartir
import SwiftUI
import AVFoundation
import Combine
import SwiftData
import CoreLocation

private final class SpeechManager: NSObject, ObservableObject {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()
    override init() { super.init(); synth.delegate = self }
    func toggle(text: String) {
        if isSpeaking { synth.stopSpeaking(at: .immediate); isSpeaking = false }
        else {
            let utt = AVSpeechUtterance(string: text)
            utt.voice = AVSpeechSynthesisVoice(language: "es-MX"); utt.rate = 0.44
            synth.speak(utt); isSpeaking = true
        }
    }
    func stop() { synth.stopSpeaking(at: .immediate); isSpeaking = false }
}
extension SpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

struct FichaView: View {
    let material  : NEXOMaterial
    let ocrText   : String?
    var imageData : Data? = nil
    @Binding var isPresented: Bool

    @Environment(\.modelContext)    private var context
    @EnvironmentObject private var repo     : ListingsRepository
    @EnvironmentObject private var location : LocationManager
    @EnvironmentObject private var auth     : AuthService

    @ObservedObject private var fmService = FoundationModelsService.shared
    @StateObject    private var speech    = SpeechManager()

    @State private var heroIn        = false
    @State private var contentIn     = false
    @State private var compartida    = false
    @State private var isPublishing  = false
    @State private var publishError  : String? = nil
    @State private var instruccionFM : String? = nil

    // Success overlay
    @State private var showSuccess   = false
    @State private var checkScale    : CGFloat = 0.3
    @State private var checkOpacity  : Double  = 0

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        routeBadgeRow
                        instructionsCard
                        if let tip = material.smellTip { smellCard(tip) }
                        if let ocr = ocrText           { ocrCard(ocr)   }
                        metricsRow
                        valueCard
                    }
                    .padding(.bottom, 24)
                }
                .opacity(contentIn ? 1 : 0)
                actionBar
            }

            // MARK: Success overlay — aparece al compartir
            if showSuccess {
                successOverlay
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.05))  { heroIn    = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.3))  { contentIn = true }
            location.startUpdating()
            Task { instruccionFM = await fmService.generarInstruccion(material: material, textoOCR: ocrText) }
        }
        .onDisappear { speech.stop() }
        .alert("No se pudo publicar", isPresented: .constant(publishError != nil)) {
            Button("OK") { publishError = nil }
        } message: { Text(publishError ?? "") }
    }

    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            // Fondo verde con blur
            Color.nexoForest
                .ignoresSafeArea()
                .opacity(0.97)

            VStack(spacing: 24) {
                // Checkmark animado
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 110, height: 110)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        .frame(width: 110, height: 110)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(checkScale)
                .opacity(checkOpacity)

                VStack(spacing: 8) {
                    Text("Ficha compartida")
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-1)
                        .foregroundStyle(.white)

                    Text("Los recolectores cercanos\nya pueden verla.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(checkOpacity)
            }
        }
        .transition(.opacity)
        .onAppear {
            // Anima el checkmark
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                checkScale   = 1.0
                checkOpacity = 1.0
            }
            // Haptic de éxito
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Auto-dismiss después de 1.8 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeIn(duration: 0.25)) {
                    isPresented = false
                }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        ZStack(alignment: .bottom) {
            material.accent.ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.black.opacity(0.0)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { speech.stop(); isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: Circle())
                    }.accessibilityLabel("Cerrar")
                    Spacer()
                    if fmService.isGenerating {
                        HStack(spacing: 6) {
                            ProgressView().tint(.white).scaleEffect(0.7)
                            Text("Generando").font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, Sp.lg).padding(.top, 56).padding(.bottom, 16)

                HStack(spacing: 14) {
                    Image(systemName: material.icon)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(material.classKey.uppercased())
                            .font(.system(size: 9, weight: .semibold)).tracking(2)
                            .foregroundStyle(.white.opacity(0.65))
                        Text(material.displayName)
                            .font(.system(size: 26, weight: .bold)).tracking(-0.8)
                            .foregroundStyle(.white)
                            .scaleEffect(heroIn ? 1 : 0.95, anchor: .leading)
                            .opacity(heroIn ? 1 : 0)
                    }
                }
                .padding(.horizontal, Sp.lg).padding(.bottom, 20)
            }
        }
        .frame(height: 210)
    }

    // MARK: - Sections
    private var routeBadgeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: material.route.icon).font(.system(size: 12, weight: .semibold))
            Text(material.route.rawValue).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(material.route.color)
        .padding(.horizontal, Sp.lg).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .accessibilityLabel("Ruta: \(material.route.rawValue)")
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Preparación")
                    .font(.system(size: 12, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                if instruccionFM != nil {
                    Text("IA").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.nexoBrand)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.nexoMint, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            Text(instruccionFM ?? material.instructions.joined(separator: " "))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(uiColor: .label))
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Sp.lg).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
    }

    private func smellCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "nose").font(.system(size: 14)).foregroundStyle(.orange)
            Text(tip).font(.system(size: 14)).foregroundStyle(Color(uiColor: .label))
        }
        .padding(Sp.lg).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.06))
    }

    private func ocrCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.viewfinder").font(.system(size: 13)).foregroundStyle(Color.nexoBlue)
            VStack(alignment: .leading, spacing: 3) {
                Text("Texto en etiqueta")
                    .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(text).font(.system(size: 14)).foregroundStyle(Color(uiColor: .label))
            }
        }
        .padding(Sp.lg).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nexoBlue.opacity(0.06))
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            metricCell(label: "CO₂ evitado", value: material.co2, color: Color.nexoBrand)
            if material.water != "—" {
                Divider().frame(height: 48)
                metricCell(label: "Agua ahorrada", value: material.water, color: Color.nexoBlue)
            }
        }
        .background(Color(uiColor: .systemBackground)).padding(.top, 2)
    }

    private func metricCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.3)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Text(value).font(.system(size: 22, weight: .bold)).tracking(-0.5).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Sp.lg).padding(.vertical, Sp.md)
        .accessibilityElement(children: .combine).accessibilityLabel("\(label): \(value)")
    }

    private var valueCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Valor estimado").font(.system(size: 10, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(material.value).font(.system(size: 18, weight: .bold)).tracking(-0.3)
                    .foregroundStyle(Color(hex: "7A5F00"))
            }
            Spacer()
            Rectangle().fill(Color.nexoAmber).frame(width: 4, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, Sp.lg).padding(.vertical, Sp.md)
        .background(Color(hex: "FFFCE8")).padding(.top, 2)
    }

    // MARK: - Action bar
    private var actionBar: some View {
        VStack(spacing: 8) {
            Button { publicarFicha() } label: {
                Group {
                    if isPublishing {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Compartir con recolector")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.nexoForest, in: RoundedRectangle(cornerRadius: Rd.lg))
                .shadow(color: Color.nexoForest.opacity(0.2), radius: 8, y: 3)
            }
            .disabled(compartida || isPublishing)

            Button { speech.toggle(text: voiceText) } label: {
                HStack(spacing: 7) {
                    Image(systemName: speech.isSpeaking ? "speaker.slash" : "speaker.wave.2")
                        .font(.system(size: 13))
                    Text(speech.isSpeaking ? "Detener" : "Leer en voz alta")
                        .font(.system(size: 14, weight: .regular))
                }
                .foregroundStyle(Color.nexoBrand)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Rd.lg))
                .overlay(RoundedRectangle(cornerRadius: Rd.lg)
                    .strokeBorder(Color.nexoForest.opacity(0.1), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, Sp.lg).padding(.vertical, 12).padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    private var voiceText: String {
        let base = instruccionFM ?? material.voiceText
        let tip  = material.smellTip.map { " \($0)" } ?? ""
        return "\(material.displayName). \(base)\(tip) Valor estimado: \(material.value)."
    }

    // MARK: - Publicar + mostrar success
    private func publicarFicha() {
        guard !compartida else { return }
        if !location.isAvailable { location.requestWhenInUse() }
        isPublishing = true
        let localImageData = imageData
        Task {
            let coord = location.anonymizedCoordinate
                     ?? location.coordinate
                     ?? CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)

            var uploadedImageUrl: String? = nil
            if let data = localImageData, let userId = auth.currentUserId {
                uploadedImageUrl = try? await StorageService.shared.uploadScanImage(data, userId: userId)
            }
            if let userId = auth.currentUserId {
                let record = NewScanRecord(
                    userId: userId, material: material.displayName, imageUrl: uploadedImageUrl,
                    ocrText: ocrText, lat: coord.latitude, lng: coord.longitude,
                    classKey: material.classKey, displayName: material.displayName, icon: material.icon,
                    route: material.route.rawValue, co2: material.co2, water: material.water,
                    value: material.value, smellTip: material.smellTip,
                    instructions: material.instructions, fmInstruction: instruccionFM
                )
                await repo.insertScanRecord(record)
            }
            let nuevo = NewListing(
                material: material.displayName, quantityLabel: "1 unidad",
                notes: instruccionFM ?? material.instructions.joined(separator: ". "),
                lat: coord.latitude, lng: coord.longitude, classKey: material.classKey,
                displayName: material.displayName, icon: material.icon,
                route: material.route.rawValue, co2: material.co2, water: material.water,
                value: material.value, fmInstruction: instruccionFM
            )
            let ok = await repo.publish(nuevo)
            isPublishing = false

            if ok {
                context.insert(FichaRegistro(material: material))
                compartida = true
                speech.stop()
                // Mostrar success overlay con animación
                withAnimation(.easeOut(duration: 0.2)) { showSuccess = true }
            } else {
                publishError = repo.lastError ?? "Intenta de nuevo."
            }
        }
    }
}
