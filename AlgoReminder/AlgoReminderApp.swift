//
//  AlgoReminderApp.swift
//  AlgoReminder
//
//  Created by Planetes on 2025/8/25.
//

import SwiftUI

@main
struct AlgoReminderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
