//
//  RootTabScaffold.swift
//  OffshoreBudgeting
//
//  Created to standardize root tab layouts across platforms.
//

import SwiftUI

/// Shared container for top-level tab views so titles and header actions render consistently
/// across iOS, iPadOS, and macOS. On iOS compact-width environments (e.g., iPhone portrait)
/// a safe-area header replaces the navigation bar chrome to avoid clipping while preserving
/// toolbar behaviour on wider devices. macOS and Mac Catalyst always show a large title
/// above the supplied content.
struct RootTabScaffold<Content: View, HeaderActions: View>: View {

    // MARK: Properties
    private let title: String
    private let usesCompactHeaderOnIOS: Bool
    private let macHeaderPadding: EdgeInsets
    private let iosHeaderPadding: EdgeInsets
    private let contentBuilder: () -> Content
    private let headerActionsBuilder: () -> HeaderActions

    @EnvironmentObject private var themeManager: ThemeManager
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    // MARK: Initializers
    init(
        title: String,
        iOSCompactHeader: Bool = false,
        macHeaderPadding: EdgeInsets = EdgeInsets(
            top: DS.Spacing.l,
            leading: DS.Spacing.l,
            bottom: DS.Spacing.s,
            trailing: DS.Spacing.l
        ),
        iosHeaderPadding: EdgeInsets = EdgeInsets(
            top: DS.Spacing.xxl,
            leading: DS.Spacing.l,
            bottom: DS.Spacing.s,
            trailing: DS.Spacing.l
        ),
        @ViewBuilder headerActions: @escaping () -> HeaderActions,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.usesCompactHeaderOnIOS = iOSCompactHeader
        self.macHeaderPadding = macHeaderPadding
        self.iosHeaderPadding = iosHeaderPadding
        self.headerActionsBuilder = headerActions
        self.contentBuilder = content
    }

    init(
        title: String,
        iOSCompactHeader: Bool = false,
        macHeaderPadding: EdgeInsets = EdgeInsets(
            top: DS.Spacing.l,
            leading: DS.Spacing.l,
            bottom: DS.Spacing.s,
            trailing: DS.Spacing.l
        ),
        iosHeaderPadding: EdgeInsets = EdgeInsets(
            top: DS.Spacing.xxl,
            leading: DS.Spacing.l,
            bottom: DS.Spacing.s,
            trailing: DS.Spacing.l
        ),
        @ViewBuilder content: @escaping () -> Content
    ) where HeaderActions == EmptyView {
        self.init(
            title: title,
            iOSCompactHeader: iOSCompactHeader,
            macHeaderPadding: macHeaderPadding,
            iosHeaderPadding: iosHeaderPadding,
            headerActions: { EmptyView() },
            content: content
        )
    }

    // MARK: Body
    var body: some View {
        container
            .ub_tabNavigationTitle(title)
        #if os(iOS)
            .safeAreaInset(edge: .top, spacing: 0) {
                if shouldUseCompactHeader {
                    compactIOSHeader
                }
            }
            .modifier(NavigationBarVisibilityModifier(isHidden: shouldUseCompactHeader))
        #endif
    }

    private var container: some View {
        VStack(alignment: .leading, spacing: 0) {
            #if os(macOS) || targetEnvironment(macCatalyst)
            macHeader
            #endif
            contentBuilder()
        }
    }

    #if os(iOS)
    private var shouldUseCompactHeader: Bool {
        usesCompactHeaderOnIOS && horizontalSizeClass == .compact
    }
    #else
    private var shouldUseCompactHeader: Bool { false }
    #endif

    #if os(macOS) || targetEnvironment(macCatalyst)
    private var macHeader: some View {
        Text(title)
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(macHeaderPadding)
    }
    #endif

    #if os(iOS)
    private var compactIOSHeader: some View {
        VStack(spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.m) {
                Text(title)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                headerActionsBuilder()
            }
        }
        .padding(iosHeaderPadding)
        .background(
            themeManager.selectedTheme.background
                .ub_ignoreSafeArea(edges: .top)
        )
    }
    #endif
}

#if os(iOS)
private struct NavigationBarVisibilityModifier: ViewModifier {
    let isHidden: Bool

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.toolbar(isHidden ? .hidden : .visible, for: .navigationBar)
        } else {
            content.navigationBarHidden(isHidden)
        }
    }
}
#endif
