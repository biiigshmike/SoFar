//
//  PresetsView.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI

struct PresetsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Presets")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Manage your budget presets")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .appToolbar(
            titleDisplayMode: .large,
            trailingItems: [
                .add { print("Add preset tapped") }
            ]
        )
    }
}
