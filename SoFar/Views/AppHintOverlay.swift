//
//  AppHintOverlay.swift
//  SoFar
//
//  Presented at the bottom of the screen whenever `AppHintManager` has
//  an active hint. Style aims to work across iOS, iPadOS and macOS.
//

import SwiftUI

// MARK: - AppHintOverlay
struct AppHintOverlay: View {
    @EnvironmentObject private var hintManager: AppHintManager

    var body: some View {
        if let hint = hintManager.activeHint {
            VStack(spacing: 12) {
                Text(hint.message)
                    .multilineTextAlignment(.center)
                Button("Got it") {
                    hintManager.markSeen(hint)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
