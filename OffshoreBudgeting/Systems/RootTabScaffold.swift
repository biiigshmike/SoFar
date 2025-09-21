import SwiftUI

/// Provides a consistent header layout for all root tab screens so the app presents
/// the same chrome across iPhone, iPad, and Mac.
struct RootTabScaffold<Trailing: View, Content: View>: View {
    private let title: String
    private let trailing: Trailing
    private let content: Content

    init(
        title: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) where Trailing == EmptyView {
        self.init(title: title, trailing: { EmptyView() }, content: content)
    }

    var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                RootTabHeader(title: title, trailing: trailing)
            }
            .ub_tabNavigationTitle(title)
            .modifier(RootNavigationVisibilityModifier())
    }

}

// MARK: - Header View
private struct RootTabHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.m) {
                Text(title)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
                trailing
                    .tint(themeManager.selectedTheme.resolvedTint)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, DS.Spacing.s)
        .background(
            themeManager.selectedTheme.background
                .overlay(alignment: .bottom) {
                    Divider()
                        .opacity(dividerOpacity)
                        .padding(.horizontal, horizontalPadding)
                }
                .ub_ignoreSafeArea(edges: .top)
        )
    }

    private var horizontalPadding: CGFloat { 16 }

    private var topPadding: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .compact ? DS.Spacing.xxl : DS.Spacing.l
        #else
        DS.Spacing.l
        #endif
    }

    private var dividerOpacity: Double {
        colorScheme == .dark ? 0.25 : 0.1
    }
}

// MARK: - Navigation Visibility
private struct RootNavigationVisibilityModifier: ViewModifier {
    #if os(iOS)
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content.navigationBarHidden(true)
        }
    }
    #else
    func body(content: Content) -> some View { content }
    #endif
}

// MARK: - Shared Header Button Label
struct RootTabHeaderButtonLabel: View {
    let title: String
    let systemImage: String

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeManager.selectedTheme.resolvedTint.opacity(backgroundOpacity))
            )
            .foregroundStyle(themeManager.selectedTheme.resolvedTint)
    }

    private var backgroundOpacity: Double {
        colorScheme == .dark ? 0.24 : 0.16
    }
}
