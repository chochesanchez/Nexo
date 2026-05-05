import SwiftUI
import SwiftData
import WidgetKit

@Model
final class FichaRegistro {
    var classKey    : String
    var displayName : String
    var icon        : String
    var route       : String
    var co2         : String
    var water       : String
    var fecha       : Date

    init(material: NEXOMaterial) {
        self.classKey    = material.classKey
        self.displayName = material.displayName
        self.icon        = material.icon
        self.route       = material.route.rawValue
        self.co2         = material.co2
        self.water       = material.water
        self.fecha       = Date()
        HistorialView.writeWidgetData()
    }
}

struct HistorialView: View {
    @EnvironmentObject private var repo: ListingsRepository
    @Query(sort: \FichaRegistro.fecha, order: .reverse) private var registros: [FichaRegistro]
    @Environment(\.modelContext) private var context

    private var useRemote: Bool { !repo.history.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if repo.history.isEmpty && registros.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Sp.md) {
                            impactSummary
                            if useRemote { remoteList } else { listadoRegistros }
                        }
                        .padding(Sp.lg)
                    }
                }
            }
            .navigationTitle("Tu impacto")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !registros.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            registros.forEach { context.delete($0) }
                            Self.writeWidgetData(count: 0, co2: "0 g")
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }.accessibilityLabel("Borrar historial local")
                    }
                }
            }
            .task { await repo.fetchHistory() }
            .onChange(of: registros.count) { _, _ in
                Self.writeWidgetData(count: registros.count, co2: co2TotalLocal)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    static func writeWidgetData(count: Int? = nil, co2: String? = nil) {
        let defaults = UserDefaults(suiteName: "group.com.nexo.app")
        if let count { defaults?.set(count, forKey: "nexo_materiales_semana") }
        if let co2   { defaults?.set(co2,   forKey: "nexo_co2_semana") }
    }

    private var emptyState: some View {
        VStack(spacing: Sp.lg) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.nexoGreen.opacity(0.5))
            Text("Sin registros aún")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("Escanea tu primer residuo\npara empezar a ver tu impacto.")
                .font(.system(size: 15)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var impactSummary: some View {
        VStack(alignment: .leading, spacing: Sp.md) {
            Text("Esta semana")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase).kerning(0.6)
            HStack(spacing: Sp.sm) {
                summaryCell(icon: "arrow.3.trianglepath", label: "Materiales",
                            value: "\(useRemote ? repo.history.count : registros.count)",
                            color: Color.nexoGreen)
                summaryCell(icon: "wind", label: "CO₂ evitado",
                            value: useRemote ? co2TotalRemote : co2TotalLocal,
                            color: Color(hex: "6DB33F"))
            }
        }
    }

    private func summaryCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Sp.md)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .accessibilityElement(children: .combine).accessibilityLabel("\(label): \(value)")
    }

    private var remoteList: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("Registros")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase).kerning(0.6)
            VStack(spacing: Sp.xs) {
                ForEach(repo.history) { record in remoteRow(record) }
            }
        }
    }

    private func remoteRow(_ record: ScanRecord) -> some View {
        let fallback = NEXOMaterial.from(supabaseMaterial: record.material)
        let iconName = record.icon ?? fallback?.icon ?? "leaf.fill"
        let title    = record.displayName ?? record.material
        let routeStr = record.route ?? fallback?.route.rawValue ?? "Reciclaje"
        let co2Str   = record.co2 ?? fallback?.co2
        let valStr   = record.value ?? fallback?.value
        return HStack(spacing: Sp.md) {
            if let urlStr = record.imageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(width: 44, height: 44).clipShape(Circle())
                    default:
                        Circle().fill(Color.nexoGreen.opacity(0.15)).frame(width: 44, height: 44)
                            .overlay(Image(systemName: iconName)
                                .font(.system(size: 18)).foregroundStyle(Color.nexoGreen))
                    }
                }
            } else {
                ZStack {
                    Circle().fill(Color.nexoGreen.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: iconName)
                        .font(.system(size: 18)).foregroundStyle(Color.nexoGreen)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    Text(routeStr)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let co2 = co2Str {
                        Text("·").foregroundStyle(.secondary)
                        Text(co2).font(.system(size: 12)).foregroundStyle(Color.nexoGreen)
                    }
                    if let v = valStr {
                        Text("·").foregroundStyle(.secondary)
                        Text(v).font(.system(size: 12)).foregroundStyle(Color.nexoAmber)
                    }
                }
            }
            Spacer()
            Text(record.createdAt, style: .date)
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(Sp.md)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(routeStr), \(record.createdAt.formatted(date: .abbreviated, time: .omitted))")
    }

    private var listadoRegistros: some View {
        VStack(alignment: .leading, spacing: Sp.sm) {
            Text("Registros")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .textCase(.uppercase).kerning(0.6)
            VStack(spacing: Sp.xs) { ForEach(registros) { registroRow($0) } }
        }
    }

    private func registroRow(_ reg: FichaRegistro) -> some View {
        HStack(spacing: Sp.md) {
            ZStack {
                Circle().fill(Color.nexoGreen.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: reg.icon).font(.system(size: 18)).foregroundStyle(Color.nexoGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(reg.displayName).font(.system(size: 15, weight: .semibold))
                Text(reg.route).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(reg.fecha, style: .date).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(Sp.md)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Rd.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reg.displayName), \(reg.route), \(reg.fecha.formatted(date: .abbreviated, time: .omitted))")
    }

    var co2TotalLocal: String {
        let total = registros.compactMap { reg -> Double? in
            let digits = reg.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits)
        }.reduce(0, +)
        return total >= 1000 ? String(format: "%.1f kg", total / 1000) : "\(Int(total)) g"
    }

    private var co2TotalRemote: String {
        let total = repo.history.compactMap { record -> Double? in
            guard let mat = NEXOMaterial.from(supabaseMaterial: record.material) else { return nil }
            let digits = mat.co2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Double(digits)
        }.reduce(0, +)
        return total >= 1000 ? String(format: "%.1f kg", total / 1000) : "\(Int(total)) g"
    }
}
