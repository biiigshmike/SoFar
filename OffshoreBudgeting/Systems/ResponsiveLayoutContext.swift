import SwiftUI
import UIKit

/// Aggregates the environmental data points that influence how a layout should
/// respond to changing device characteristics. Inject a single instance high in
/// the scene hierarchy so that descendants can inspect the same snapshot when
/// making adaptive decisions.
struct ResponsiveLayoutContext: Equatable {
    /// Enum describing the relevant traits for the current platform. Using our
    /// own abstraction keeps the API consistent across UIKit- and AppKit-backed
    /// targets without leaking platform-specific types into the view layer.
    enum Idiom: Equatable {
        case phone
        case pad
        case mac
        case car
        case vision
        case unspecified

        static var current: Idiom {
            #if targetEnvironment(macCatalyst)
            return .mac
            #else
            return .unspecified
            #endif
        }
    }

    var containerSize: CGSize
    var safeArea: EdgeInsets
    var horizontalSizeClass: UserInterfaceSizeClass?
    var verticalSizeClass: UserInterfaceSizeClass?
    var dynamicTypeSize: DynamicTypeSize
    var idiom: Idiom
    var isLandscape: Bool

    init(
        containerSize: CGSize = .zero,
        safeArea: EdgeInsets = EdgeInsets(),
        horizontalSizeClass: UserInterfaceSizeClass? = nil,
        verticalSizeClass: UserInterfaceSizeClass? = nil,
        dynamicTypeSize: DynamicTypeSize = .medium,
        idiom: Idiom = .unspecified,
        isLandscape: Bool = false
    ) {
        self.containerSize = containerSize
        self.safeArea = safeArea
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
        self.dynamicTypeSize = dynamicTypeSize
        self.idiom = idiom
        self.isLandscape = isLandscape
    }
}

private struct ResponsiveLayoutContextKey: EnvironmentKey {
    static let defaultValue = ResponsiveLayoutContext()
}

extension EnvironmentValues {
    var responsiveLayoutContext: ResponsiveLayoutContext {
        get { self[ResponsiveLayoutContextKey.self] }
        set { self[ResponsiveLayoutContextKey.self] = newValue }
    }
}

extension View {
    /// Injects the provided responsive layout context into the environment so
    /// that descendants can opt into it without threading values manually.
    func responsiveLayoutContext(_ context: ResponsiveLayoutContext) -> some View {
        environment(\.responsiveLayoutContext, context)
    }
}

/// Convenience edge inset helpers shared by multiple layout consumers.
extension EdgeInsets {
    var hasNonZeroInsets: Bool {
        top != 0 || leading != 0 || bottom != 0 || trailing != 0
    }
}

/// Captures geometry information and injects a ``ResponsiveLayoutContext`` into
/// the view hierarchy. The reader always vends a context through the
/// environment, but the supplied closure also receives the context directly so
/// that callers can make ad-hoc decisions without performing another lookup.
struct ResponsiveLayoutReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.ub_safeAreaInsets) private var legacySafeAreaInsets

    private let content: (ResponsiveLayoutContext) -> Content

    init(@ViewBuilder content: @escaping (ResponsiveLayoutContext) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let context = makeContext(using: proxy)

            content(context)
                .responsiveLayoutContext(context)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .modifier(LegacySafeAreaCapture())
    }

    private func makeContext(using proxy: GeometryProxy) -> ResponsiveLayoutContext {
        ResponsiveLayoutContext(
            containerSize: proxy.size,
            safeArea: resolvedSafeAreaInsets(from: proxy),
            horizontalSizeClass: horizontalSizeClass,
            verticalSizeClass: verticalSizeClass,
            dynamicTypeSize: dynamicTypeSize,
            idiom: .current,
            isLandscape: proxy.size.width > proxy.size.height && proxy.size.width > 0 && proxy.size.height > 0
        )
    }

    private func resolvedSafeAreaInsets(from proxy: GeometryProxy) -> EdgeInsets {
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            return proxy.safeAreaInsets
        } else {
            return legacySafeAreaInsets
        }
    }
}

private struct LegacySafeAreaCapture: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            content
        } else {
            content.ub_captureSafeAreaInsets()
        }
    }
}
