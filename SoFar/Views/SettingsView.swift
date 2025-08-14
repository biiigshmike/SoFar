//
//  SettingsView.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Configure your app preferences")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .appToolbar(
            titleDisplayMode: .large
        )
    }
}
