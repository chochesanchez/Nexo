//
//  OrganicFichaView.swift
//  nexo
//
//  Created by Guillermo Lira on 05/05/26.
//


// OrganicFichaView.swift
// Vista especial para residuos orgánicos:
//   Step 1 → sub-clasificación (qué tipo de orgánico)
//   Step 2 → estado (fresco / echado a perder) — solo para fruta/verdura
//   Step 3 → rutas recomendadas + timer de fermentación activo

import SwiftUI
import UserNotifications
import SwiftData

struct OrganicFichaView: View {
    let material   : NEXOMaterial
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var context

    // ── Flujo por pasos ───────────────────────────────────────────────────────
    @State private var step        : Int              = 1
    @State private var subType     : OrganicSubType?  = nil
    @State private var isGoodState : Bool?            = nil

    // ── Timer de fermentación ─────────────────────────────────────────────────
    @State private var ferTimer    : FermentationTimer? = nil
    @State private var tickDate    = Date()           // fuerza refresh del timer
    @State private var isFreezing  = false
    @State private var guardada    = false

    // ── Animaciones ───────────────────────────────────────────────────────────
    @State private var stepIn      = false
    @State private var showSuccess = false

    private let notifManager = FermentationNotificationManager.shared

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                organicHeader
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch step {
                        case 1: stepSubType
                        case 2: stepFreshness
                        default: stepResults
                        }
                    }
                    .padding(Sp.lg)
                    .padding(.bottom, 32)
                }
                .opacity(stepIn ? 1 : 0)
                .offset(y: stepIn ? 0 : 12)
            }
            if showSuccess { savedOverlay }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            notifManager.requestPermission()
            withAnimation(.easeOut(duration: 0.35)) { stepIn = true }
        }
        // Tick del timer cada 30 segundos
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                tickDate = Date()
            }
        }
    }

    // MARK: - Header orgánico

    private var organicHeader: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "1B5E20").ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    // Indicador de pasos
                    HStack(spacing: 6) {
                        ForEach(1...3, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? Color.white : Color.white.opacity(0.25))
                                .frame(width: i == step ? 20 : 7, height: 7)
                                .animation(.spring(response: 0.3), value: step)
                        }
                    }
                }
                .padding(.horizontal, Sp.lg).padding(.top, 56).padding(.bottom, 16)

                HStack(spacing: 14) {
                    Image(systemName: subType?.sfSymbol ?? "leaf.fill")
                        .font(.system(size: 24, weight: .light)).foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RESIDUO ORGÁNICO")
                            .font(.system(size: 9, weight: .semibold)).tracking(2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(subType?.displayName ?? "Identificando tipo…")
                            .font(.system(size: 24, weight: .bold)).tracking(-0.8)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, Sp.lg).padding(.bottom, 20)
            }
        }
        .frame(height: 200)
    }

    // MARK: - Step 1: Sub-clasificación

    private var stepSubType: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("¿Qué tipo de residuo orgánico es?")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(OrganicSubType.allCases) { type in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            subType = type
                            stepIn  = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            // Aceite/grasa y jardín van directo a resultados
                            step = (type == .frutaVerdura || type == .comidaCocinada) ? 2 : 3
                            if step == 3 { iniciarTimer() }
                            withAnimation(.easeOut(duration: 0.3)) { stepIn = true }
                        }
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(type.accentColor.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                Image(systemName: type.sfSymbol)
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(type.accentColor)
                            }
                            Text(type.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(uiColor: .label))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
                        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2: Estado del alimento

    private var stepFreshness: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("¿Está en buen estado?")

            // Contexto de por qué importa
            HStack(spacing: 8) {
                Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(Color.nexoBrand)
                Text("Si está fresca puede ir a un banco de alimentos — le llega a alguien que la necesita.")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineSpacing(2)
            }
            .padding(12)
            .background(Color.nexoMint, in: RoundedRectangle(cornerRadius: Rd.md))

            VStack(spacing: 10) {
                freshnessBtn(
                    icon    : "checkmark.circle.fill",
                    title   : "Sí, está fresca",
                    subtitle: "Puede ir al banco de alimentos",
                    color   : Color(hex: "2E7D32"),
                    value   : true
                )
                freshnessBtn(
                    icon    : "xmark.circle.fill",
                    title   : "No, está deteriorada",
                    subtitle: "Mejor para composta o biodigestión",
                    color   : Color(hex: "BF360C"),
                    value   : false
                )
            }
        }
    }

    private func freshnessBtn(icon: String, title: String, subtitle: String, color: Color, value: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isGoodState = value
                stepIn      = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                step = 3
                iniciarTimer()
                withAnimation(.easeOut(duration: 0.3)) { stepIn = true }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                    Text(subtitle).font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(Sp.md)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
            .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Resultados — rutas + timer

    private var stepResults: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Urgencia
            if let sub = subType {
                urgencyBanner(sub)
            }

            // Rutas recomendadas
            if let sub = subType {
                let routes = OrganicRoutingEngine.routes(for: sub, isGoodState: isGoodState ?? false)
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Rutas disponibles")
                    ForEach(Array(routes.enumerated()), id: \.offset) { idx, route in
                        routeCard(route, isPrimary: idx == 0)
                    }
                }
            }

            // Timer de fermentación
            if let timer = ferTimer {
                fermentationCard(timer)
            }

            // Guardar en historial
            saveButton
        }
    }

    // MARK: - Urgency banner

    private func urgencyBanner(_ sub: OrganicSubType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: sub == .aceiteGrasa ? "exclamationmark.triangle.fill" : "clock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sub.accentColor)
            Text(OrganicRoutingEngine.urgencyMessage(for: sub))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(uiColor: .label))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(sub.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(RoundedRectangle(cornerRadius: Rd.lg).strokeBorder(sub.accentColor.opacity(0.2), lineWidth: 0.5))
    }

    // MARK: - Route card

    private func routeCard(_ route: OrganicRoute, isPrimary: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(route.color.opacity(isPrimary ? 0.15 : 0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: route.icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(route.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(route.displayName)
                        .font(.system(size: 14, weight: isPrimary ? .semibold : .regular))
                        .foregroundStyle(Color(uiColor: .label))
                    if isPrimary {
                        Text("Recomendada")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.nexoBrand)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.nexoMint, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(route.description)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Sp.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Rd.lg)
                .strokeBorder(isPrimary ? route.color.opacity(0.3) : Color(uiColor: .separator),
                              lineWidth: isPrimary ? 1 : 0.5)
        )
    }

    // MARK: - Fermentation timer card

    private func fermentationCard(_ timer: FermentationTimer) -> some View {
        let urgency = timer.urgencyLevel
        let _ = tickDate   // dependencia para refrescar

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Timer de fermentación")
                    .font(.system(size: 12, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Spacer()
                if timer.isFrozen {
                    HStack(spacing: 4) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 11))
                        Text("Congelado")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "0288D1"))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(hex: "E1F5FE"), in: Capsule())
                }
            }

            // Barra de progreso
            VStack(spacing: 8) {
                // Tiempo restante
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if timer.isExpired {
                        Text("Fermentado")
                            .font(.system(size: 28, weight: .bold)).tracking(-1)
                            .foregroundStyle(.red)
                    } else {
                        Text("\(timer.hoursRemaining)")
                            .font(.system(size: 36, weight: .black)).tracking(-2)
                            .foregroundStyle(urgency.color)
                        Text("h \(timer.minutesRemaining)m restantes")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    Spacer()
                }

                // Barra visual
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(uiColor: .systemGray5))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(urgency.color)
                            .frame(width: max(8, geo.size.width * timer.progress), height: 8)
                            .animation(.easeInOut(duration: 0.5), value: timer.progress)
                    }
                }
                .frame(height: 8)

                // Labels de la barra
                HStack {
                    Text("Ahora")
                        .font(.system(size: 10)).foregroundStyle(Color(uiColor: .tertiaryLabel))
                    Spacer()
                    Text("Fermenta")
                        .font(.system(size: 10)).foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }

            // Acción: congelar
            if !timer.isFrozen && !timer.isExpired {
                Button {
                    congelar()
                } label: {
                    HStack(spacing: 8) {
                        if isFreezing {
                            ProgressView().scaleEffect(0.8).tint(Color(hex: "0288D1"))
                        } else {
                            Image(systemName: "snowflake")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Guardar en el congelador")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Extiende el tiempo 48 horas más")
                                .font(.system(size: 11, weight: .light))
                        }
                        Spacer()
                        Text("+48h")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: "E1F5FE"), in: Capsule())
                    }
                    .foregroundStyle(Color(hex: "0288D1"))
                    .padding(Sp.md)
                    .background(Color(hex: "E1F5FE"), in: RoundedRectangle(cornerRadius: Rd.md))
                    .overlay(RoundedRectangle(cornerRadius: Rd.md).strokeBorder(Color(hex: "0288D1").opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(isFreezing)
            }
        }
        .padding(Sp.lg)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Rd.lg)
                .strokeBorder(urgency.color.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button { guardarEnHistorial() } label: {
            HStack(spacing: 8) {
                Image(systemName: guardada ? "checkmark.circle.fill" : "clock.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                Text(guardada ? "Guardado en historial" : "Guardar en historial")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(guardada ? Color.nexoBrand : .white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(guardada ? Color.nexoMint : Color(hex: "1B5E20"),
                        in: RoundedRectangle(cornerRadius: Rd.lg))
            .shadow(color: Color(hex: "1B5E20").opacity(guardada ? 0 : 0.2), radius: 8, y: 3)
        }
        .disabled(guardada || subType == nil)
        .buttonStyle(.plain)
    }

    // MARK: - Success overlay

    private var savedOverlay: some View {
        ZStack {
            Color(hex: "1B5E20").opacity(0.97).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 90, height: 90)
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 44, weight: .light)).foregroundStyle(.white)
                }
                VStack(spacing: 8) {
                    Text("Guardado en historial")
                        .font(.system(size: 22, weight: .bold)).tracking(-1).foregroundStyle(.white)
                    Text("Recibirás una notificación\nantes de que fermente.")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center).lineSpacing(3)
                }
            }
        }
        .transition(.opacity)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { isPresented = false }
            }
        }
    }

    // MARK: - Lógica

    private func iniciarTimer() {
        guard let sub = subType else { return }
        var timer = FermentationTimer(
            uuid      : UUID(),
            subType   : sub,
            startDate : Date(),
            isFrozen  : false,
            frozenAt  : nil
        )
        timer.save()
        ferTimer = timer
        notifManager.schedule(for: timer)
    }

    private func congelar() {
        guard var timer = ferTimer, !timer.isFrozen else { return }
        isFreezing = true
        timer.isFrozen = true
        timer.frozenAt = Date()
        timer.save()
        notifManager.reschedule(for: timer)
        withAnimation(.spring(response: 0.4)) { ferTimer = timer }
        isFreezing = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func guardarEnHistorial() {
        guard let sub = subType else { return }
        let registro = FichaRegistro(material: material)
        context.insert(registro)
        guardada = true
        withAnimation(.easeOut(duration: 0.2)) { showSuccess = true }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold)).tracking(0.3)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}

#Preview {
    OrganicFichaView(
        material   : NEXOMaterial.all["organic_simple"]!,
        isPresented: .constant(true)
    )
    .modelContainer(for: FichaRegistro.self, inMemory: true)
}
