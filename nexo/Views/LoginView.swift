import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Correo", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Contraseña", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let error = auth.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                Button("Iniciar sesión") {
                    Task { await auth.signIn(email: email, password: password) }
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Registrarse") {
                    SignUpView()
                }
            }
            .padding()
            .navigationTitle("NEXO")
        }
    }
}
