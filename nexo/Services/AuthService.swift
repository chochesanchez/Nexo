import Foundation
import Supabase
import Combine

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var errorMessage: String?

    private let client = SupabaseClientProvider.shared.client

    private init() {}

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            try await client.auth.signIn(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = "Correo o contraseña incorrectos."
            print("[Auth] signIn:", error)
        }
    }

    func signUp(nombre: String, apellido: String, email: String, telefono: String, edad: Int, password: String) async {
    errorMessage = nil
    do {
        let response = try await client.auth.signUp(email: email, password: password)
        let user = response.user
        try await client.auth.update(user: UserAttributes(data: [
            "full_name": AnyJSON(stringLiteral: "\(nombre) \(apellido)")
        ]))
        let profile = NewProfile(userId: user.id, nombre: nombre, apellido: apellido, telefono: telefono, correo: email, edad: edad)
        try await client.from("profiles").insert(profile).execute()
        isAuthenticated = response.session != nil
    } catch {
        errorMessage = "Error al registrarse. Intenta con otro correo."
        print("[Auth] signUp:", error)
    }
}



    func signOut() async {
        do {
            try await client.auth.signOut()
            isAuthenticated = false
        } catch {
            print("[Auth] signOut:", error)
        }
    }

    func loadSession() async {
        isAuthenticated = client.auth.currentSession != nil
    }

}
