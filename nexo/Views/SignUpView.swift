import SwiftUI
import PhotosUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthService
    @State private var nombre      = ""
    @State private var apellido    = ""
    @State private var email       = ""
    @State private var telefono    = ""
    @State private var edadText    = ""
    @State private var password    = ""
    @State private var localError  : String?
    @State private var isLoading   = false
    @State private var avatarItem  : PhotosPickerItem? = nil
    @State private var avatarData  : Data?             = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 88, height: 88)
                        if let data = avatarData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 38))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: avatarItem) { _, item in
                    Task { avatarData = try? await item?.loadTransferable(type: Data.self) }
                }

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
                        isLoading = true
                        await auth.signUp(
                            nombre    : nombre,
                            apellido  : apellido,
                            email     : email,
                            telefono  : telefono,
                            edad      : edad,
                            password  : password,
                            avatarData: avatarData
                        )
                        isLoading = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if isLoading {
                    ProgressView()
                }
            }
            .padding()
        }
        .navigationTitle("Registro")
    }
}
