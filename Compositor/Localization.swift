import Foundation

/// Looks up keys that are chosen at runtime (for example enum-backed picker values).
/// SwiftUI localizes literal labels automatically, but it cannot extract a value such as
/// `filter.rawValue` as a localization key at compile time.
nonisolated func localizedString(_ key: String, bundle: Bundle = .main) -> String {
    bundle.localizedString(forKey: key, value: key, table: "Localizable")
}

nonisolated extension RawRepresentable where RawValue == String {
    var localizedName: String { localizedString(rawValue) }
}

/// History entries normally use a fixed key. Adjustment entries include the adjustment
/// kind in the key, so rebuild those two formatted forms after translating the kind.
nonisolated func localizedHistoryAction(_ name: String, bundle: Bundle = .main) -> String {
    let suffix = " Adjustment"
    if name.hasPrefix("Edit "), name.hasSuffix(suffix) {
        let start = name.index(name.startIndex, offsetBy: 5)
        let end = name.index(name.endIndex, offsetBy: -suffix.count)
        return String(format: localizedString("Edit %@ Adjustment", bundle: bundle),
                      localizedString(String(name[start..<end]), bundle: bundle))
    }
    if name.hasPrefix("New "), name.hasSuffix(suffix) {
        let start = name.index(name.startIndex, offsetBy: 4)
        let end = name.index(name.endIndex, offsetBy: -suffix.count)
        return String(format: localizedString("New %@ Adjustment", bundle: bundle),
                      localizedString(String(name[start..<end]), bundle: bundle))
    }
    return localizedString(name, bundle: bundle)
}
