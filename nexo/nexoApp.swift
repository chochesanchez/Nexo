//
//  nexoApp.swift
//  nexo
//
//  Created by José Manuel Sánchez Pérez on 04/05/26.
//

import SwiftUI

@main
struct nexoApp: App {
    @StateObject private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            if auth.isAuthenticated {
                ContentView()
            } else {
                LoginView()
            }
        }
        .task {
            await auth.loadSession()
        }
    }
}
