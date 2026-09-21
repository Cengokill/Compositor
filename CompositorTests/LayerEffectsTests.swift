import AppKit
import Testing
@testable import Compositor

@MainActor
struct LayerEffectsTests {
    private func sessionWithImage() throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 4, height: 4)
        session.insert(try LiveMaskTests().asset([255, 255, 255, 255]))
        return session
    }

    @Test func effectEditsRecordEnglishHistoryNames() throws {
        let session = try sessionWithImage()
        let source = try #require(session.activeLayerID)
        session.addEffect(.shadow)
        #expect(session.history.undoName == "Add Drop Shadow")
        session.changeEffects { $0.shadow?.distance = 30 }
        #expect(session.history.undoName == "Edit Drop Shadow")
        session.finishEffectsEditing(commit: true)
        session.toggleEffect(.shadow, on: source)
        #expect(session.history.undoName == "Hide Drop Shadow")
        session.toggleEffect(.shadow, on: source)
        #expect(session.history.undoName == "Show Drop Shadow")

        session.insert(try LiveMaskTests().asset([255, 0, 0, 255], color: 0))
        let target = try #require(session.activeLayerID)
        session.copyEffect(.shadow, from: source, to: target)
        #expect(session.history.undoName == "Copy Drop Shadow")
        #expect(session.document?.layers.first { $0.id == target }?.effects?.shadow != nil)

        session.addEffect(.stroke)
        session.finishEffectsEditing(commit: false)
        #expect(session.history.undoName == "Cancel Stroke")
        #expect(session.activeLayer?.effects?.stroke == nil)

        session.addEffect(.colorOverlay)
        session.finishEffectsEditing(commit: true)
        session.selectEffect(.colorOverlay, on: target)
        session.removeSelectedEffect()
        #expect(session.history.undoName == "Remove Color Overlay")
        #expect(session.activeLayer?.effects?.colorOverlay == nil)
    }
}
