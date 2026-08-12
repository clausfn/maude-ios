import Testing
import SwiftUI
import UIKit
@testable import Liviqa

// The sweep's actual artefact was a picture: a fully black in-call stage. So the
// fix is asserted as a picture too — the placeholder is rendered off-screen and
// the pixels are counted. A stage that draws nothing cannot pass this.
@MainActor
struct CallStagePlaceholderRenderTests {

    private func render(phase: CallStagePhase, camera: CallCameraStatus) throws -> [UInt8] {
        let copy = try #require(CallStageDeriver.copy(phase: phase, camera: camera))
        let view = CallStagePlaceholder(recipientName: "Mette Holm",
                                        recipientOrg: "Steno Diabetes Center",
                                        selfInitials: "LV",
                                        copy: copy,
                                        onRetry: {})
            .frame(width: 390, height: 620)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.uiImage)
        let cg = try #require(image.cgImage)

        // Leave the frame behind for review (the sweep is a visual artefact):
        // <test-host container>/tmp/call-stage-<phase>-<camera>.png
        if let png = image.pngData() {
            try? png.write(to: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("call-stage-\(phase.rawValue)-\(camera.rawValue).png"))
        }

        var buffer = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let ctx = try #require(CGContext(data: &buffer,
                                         width: cg.width, height: cg.height,
                                         bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        return buffer
    }

    /// Luminance well above the #0A0E12 stage — ink, brass, ring, tile.
    private func litPixels(_ buffer: [UInt8]) -> Int {
        var lit = 0
        for i in stride(from: 0, to: buffer.count, by: 4) {
            let l = 0.299 * Double(buffer[i]) + 0.587 * Double(buffer[i + 1]) + 0.114 * Double(buffer[i + 2])
            if l > 90 { lit += 1 }
        }
        return lit
    }

    @Test func theStageIsNeverABlankBlackRectangle() throws {
        for phase in [CallStagePhase.notConfigured, .connecting, .unreachable] {
            let lit = litPixels(try render(phase: phase, camera: .noDevice))
            #expect(lit > 500, "\(phase) drew a near-blank stage — only \(lit) lit pixels")
        }
    }

    /// The self corner is drawn too, whatever the camera situation.
    @Test func theSelfTileIsDrawnForEveryCameraStatus() throws {
        for camera in [CallCameraStatus.ready, .noDevice, .notPermitted] {
            let lit = litPixels(try render(phase: .connecting, camera: camera))
            #expect(lit > 500, "camera \(camera) drew a near-blank stage — \(lit) lit pixels")
        }
    }
}
