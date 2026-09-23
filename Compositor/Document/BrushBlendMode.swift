import Foundation

/// How a brush stroke combines with the pixels already on the layer.
/// Layer modes reuse `LayerBlendMode`; Replace and Negation exist only on the brush.
nonisolated enum BrushBlendMode: Hashable, Sendable {
    case layer(LayerBlendMode)
    case replace
    case negation

    /// Same sections as the Layers menu, then the brush-only modes.
    static let groups: [[BrushBlendMode]] = LayerBlendMode.groups.map { $0.map(BrushBlendMode.layer) } + [[.replace, .negation]]

    var title: String {
        switch self {
        case .layer(let mode): mode.rawValue
        case .replace: "Replace"
        case .negation: "Negation"
        }
    }

    init?(title: String) {
        switch title {
        case "Replace": self = .replace
        case "Negation": self = .negation
        default:
            guard let mode = LayerBlendMode(rawValue: title) else { return nil }
            self = .layer(mode)
        }
    }
}
