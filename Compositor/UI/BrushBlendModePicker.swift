import SwiftUI
import AppKit

/// Brush blend menu. Same grouping and separators as the Layers menu, plus Replace and Negation.
struct BrushBlendModePicker: NSViewRepresentable {
    let session: EditorSession
    func makeCoordinator() -> Coordinator { Coordinator(session: session) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        for (index, group) in BrushBlendMode.groups.enumerated() {
            if index > 0 { button.menu?.addItem(.separator()) }
            for mode in group { button.addItem(withTitle: mode.title) }
        }
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.setAccessibilityLabel("Mode")
        // A capsule like the SwiftUI buttons and menus (`roundedControls`), which don't reach this AppKit pop-up.
        button.borderShape = .capsule
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        button.selectItem(withTitle: session.brushSettings.blendMode.title)
    }
    final class Coordinator: NSObject {
        let session: EditorSession
        init(session: EditorSession) { self.session = session }
        @objc func choose(_ button: NSPopUpButton) {
            guard let mode = button.selectedItem.flatMap({ BrushBlendMode(title: $0.title) }) else { return }
            session.brushSettings.blendMode = mode
        }
    }
}
