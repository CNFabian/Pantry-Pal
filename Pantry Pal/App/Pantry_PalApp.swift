//
//  Pantry_PalApp.swift
//  Pantry Pal
//
//  Created by Christopher Fabian on 6/18/25.
//

import SwiftUI

@main
struct Pantry_PalApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
