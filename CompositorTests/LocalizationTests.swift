import Foundation
import Testing
@testable import Compositor

struct LocalizationTests {
    private var catalogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Compositor/Localizable.xcstrings")
    }

    private func catalog() throws -> [String: [String: String]] {
        let data = try Data(contentsOf: catalogURL)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = try #require(root?["strings"] as? [String: Any])
        var result: [String: [String: String]] = [:]
        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else { continue }
            var byLocale: [String: String] = [:]
            for (locale, localization) in localizations {
                guard let unit = (localization as? [String: Any])?["stringUnit"] as? [String: Any],
                      let text = unit["value"] as? String else { continue }
                byLocale[locale] = text
            }
            result[key] = byLocale
        }
        return result
    }

    @Test func historyActionLocalizesAdjustmentKinds() {
        #expect(localizedHistoryAction("Edit Curves Adjustment") == String(format: localizedString("Edit %@ Adjustment"), localizedString("Curves")))
        #expect(localizedHistoryAction("New Hue/Saturation Adjustment") == String(format: localizedString("New %@ Adjustment"), localizedString("Hue/Saturation")))
        #expect(localizedHistoryAction("Transform Layer") == localizedString("Transform Layer"))
    }

    @Test func frenchCatalogCoversEveryEnglishKey() throws {
        let strings = try catalog()
        #expect(!strings.isEmpty)
        for (key, locales) in strings {
            #expect(locales["fr"] != nil, "Missing French translation for \(key)")
        }
    }

    @Test func frenchCatalogDiffersForVisibleActions() throws {
        let strings = try catalog()
        for key in ["Undo", "Brush", "Merge Down", "Multiply"] {
            let english = try #require(strings[key]?["en"] ?? key)
            let french = try #require(strings[key]?["fr"])
            #expect(french != english, "\(key) should be translated")
        }
    }

    /// Undo/Redo titles look up these English history names at runtime. A missing catalog
    /// entry leaves the Edit menu in English after a French UI action.
    @Test func frenchCatalogCoversStaticHistoryActionNames() throws {
        let strings = try catalog()
        for name in Self.staticHistoryNames {
            let french = try #require(strings[name]?["fr"], "Missing French translation for history name \(name)")
            let english = strings[name]?["en"] ?? name
            #expect(!french.isEmpty)
            if Self.historyNamesThatMustDiffer.contains(name) {
                #expect(french != english, "\(name) should be translated")
            }
        }
        for kind in AdjustmentKind.allCases {
            #expect(strings[kind.rawValue]?["fr"] != nil, "Missing French translation for \(kind.rawValue)")
        }
        for kind in FilterKind.allCases {
            #expect(strings[kind.rawValue]?["fr"] != nil, "Missing French translation for \(kind.rawValue)")
        }
    }

    @Test func persistedEnumRawValuesStayEnglish() {
        #expect(LayerBlendMode.multiply.rawValue == "Multiply")
        #expect(LayerBlendMode.colorDodge.rawValue == "Color Dodge")
        #expect(FilterKind.gaussianBlur.rawValue == "Gaussian Blur")
        #expect(AdjustmentKind.hsv.rawValue == "Hue/Saturation")
    }

    /// English identifiers stored on `DocumentHistory` and shown through `localizedHistoryAction`.
    private static let staticHistoryNames = [
        "Add Hide-All Mask", "Add Mask from Selection", "Add Reveal-All Mask", "Blur", "Brush Stroke",
        "Canvas Size", "Clear", "Clone Stamp", "Contract Selection", "Copy Layer Mask",
        "Copy Layers from Project", "Create Clipping Mask", "Crop", "Delete Layer", "Delete Layer Mask",
        "Delete Layers", "Deselect", "Disable Layer Mask", "Distort", "Distort Layer Mask", "Distort Layers",
        "Duplicate Layer", "Duplicate Layers", "Duplicate Pixels", "Elliptical Marquee", "Enable Layer Mask",
        "Erase", "Expand Selection", "Fill", "Fill Mask", "Flip Canvas Horizontal", "Flip Canvas Vertical",
        "Flip Horizontal", "Flip Vertical", "Gradient", "Gradient Mask", "Group Layers", "Hide Layer",
        "Hue/Saturation", "Image Size", "Import Image", "Import Images", "Inverse", "Invert", "Invert Mask",
        "Lasso", "Layer Blend Mode", "Layer Opacity", "Layer via Copy", "Levels", "Link Layer Mask",
        "Liquify", "Load Layer Selection", "Load Mask Selection", "Magic Wand", "Merge Down", "Merge Group",
        "Merge Layers", "Move Layer", "Move Pixels", "Move Selection", "New Blank Layer", "New Canvas",
        "New Folder", "Paint Mask", "Paste", "Polygonal Lasso", "Rectangular Marquee", "Release Clipping Mask",
        "Rename Layer", "Reorder Layers", "Replace Layer Mask", "Select All", "Show Layer", "Smudge",
        "Spot Healing", "Transform Layer", "Transform Layer Mask", "Transform Layers", "Transform Selection",
        "Unlink Layer Mask",
    ]

    /// Names whose French copy must not be a copy of the English source.
    private static let historyNamesThatMustDiffer: Set<String> = [
        "Duplicate Pixels", "Elliptical Marquee", "Gradient Mask", "Move Pixels",
        "Polygonal Lasso", "Rectangular Marquee",
    ]
}
