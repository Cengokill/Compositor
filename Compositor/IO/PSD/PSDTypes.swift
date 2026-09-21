import CoreGraphics
import Foundation
import UniformTypeIdentifiers

nonisolated enum PSDError: LocalizedError, Equatable {
    case truncated, unsupportedVersion, unsupportedColorMode, unsupportedDepth, unsupportedCompression
    var errorDescription: String? {
        switch self {
        case .truncated: localizedString("The Photoshop file could not be read. It may be damaged or incomplete.")
        case .unsupportedVersion: localizedString("Large Document (.psb) Photoshop files aren’t supported.")
        case .unsupportedColorMode: localizedString("Only 8-bit RGB Photoshop files can be imported.")
        case .unsupportedDepth: localizedString("Only 8-bit RGB Photoshop files can be imported.")
        case .unsupportedCompression: localizedString("This Photoshop file uses a layer compression method that isn’t supported.")
        }
    }
}

nonisolated struct PSDConversion: Identifiable, Equatable, Sendable {
    let id: UUID
    let layerName: String
    /// English sentence. Import tests match this text; the sheet shows `localizedMessage`.
    let message: String
    /// Set when `message` was built with `String(format:format, argument)`.
    var format: String? = nil
    var argument: String? = nil
    init(id: UUID = UUID(), layerName: String, message: String, argument: String? = nil) {
        self.id = id
        self.layerName = layerName
        if let argument {
            self.format = message
            self.argument = argument
            self.message = String(format: message, argument)
        } else {
            self.message = message
        }
    }

    var localizedMessage: String {
        if let format, let argument {
            return String(format: localizedString(format), argument)
        }
        return localizedString(message)
    }
}

nonisolated struct PSDDocument: @unchecked Sendable {
    var width: Int
    var height: Int
    var resolution: Double
    /// Bottom to top, including folders. Hidden section dividers are not stored.
    var layers: [PSDRecord]
}

nonisolated struct PSDRecord: @unchecked Sendable {
    var id: UUID
    var parentID: UUID?
    var name: String
    var isGroup = false
    var isVisible = true
    var opacity: Double = 1
    var blendKey = "norm"
    var clipping = false
    var bounds = CGRect.zero
    var image: CGImage?
    var mask: CGImage?
    var maskEnabled = true
    var maskLinked = true
    var adjustment: LayerAdjustment?
    var kind = PSDLayerKind.raster
    var shape: LayerShapeStyle?
    var shapeNotes: [String] = []
}

nonisolated enum PSDLayerKind: Equatable, Sendable {
    case raster, group, adjustment, text, smartObject, effects, vector, other
}

extension LayerBlendMode {
    nonisolated static func fromPSD(_ key: String) -> LayerBlendMode? {
        switch key {
        case "norm": .normal
        case "mul ": .multiply
        case "scrn": .screen
        case "over": .overlay
        case "sLit": .softLight
        case "dark": .darken
        case "lite": .lighten
        case "diff": .difference
        case "div ": .colorDodge
        case "idiv": .colorBurn
        case "hue ": .hue
        case "sat ": .saturation
        case "colr": .color
        case "lum ": .luminosity
        default: nil
        }
    }
}

extension PSDRecord {
    nonisolated var blendMode: LayerBlendMode? { LayerBlendMode.fromPSD(blendKey) }
}
