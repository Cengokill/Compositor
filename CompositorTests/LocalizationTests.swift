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

    @Test func persistedEnumRawValuesStayEnglish() {
        #expect(LayerBlendMode.multiply.rawValue == "Multiply")
        #expect(LayerBlendMode.colorDodge.rawValue == "Color Dodge")
        #expect(FilterKind.gaussianBlur.rawValue == "Gaussian Blur")
        #expect(AdjustmentKind.hsv.rawValue == "Hue/Saturation")
    }
}
