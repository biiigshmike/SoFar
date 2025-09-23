//
//  HomeHeaderLayoutEnvironment.swift
//  Offshore
//
//  Created by Michael Brown on 9/23/25.
//

//  HomeHeaderLayoutEnvironment.swift
//  SoFar
//
//  Provides environment value for matching the width of the header "pills"
//  (calendar/plus/ellipsis group or period navigator) so subviews below the
//  header can align/center to the same width on all platforms.

import SwiftUI

// MARK: - Environment Key
private struct HomeHeaderPillMatchedWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    /// The computed width of the header's right-side pill controls (period navigator, etc.).
    /// When set, detail views can align secondary elements (like the income/savings grid)
    /// to exactly this width and center them beneath the pills for a consistent layout
    /// on macOS, iOS, and iPadOS.
    var homeHeaderPillMatchedWidth: CGFloat? {
        get { self[HomeHeaderPillMatchedWidthKey.self] }
        set { self[HomeHeaderPillMatchedWidthKey.self] = newValue }
    }
}
