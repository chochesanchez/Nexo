// ExplainView.swift — Light mode, liquid glass cards
import SwiftUI

struct ExplainView: View {
    @State private var selectedRole: AppRole? = nil
    @State private var contentIn = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            // Gradiente de fondo sutil
            VStack {
                LinearGradient(
                    colors: [Color.nexoMint.opacity(0.5), Color.clear],
                    startPoint: .top, endPoint: .bottom
                ).frame(height: 280)
                Spacer()
            }.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Text("¿Cómo usas NEXO?")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-1.5)
                        .foregroundStyle(Color(uiColor: .label))

                    Text("Esto define tu pantalla principal.\nPuedes cambiarlo en cualquier momento.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineSpacing(3)
                }
                .padding(.top, 72)
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 32)

                // Regla
                Rectangle()
                    .fill(Color.nexoForest.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.horizontal, Sp.lg)
                    .padding(.bottom, 28)

                // Tarjetas
                VStack(spacing: 12) {
                    RoleCard(
                        icon      : "house",
                        title     : "Hogar, escuela o negocio",
                        subtitle  : "Identifico residuos y los preparo para recolección.",
                        isSelected: selectedRole == .hogar
                    ) { withAnimation(.easeOut(duration: 0.2)) { selectedRole = .hogar } }

                    RoleCard(
                        icon      : "figure.walk",
                        title     : "Soy recolector",
                        subtitle  : "Busco materiales preparados cerca de mi ruta.",
                        isSelected: selectedRole == .recolector
                    ) { withAnimation(.easeOut(duration: 0.2)) { selectedRole = .recolector } }
                }
                .padding(.horizontal, Sp.lg)
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? 0 : 12)

                Spacer()

                // CTA
                NavigationLink(destination: SignUpView()) {
                    Group {
                        if selectedRole == nil {
                            Text("Selecciona un modo")
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        } else {
                            Text("Continuar")
                                .foregroundStyle(.white)
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        selectedRole == nil
                            ? Color(uiColor: .systemGray5)
                            : Color.nexoForest,
                        in: RoundedRectangle(cornerRadius: Rd.lg)
                    )
                    .animation(.easeOut(duration: 0.25), value: selectedRole)
                }
                .disabled(selectedRole == nil)
                .padding(.horizontal, Sp.lg)
                .padding(.bottom, 48)
                .simultaneousGesture(TapGesture().onEnded {
                    if let role = selectedRole {
                        UserDefaults.standard.set(role == .hogar ? "hogar" : "recolector", forKey: "nexoRole")
                    }
                })
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.nexoBrand)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { contentIn = true }
        }
    }
}

// MARK: - RoleCard — liquid glass light mode
struct RoleCard: View {
    let icon      : String
    let title     : String
    let subtitle  : String
    let isSelected: Bool
    let onTap     : () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Ícono en círculo
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.nexoMint : Color(uiColor: .systemGray6))
                        .frame(width: 44, height: 44)
                    Image(systemName: isSelected ? "\(icon).fill" : icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(isSelected ? Color.nexoBrand : Color(uiColor: .secondaryLabel))
                }

                // Texto
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Indicador
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.nexoBrand : Color(uiColor: .systemGray4),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color.nexoBrand)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(Sp.md)
            .background(
                isSelected
                    ? Color.nexoMint.opacity(0.5)
                    : Color(uiColor: .systemBackground),
                in: RoundedRectangle(cornerRadius: Rd.lg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Rd.lg)
                    .strokeBorder(
                        isSelected ? Color.nexoBrand.opacity(0.4) : Color(uiColor: .separator),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            // Liquid glass shadow sutil cuando está seleccionada
            .shadow(
                color: isSelected ? Color.nexoForest.opacity(0.08) : .clear,
                radius: 8, x: 0, y: 3
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

enum AppRole { case hogar, recolector }

#Preview {
    NavigationStack { ExplainView() }
}
