#if os(macOS)
import SwiftUI

struct MacLiquidGlassNavigationBar<Content: View, Leading: View, Principal: View, Trailing: View>: View {
    private let supportsTranslucency: Bool
    private let content: () -> Content
    private let leading: () -> Leading
    private let principal: () -> Principal
    private let trailing: () -> Trailing

    init(
        supportsTranslucency: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder principal: @escaping () -> Principal,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.supportsTranslucency = supportsTranslucency
        self.content = content
        self.leading = leading
        self.principal = principal
        self.trailing = trailing
    }

    var body: some View {
        navigationContainer
            .toolbar {
                if hasLeading {
                    ToolbarItem(placement: .navigation) {
                        glassToolbarItem(leading())
                    }
                }

                if hasPrincipal {
                    ToolbarItem(placement: .principal) {
                        principal()
                    }
                }

                if hasTrailing {
                    ToolbarItem(placement: .primaryAction) {
                        glassToolbarItem(trailing())
                    }
                }
            }
    }

    @ViewBuilder
    private var navigationContainer: some View {
        if #available(macOS 13.0, *) {
            NavigationStack {
                content()
            }
            .modifier(MacNavigationGlassModifier(supportsTranslucency: supportsTranslucency))
        } else {
            NavigationView {
                content()
            }
            .modifier(MacNavigationGlassModifier(supportsTranslucency: supportsTranslucency))
        }
    }

    private var hasLeading: Bool { Leading.self != EmptyView.self }
    private var hasPrincipal: Bool { Principal.self != EmptyView.self }
    private var hasTrailing: Bool { Trailing.self != EmptyView.self }

    @ViewBuilder
    private func glassToolbarItem<V: View>(_ view: V) -> some View {
        if supportsTranslucency {
            if #available(macOS 26.0, *) {
                view.glassEffect()
            } else {
                view
            }
        } else {
            view
        }
    }
}

private struct MacNavigationGlassModifier: ViewModifier {
    let supportsTranslucency: Bool

    func body(content: Content) -> some View {
        if supportsTranslucency {
            if #available(macOS 26.0, *) {
                content.glassEffect()
            } else {
                content
            }
        } else {
            content
        }
    }
}

extension MacLiquidGlassNavigationBar where Leading == EmptyView, Principal == EmptyView, Trailing == EmptyView {
    init(
        supportsTranslucency: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            supportsTranslucency: supportsTranslucency,
            content: content,
            leading: { EmptyView() },
            principal: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

extension MacLiquidGlassNavigationBar where Leading == EmptyView, Trailing == EmptyView {
    init(
        supportsTranslucency: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder principal: @escaping () -> Principal
    ) {
        self.init(
            supportsTranslucency: supportsTranslucency,
            content: content,
            leading: { EmptyView() },
            principal: principal,
            trailing: { EmptyView() }
        )
    }
}
#endif
