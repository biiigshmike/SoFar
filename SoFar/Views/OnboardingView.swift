//
//  OnboardingView.swift
//  SoFar
//
//  Created by OpenAI on 2024-05-30.
//
//  Simple page-based tour displayed on first launch.
//

import SwiftUI

// MARK: - OnboardingView
/// Displays a brief introduction the first time the app launches.
/// Dismisses by setting `guidance.hasSeenTour` to `true`.
struct OnboardingView: View {
    @EnvironmentObject private var guidance: GuidanceManager
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        TabView {
            OnboardingPage(
                image: "hands.sparkles",
                title: "Welcome to SoFar",
                message: "Keep your budgets on track across iPhone, iPad, and Mac."
            )
            OnboardingPage(
                image: "list.bullet.rectangle",
                title: "Plan Ahead",
                message: "Create budgets and planned expenses with just a few taps."
            )
            OnboardingPage(
                image: "gearshape",
                title: "Make it Yours",
                message: "Themes and settings let you customize the experience."
            )
        }
        .tabViewStyle(.page)
        .overlay(alignment: .bottom) {
            Button(action: { guidance.hasSeenTour = true }) {
                Text("Get Started")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(themeManager.selectedTheme.accent)
                    .foregroundStyle(Color.white)
                    .cornerRadius(12)
                    .padding()
            }
        }
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
    }
}

// MARK: - OnboardingPage
private struct OnboardingPage: View {
    let image: String
    let title: String
    let message: String
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: image)
                .font(.system(size: 64))
                .foregroundStyle(themeManager.selectedTheme.accent)
            Text(title)
                .font(.title2).bold()
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

