import AppKit
import Testing
@testable import Compositor

@MainActor
struct BrushBlendTests {
    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [Int] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let index = (y * image.width + x) * 4
        return (0..<4).map { Int(bytes[index + $0]) }
    }

    /// Opaque red, with a green pixel the dab must not reach, and a 50% red field when requested.
    private func session(partial: Bool) throws -> EditorSession {
        let session = EditorSession()
        session.createDocument(width: 80, height: 80)
        session.addBlankLayer()
        session.selectTool(.brush)
        let context = try BrushRaster.context(width: 80, height: 80, mask: false)
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: partial ? 0.5 : 1))
        context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 2, y: 2, width: 4, height: 4))
        let image = try #require(context.makeImage())
        let layer = try #require(session.activeLayer)
        session.document?.layers[0] = ImageLayer(id: layer.id, asset: ImportedImage(image: image, thumbnail: image, name: "Base"),
            name: layer.name, isVisible: true, transform: layer.transform)
        return session
    }

    private func stroke(_ session: EditorSession, mode: BrushBlendMode, opacity: CGFloat) async throws -> CGImage {
        session.brushSettings = BrushSettings(diameter: 16, hardness: 1, red: 0, green: 0, blue: 1, opacity: opacity, blendMode: mode)
        session.beginBrush(at: CGPoint(x: 40, y: 40))
        await session.finishBrush()
        #expect(session.brushError == nil)
        #expect(session.activeLayer?.blendMode == .normal)
        return try await ImageExporter.shared.render(try #require(session.projectSnapshot())).image
    }

    private func close(_ pixel: [Int], _ expected: [Int], _ label: String) {
        for channel in 0..<4 {
            #expect(abs(pixel[channel] - expected[channel]) <= 2, "\(label) channel \(channel): \(pixel) vs \(expected)")
        }
    }

    @Test func normalSourceOverKeepsUntouchedPixelsAndTheLayerMode() async throws {
        let opaque = try await stroke(try session(partial: false), mode: .layer(.normal), opacity: 0.5)
        close(try pixel(opaque, x: 40, y: 40), [128, 0, 128, 255], "normal over opaque")
        close(try pixel(opaque, x: 3, y: 3), [0, 255, 0, 255], "untouched")
        let partial = try await stroke(try session(partial: true), mode: .layer(.normal), opacity: 0.5)
        // 50% blue over 50% red: alpha 0.75, premul red 0.25, premul blue 0.5.
        close(try pixel(partial, x: 40, y: 40), [64, 0, 128, 191], "normal over partial")
        close(try pixel(partial, x: 3, y: 3), [0, 255, 0, 255], "untouched partial")
    }

    @Test func replaceWritesBrushColorAndAlphaWithoutMixingRGB() async throws {
        let opaque = try await stroke(try session(partial: false), mode: .replace, opacity: 0.5)
        close(try pixel(opaque, x: 40, y: 40), [0, 0, 128, 128], "replace over opaque")
        close(try pixel(opaque, x: 3, y: 3), [0, 255, 0, 255], "untouched replace")
        let partial = try await stroke(try session(partial: true), mode: .replace, opacity: 0.5)
        close(try pixel(partial, x: 40, y: 40), [0, 0, 128, 128], "replace over partial")
    }

    @Test func negationMixesTheFormulaByCoverage() async throws {
        let opaque = try await stroke(try session(partial: false), mode: .negation, opacity: 1)
        // 1 - abs(1 - red - blue) = magenta.
        close(try pixel(opaque, x: 40, y: 40), [255, 0, 255, 255], "negation opaque")
        close(try pixel(opaque, x: 3, y: 3), [0, 255, 0, 255], "untouched negation")
        let half = try await stroke(try session(partial: false), mode: .negation, opacity: 0.5)
        close(try pixel(half, x: 40, y: 40), [255, 0, 128, 255], "negation half opacity")
        let partial = try await stroke(try session(partial: true), mode: .negation, opacity: 0.5)
        // Straight mix is (1, 0, 0.5) at alpha 0.75.
        close(try pixel(partial, x: 40, y: 40), [191, 0, 96, 191], "negation over partial")
        let clear = EditorSession()
        clear.createDocument(width: 80, height: 80)
        clear.addBlankLayer()
        clear.selectTool(.brush)
        clear.brushSettings = BrushSettings(diameter: 16, hardness: 1, red: 0, green: 0, blue: 1, blendMode: .negation)
        clear.beginBrush(at: CGPoint(x: 40, y: 40))
        await clear.finishBrush()
        let empty = try await ImageExporter.shared.render(try #require(clear.projectSnapshot())).image
        close(try pixel(empty, x: 40, y: 40), [0, 0, 255, 255], "negation on empty")
        #expect(try pixel(empty, x: 3, y: 3)[3] == 0)
    }

    @Test func multiplyAndLinearBurnMatchLayerCompositing() async throws {
        let context = try BrushRaster.context(width: 80, height: 80, mask: false)
        context.setFillColor(CGColor(srgbRed: 0.8, green: 0.4, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        let base = try #require(context.makeImage())
        let brush = CGColor(srgbRed: 0.2, green: 0.6, blue: 1, alpha: 1)
        for mode in [LayerBlendMode.multiply, .linearBurn] {
            let session = EditorSession()
            session.createDocument(width: 80, height: 80)
            session.addBlankLayer()
            session.selectTool(.brush)
            let layer = try #require(session.activeLayer)
            session.document?.layers[0] = ImageLayer(id: layer.id, asset: ImportedImage(image: base, thumbnail: base, name: "Base"),
                name: layer.name, isVisible: true, transform: layer.transform)
            session.brushSettings = BrushSettings(diameter: 16, hardness: 1, red: 0.2, green: 0.6, blue: 1, blendMode: .layer(mode))
            session.beginBrush(at: CGPoint(x: 40, y: 40))
            await session.finishBrush()
            let painted = try await ImageExporter.shared.render(try #require(session.projectSnapshot())).image
            let reference = try composite(mode, base: base, color: brush)
            close(try pixel(painted, x: 40, y: 40), try pixel(reference, x: 40, y: 40), mode.rawValue)
            close(try pixel(painted, x: 3, y: 3), try pixel(base, x: 3, y: 3), "\(mode.rawValue) outside")
        }
    }

    private func composite(_ mode: LayerBlendMode, base: CGImage, color: CGColor) throws -> CGImage {
        let context = try BrushRaster.context(width: base.width, height: base.height, mask: false)
        let bounds = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        BrushRaster.draw(base, in: bounds, mask: false, context: context)
        let paint = { (surface: CGContext) in
            surface.setFillColor(color)
            surface.fill(bounds)
        }
        if SeparableBlend.needsSurface(mode) {
            #expect(SeparableBlend.draw(mode, in: context, body: paint))
        } else {
            context.setBlendMode(mode.cgMode)
            paint(context)
        }
        return try #require(context.makeImage())
    }

    @Test func replaceAndNegationStayOutOfTheLayerMenu() {
        let layerTitles = LayerBlendMode.groups.map { $0.map(\.rawValue) }
        #expect(BrushBlendMode.groups.dropLast().map { $0.map(\.title) } == layerTitles)
        #expect(BrushBlendMode.groups.last?.map(\.title) == ["Replace", "Negation"])
        let names = LayerBlendMode.allCases.map(\.rawValue)
        #expect(LayerBlendMode.groups.flatMap { $0 }.map(\.rawValue) == names)
        #expect(!names.contains("Replace") && !names.contains("Negation"))
        #expect(BrushSettings().blendMode == .layer(.normal))
    }
}
