import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email    = ""
    @State private var password = ""
    @State private var contentIn = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack {
                LinearGradient(
                    colors: [Color.nexoMint.opacity(0.6), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 320)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Eyebrow
                Text("Bienvenido de vuelta")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2).textCase(.uppercase)
                    .foregroundStyle(Color.nexoBrand.opacity(0.5))
                    .padding(.bottom, 16)
                    .opacity(contentIn ? 1 : 0)

                // Título
                Text("Inicia\nsesión")
                    .font(.system(size: 52, weight: .bold))
                    .tracking(-3)
                    .foregroundStyle(Color.nexoForest)
                    .opacity(contentIn ? 1 : 0)
                    .offset(y: contentIn ? 0 : 10)

                // Regla
                Rectangle()
                    .fill(Color.nexoForest.opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.vertical, 20)
                    .opacity(contentIn ? 1 : 0)

                // Subtítulo
                Text("Accede a tu cuenta\npara continuar.")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineSpacing(4)
                    .opacity(contentIn ? 1 : 0)
                    .offset(y: contentIn ? 0 : 8)

                Spacer()

                // Campos
                VStack(spacing: 0) {
                    loginField("Correo electrónico", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Rectangle()
                        .fill(Color(uiColor: .separator))
                        .frame(height: 0.5)
                        .padding(.leading, Sp.md)

                    loginSecureField("Contraseña", text: $password)
                }
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: Rd.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Rd.lg)
                        .strokeBorder(Color.nexoForest.opacity(0.1), lineWidth: 0.5)
                )
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? 0 : 10)
                .padding(.bottom, Sp.md)

                // Error
                if let error = auth.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 13)).foregroundStyle(.red)
                        Text(error)
                            .font(.system(size: 13, weight: .regular)).foregroundStyle(.red)
                    }
                    .padding(.bottom, Sp.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Botones 
                VStack(spacing: 10) {
                    Button {
                        Task { await auth.signIn(email: email, password: password) }
                    } label: {
                        Text("Iniciar sesión")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Color.nexoForest, in: RoundedRectangle(cornerRadius: Rd.lg))
                            .shadow(color: Color.nexoForest.opacity(0.25), radius: 12, y: 4)
                    }

                    NavigationLink(destination: SignUpView()) {
                        Text("¿No tienes cuenta? Regístrate")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.nexoBrand)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Rd.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: Rd.lg)
                                    .strokeBorder(Color.nexoForest.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                }
                .opacity(contentIn ? 1 : 0)
                .offset(y: contentIn ? 0 : 14)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, Sp.lg)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Regresar")
                            .font(.system(size: 15, weight: .regular))
                    }
                    .foregroundStyle(Color.nexoForest)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.1)) { contentIn = true }
        }
    }

    // MARK: - Campos

    private func loginField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color(uiColor: .label))
            .padding(.horizontal, Sp.md)
            .frame(height: 52)
            .tint(Color.nexoBrand)
    }

    private func loginSecureField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color(uiColor: .label))
            .padding(.horizontal, Sp.md)
            .frame(height: 52)
            .tint(Color.nexoBrand)
    }
}

#Preview {
    NavigationStack {
        LoginView().environmentObject(AuthService.shared)
    }
}
