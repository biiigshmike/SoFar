import SwiftUI

// MARK: - AppTourView
/// Multi-page onboarding tour shown on first launch. Customize the
/// pages to highlight key features of the app.
struct AppTourView: View {
    @EnvironmentObject private var tourManager: AppTourManager

    var body: some View {
        TabView {
            TourPage(imageSystemName: "creditcard",
                     title: "Track Cards",
                     message: "Keep an eye on every swipe with real-time budgets.")
            TourPage(imageSystemName: "chart.pie.fill",
                     title: "Visual Budgets",
                     message: "Colorful charts help you understand spending patterns.")
            TourPage(imageSystemName: "gearshape",
                     title: "Customize",
                     message: "Themes and settings make the app your own.",
                     showDone: true) {
                tourManager.completeTour()
            }
        }
        .tabViewStyle(.page)
        .frame(minWidth: 300, minHeight: 300)
    }
}

// MARK: - TourPage
private struct TourPage: View {
    let imageSystemName: String
    let title: String
    let message: String
    var showDone: Bool = false
    var onDone: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: imageSystemName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            Text(title)
                .font(.title).fontWeight(.bold)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            if showDone {
                Button("Get Started") { onDone?() }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
            }
        }
        .padding()
    }
}
