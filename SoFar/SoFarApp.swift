//
//  SoFarApp.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI

@main
struct SoFarApp: App {
    init() {
        CoreDataService.shared.ensureLoaded()
    }
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
