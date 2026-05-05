//
//  Organicwasteservice.swift
//  nexo
//
//  Created by Guillermo Lira on 05/05/26.
//

// OrganicWasteService.swift
// Flujo completo para residuos orgánicos:
//   • Sub-clasificación en 4 tipos
//   • Routing inteligente (banco de alimentos / composta / biodigestión / especial)
//   • Timer de fermentación con opción "Congelar"
//   • Notificaciones locales a las 20h (aviso) y 24h (crítico)

import SwiftUI
import UserNotifications
import Foundation

// MARK: - Sub-tipos de residuo orgánico

enum OrganicSubType: String, CaseIterable, Identifiable {
    case frutaVerdura   = "fruta_verdura"
    case comidaCocinada = "comida_cocinada"
    case jardinHojas    = "jardin_hojas"
    case aceiteGrasa    = "aceite_grasa"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .frutaVerdura:   return "Fruta o verdura"
        case .comidaCocinada: return "Comida cocinada"
        case .jardinHojas:    return "Jardín u hojas"
        case .aceiteGrasa:    return "Aceite o grasa"
        }
    }

    var icon: String {
        switch self {
        case .frutaVerdura:   return "apple.logo"
        case .comidaCocinada: return "fork.knife"
        case .jardinHojas:    return "leaf"
        case .aceiteGrasa:    return "drop.fill"
        }
    }

    var sfSymbol: String {
        switch self {
        case .frutaVerdura:   return "apple.logo"
        case .comidaCocinada: return "fork.knife"
        case .jardinHojas:    return "leaf"
        case .aceiteGrasa:    return "drop.fill"
        }
    }

    /// Horas antes de que empiece a fermentar / deteriorarse
    var fermentationHours: Int {
        switch self {
        case .frutaVerdura:   return 24
        case .comidaCocinada: return 12
        case .jardinHojas:    return 72
        case .aceiteGrasa:    return 240   // aceite no fermenta rápido
        }
    }

    var accentColor: Color {
        switch self {
        case .frutaVerdura:   return Color(hex: "4CAF50")
        case .comidaCocinada: return Color(hex: "FF8C00")
        case .jardinHojas:    return Color(hex: "2E7D32")
        case .aceiteGrasa:    return Color(hex: "F9A825")
        }
    }
}

// MARK: - Rutas disponibles para orgánicos

enum OrganicRoute: Identifiable {
    case bancoAlimentos
    case compostaEnCasa
    case biodigestionMunicipal
    case recolectorOrganico
    case centroAcopioAceite

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .bancoAlimentos:        return "Banco de Alimentos"
        case .compostaEnCasa:        return "Composta en casa"
        case .biodigestionMunicipal: return "Biodigestión municipal"
        case .recolectorOrganico:    return "Recolector de orgánicos"
        case .centroAcopioAceite:    return "Centro de acopio de aceite"
        }
    }

    var description: String {
        switch self {
        case .bancoAlimentos:
            return "Alimento en buen estado que puede ayudar a otras personas antes de desperdiciarse."
        case .compostaEnCasa:
            return "Conviértelo en abono para plantas. Sin costo, sin intermediarios, cero desperdicio."
        case .biodigestionMunicipal:
            return "CDMX tiene plantas de biodigestión que convierten orgánicos en gas y fertilizante."
        case .recolectorOrganico:
            return "Recolectores especializados en rutas de orgánicos en tu colonia."
        case .centroAcopioAceite:
            return "El aceite usado nunca va al drenaje. Un litro contamina 1,000 litros de agua."
        }
    }

    var icon: String {
        switch self {
        case .bancoAlimentos:        return "heart.fill"
        case .compostaEnCasa:        return "leaf.circle.fill"
        case .biodigestionMunicipal: return "building.2.fill"
        case .recolectorOrganico:    return "person.fill"
        case .centroAcopioAceite:    return "drop.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .bancoAlimentos:        return Color(hex: "E53935")
        case .compostaEnCasa:        return Color(hex: "2E7D32")
        case .biodigestionMunicipal: return Color(hex: "1565C0")
        case .recolectorOrganico:    return Color(hex: "4CAF50")
        case .centroAcopioAceite:    return Color(hex: "F9A825")
        }
    }

    var isPrimary: Bool {
        switch self {
        case .bancoAlimentos, .compostaEnCasa, .centroAcopioAceite: return true
        default: return false
        }
    }
}

// MARK: - Motor de routing

enum OrganicRoutingEngine {
    static func routes(for subType: OrganicSubType, isGoodState: Bool) -> [OrganicRoute] {
        switch subType {
        case .frutaVerdura:
            if isGoodState {
                return [.bancoAlimentos, .compostaEnCasa, .biodigestionMunicipal]
            } else {
                return [.compostaEnCasa, .biodigestionMunicipal, .recolectorOrganico]
            }
        case .comidaCocinada:
            return [.biodigestionMunicipal, .compostaEnCasa, .recolectorOrganico]
        case .jardinHojas:
            return [.compostaEnCasa, .biodigestionMunicipal]
        case .aceiteGrasa:
            return [.centroAcopioAceite]
        }
    }

    static func urgencyMessage(for subType: OrganicSubType) -> String {
        switch subType {
        case .frutaVerdura:
            return "Tienes ~24 horas antes de que pierda valor nutricional y empiece a fermentar."
        case .comidaCocinada:
            return "La comida cocinada fermenta rápido — actúa en las próximas 12 horas."
        case .jardinHojas:
            return "Puedes guardar hojas y ramas hasta 3 días sin problema."
        case .aceiteGrasa:
            return "Nunca al drenaje. Un litro de aceite contamina 1,000 litros de agua potable."
        }
    }
}

// MARK: - Timer de fermentación

struct FermentationTimer {
    let uuid         : UUID
    let subType      : OrganicSubType
    let startDate    : Date
    var isFrozen     : Bool
    var frozenAt     : Date?

    var deadlineDate: Date {
        let baseHours = subType.fermentationHours
        let extraHours = isFrozen ? 48 : 0
        return startDate.addingTimeInterval(Double(baseHours + extraHours) * 3600)
    }

    var timeRemaining: TimeInterval { max(0, deadlineDate.timeIntervalSinceNow) }
    var isExpired: Bool             { timeRemaining <= 0 }
    var hoursRemaining: Int         { Int(timeRemaining / 3600) }
    var minutesRemaining: Int       { Int((timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60) }

    var progress: Double {
        let total = Double(subType.fermentationHours + (isFrozen ? 48 : 0)) * 3600
        return min(1, max(0, 1 - (timeRemaining / total)))
    }

    var urgencyLevel: UrgencyLevel {
        let pct = progress
        if pct < 0.6  { return .safe    }
        if pct < 0.85 { return .warning }
        return .critical
    }

    enum UrgencyLevel {
        case safe, warning, critical
        var color: Color {
            switch self { case .safe: return .nexoGreen; case .warning: return .orange; case .critical: return .red }
        }
    }

    // Persiste en UserDefaults
    static let udKey = "nexo_organic_timers"

    func save() {
        var timers = Self.loadAll()
        timers[uuid.uuidString] = [
            "subType"  : subType.rawValue,
            "start"    : startDate.timeIntervalSince1970,
            "frozen"   : isFrozen,
            "frozenAt" : frozenAt?.timeIntervalSince1970 ?? 0
        ]
        UserDefaults.standard.set(timers, forKey: Self.udKey)
    }

    static func loadAll() -> [String: [String: Any]] {
        UserDefaults.standard.dictionary(forKey: udKey) as? [String: [String: Any]] ?? [:]
    }
}

// MARK: - Notification Manager

final class FermentationNotificationManager {

    static let shared = FermentationNotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Programa aviso a las (baseHours - 4)h y notificación crítica a baseHours
    func schedule(for timer: FermentationTimer) {
        let center = UNUserNotificationCenter.current()
        let base = timer.deadlineDate

        // ── Aviso previo (4h antes del límite) ───────────────────────────────
        let warningDate = base.addingTimeInterval(-4 * 3600)
        if warningDate > Date() {
            let warningContent = UNMutableNotificationContent()
            warningContent.title = "Tu orgánico está a punto de fermentar"
            warningContent.body  = "Quedan ~4 horas para que \(timer.subType.displayName.lowercased()) empiece a fermentar. Actúa ahora."
            warningContent.sound = .default
            warningContent.categoryIdentifier = "ORGANIC_WARNING"

            let warningComps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: warningDate)
            let warningTrigger = UNCalendarNotificationTrigger(dateMatching: warningComps, repeats: false)
            let warningReq = UNNotificationRequest(
                identifier: "nexo_organic_warning_\(timer.uuid.uuidString)",
                content: warningContent,
                trigger: warningTrigger
            )
            center.add(warningReq)
        }

        // ── Notificación crítica (al llegar al límite) ─────────────────────
        if base > Date() {
            let criticalContent = UNMutableNotificationContent()
            criticalContent.title = "¡Tu orgánico ya fermentó!"
            criticalContent.body  = "El \(timer.subType.displayName.lowercased()) ya superó su tiempo óptimo. Disponlo ahora o pasará al relleno sanitario."
            criticalContent.sound = .defaultCritical
            criticalContent.categoryIdentifier = "ORGANIC_CRITICAL"
            criticalContent.interruptionLevel   = .timeSensitive

            let criticalComps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: base)
            let criticalTrigger = UNCalendarNotificationTrigger(dateMatching: criticalComps, repeats: false)
            let criticalReq = UNNotificationRequest(
                identifier: "nexo_organic_critical_\(timer.uuid.uuidString)",
                content: criticalContent,
                trigger: criticalTrigger
            )
            center.add(criticalReq)
        }
    }

    /// Cancela y reprograma cuando el usuario congela
    func reschedule(for timer: FermentationTimer) {
        cancel(uuid: timer.uuid)
        schedule(for: timer)
    }

    func cancel(uuid: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "nexo_organic_warning_\(uuid.uuidString)",
            "nexo_organic_critical_\(uuid.uuidString)"
        ])
    }
}
