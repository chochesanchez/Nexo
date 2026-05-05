import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthService
    @State private var nombre = ""
    @State private var apellido = ""
    @State private var email = ""
    @State private var telefono = ""
    @State private var edadText = ""
    @State private var password = ""
    @State private var localError: String?

    var body: some View {
        VStack(spacing: 16) {
            TextField("Nombre", text: $nombre)
                .textFieldStyle(.roundedBorder)

            TextField("Apellido", text: $apellido)
                .textFieldStyle(.roundedBorder)

            TextField("Correo", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("Teléfono", text: $telefono)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)

            TextField("Edad", text: $edadText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

            SecureField("Contraseña", text: $password)
                .textFieldStyle(.roundedBorder)

            if let error = localError ?? auth.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            Button("Crear cuenta") {
                localError = nil
                auth.errorMessage = nil
                guard !nombre.isEmpty, !apellido.isEmpty, !email.isEmpty, !password.isEmpty else {
                    localError = "Completa todos los campos."
                    return
                }
                guard let edad = Int(edadText), edad >= 18 else {
                    localError = "Debes tener 18 años o más."
                    return
                }
                Task {
                    await auth.signUp(nombre: nombre, apellido: apellido, email: email, telefono: telefono, edad: edad, password: password)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Registro")
    }
}
