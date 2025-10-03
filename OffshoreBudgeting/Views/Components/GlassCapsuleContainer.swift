import SwiftUI

// MARK: - GlassCapsuleContainer
struct GlassCapsuleContainer<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.responsiveLayoutContext) private var layoutContext
    @Environment(\.platformCapabilities) private var capabilities

    private let content: Content
    private let minimumHeight: CGFloat?
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    private let contentAlignment: Alignment
    private let namespace: Namespace.ID?
    private let glassID: String?
    private let transitionStorage: Any?

    init(
        minimumHeight: CGFloat? = nil,
        horizontalPadding: CGFloat = DS.Spacing.l,
        verticalPadding: CGFloat = DS.Spacing.m,
        alignment: Alignment = .leading,
        namespace: Namespace.ID? = nil,
        glassID: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.minimumHeight = minimumHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.contentAlignment = alignment
        self.namespace = namespace
        self.glassID = glassID
        self.transitionStorage = nil
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    init(
        minimumHeight: CGFloat? = nil,
        horizontalPadding: CGFloat = DS.Spacing.l,
        verticalPadding: CGFloat = DS.Spacing.m,
        alignment: Alignment = .leading,
        namespace: Namespace.ID? = nil,
        glassID: String? = nil,
        transition: GlassEffectTransition,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.minimumHeight = minimumHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.contentAlignment = alignment
        self.namespace = namespace
        self.glassID = glassID
        self.transitionStorage = transition
    }

    var body: some View {
        let _ = themeManager
        let _ = layoutContext

        let capsule = Capsule(style: .continuous)
        let decorated = content
            .frame(maxWidth: .infinity, alignment: contentAlignment)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minimumHeight)
            .contentShape(capsule)

        if #available(iOS 26.0, macCatalyst 26.0, *), capabilities.supportsOS26Translucency {
            GlassEffectContainer {
                var glassDecorated = decorated
                    .glassEffect(.regular.interactive(), in: capsule)

                if let namespace, let glassID {
                    glassDecorated = glassDecorated.glassEffectID(glassID, in: namespace)
                }

                if let transition = transitionStorage as? GlassEffectTransition {
                    glassDecorated = glassDecorated.glassEffectTransition(transition)
                }

                glassDecorated
            }
        } else {
            decorated
        }
    }
}
