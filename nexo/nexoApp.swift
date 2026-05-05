//
//  nexoApp.swift
//  nexo
//
//  Created by José Manuel Sánchez Pérez on 04/05/26.
//

import SwiftUI
import SwiftData

@main
struct nexoApp: App {

    @StateObject private var repo     = ListingsRepository()
    @StateObject private var location = LocationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(repo)
                .environmentObject(location)
        }
        .modelContainer(for: FichaRegistro.self)
    }
}
