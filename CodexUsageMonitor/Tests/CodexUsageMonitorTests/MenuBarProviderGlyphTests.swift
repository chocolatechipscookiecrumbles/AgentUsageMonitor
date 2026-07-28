import CoreGraphics
import XCTest
@testable import CodexUsageMonitor

/// Regression coverage for the Codex menu-bar glyph rendering as a solid block.
///
/// `MenuBarLabelView` draws the provider glyph with `.renderingMode(.template)`,
/// which paints *every* non-transparent pixel with the tint. The menu bar used
/// `AgentProvider.settingsAssetName`, whose Codex artwork (`codex-color.pdf`) is
/// a full-bleed opaque square — a blue mark on white, not a transparent glyph.
/// Templating it produced a filled block in the menu bar and in the General
/// page's Menu Bar Preview card.
///
/// This reads the artwork the *menu bar* names, so any future substitution of
/// opaque artwork fails here rather than in the menu bar.
final class MenuBarProviderGlyphTests: XCTestCase {
    /// Rendered resolution for the alpha probe. Small enough to stay fast,
    /// large enough that the `>_` knockout survives rasterization.
    private let resolution = 64

    /// The defect asset measures 97% opaque at this resolution (a square with
    /// antialiased corners); the three shipped glyphs measure well under 60%.
    private let maximumOpaqueCoverage = 0.90

    func testMenuBarGlyphsAreNotFullyOpaque() throws {
        for provider in AgentProvider.allCases {
            let alpha = try alphaMask(for: provider)
            let coverage = Double(alpha.filter { $0 }.count) / Double(alpha.count)
            XCTAssertLessThan(
                coverage,
                maximumOpaqueCoverage,
                "\(provider.menuBarAssetName) is \(Int(coverage * 100))% opaque; template rendering would paint it as a solid block"
            )
        }
    }

    // MARK: Probing

    /// Renders the imageset's PDF over a cleared context and returns one
    /// `isOpaque` flag per pixel, row-major from the top.
    private func alphaMask(for provider: AgentProvider) throws -> [Bool] {
        let url = try artworkURL(for: provider.menuBarAssetName)
        let document = try XCTUnwrap(
            CGPDFDocument(url as CFURL),
            "\(url.lastPathComponent) is not a readable PDF"
        )
        let page = try XCTUnwrap(document.page(at: 1), "\(url.lastPathComponent) has no first page")
        let box = page.getBoxRect(.cropBox)
        XCTAssertGreaterThan(box.width, 0)
        XCTAssertGreaterThan(box.height, 0)

        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: resolution,
                height: resolution,
                bitsPerComponent: 8,
                bytesPerRow: resolution * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.clear(CGRect(x: 0, y: 0, width: resolution, height: resolution))
        context.scaleBy(x: CGFloat(resolution) / box.width, y: CGFloat(resolution) / box.height)
        context.translateBy(x: -box.origin.x, y: -box.origin.y)
        context.drawPDFPage(page)

        let pixels = try XCTUnwrap(context.data).bindMemory(
            to: UInt8.self,
            capacity: resolution * resolution * 4
        )
        return (0 ..< resolution * resolution).map { pixels[$0 * 4 + 3] > 127 }
    }

    /// Resolves an imageset's artwork from the repository asset catalog. The
    /// catalog is compiled into the `.app` by `Scripts/build-app.sh` rather than
    /// declared as a SwiftPM resource, so there is no test bundle to read it
    /// from; locate it relative to this source file instead.
    private func artworkURL(for assetName: String) throws -> URL {
        let imageset = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CodexUsageMonitorTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // CodexUsageMonitor
            .appendingPathComponent("Resources/Assets.xcassets/\(assetName).imageset")

        let contents = try Data(contentsOf: imageset.appendingPathComponent("Contents.json"))
        let decoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: contents) as? [String: Any],
            "\(assetName).imageset has an unreadable Contents.json"
        )
        let images = decoded["images"] as? [[String: Any]] ?? []
        let filename = try XCTUnwrap(
            images.compactMap { $0["filename"] as? String }.first,
            "\(assetName).imageset names no artwork file"
        )
        return imageset.appendingPathComponent(filename)
    }
}
