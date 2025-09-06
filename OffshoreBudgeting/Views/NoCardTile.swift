//
//  NoCardTile.swift
//  SoFar
//
//  Placeholder card tile used when a card is optional.
//

import SwiftUI

struct NoCardTile: View {
    // MARK: Inputs
    let isSelected: Bool

    // MARK: Layout
    /// ISO/ID-1 credit card aspect ratio (width / height).
    private let aspectRatio: CGFloat = 85.60 / 53.98 // ≈ 1.586
    private let cornerRadius: CGFloat = DS.Radius.card

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DS.Colors.cardFill)
            Text("No Card")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(selectionRingOverlay)
        .overlay(selectionGlowOverlay)
        .overlay(thinEdgeOverlay)
        .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 4)
        .accessibilityLabel(Text("No Card"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Overlays
private extension NoCardTile {
    var selectionRingOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius - 0.5, style: .continuous)
            .inset(by: 0.5)
            .stroke(
                isSelected ? Color.accentColor.opacity(0.95) : .clear,
                lineWidth: isSelected ? 2.5 : 0
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 1.5, style: .continuous)
                    .inset(by: 1.5)
                    .stroke(isSelected ? Color.white.opacity(0.45) : .clear, lineWidth: isSelected ? 0.8 : 0)
            )
            .allowsHitTesting(false)
    }

    var selectionGlowOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous)
            .stroke(Color.clear, lineWidth: 0)
            .shadow(color: Color.accentColor.opacity(isSelected ? 0.60 : 0), radius: isSelected ? 10 : 0)
            .shadow(color: Color.accentColor.opacity(isSelected ? 0.36 : 0), radius: isSelected ? 20 : 0)
            .shadow(color: Color.accentColor.opacity(isSelected ? 0.18 : 0), radius: isSelected ? 34 : 0)
            .padding(isSelected ? -1 : 0)
            .allowsHitTesting(false)
    }

    var thinEdgeOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
            .allowsHitTesting(false)
    }
}

