import AppKit
import Testing
@testable import UzbekKeyboardMac

@Suite struct IconTests {
    @Test func appIconHasTheSizesFinderAndTheDockUse() throws {
        let icon = try #require(NSImage(data: try Icon.icns(sizes: Icon.appSizes)))
        let widths = Set(icon.representations.map(\.pixelsWide))
        #expect(widths.isSuperset(of: [16, 32, 128, 256, 512, 1024]))
    }
}
