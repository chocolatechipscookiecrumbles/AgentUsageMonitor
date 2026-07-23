import XCTest
@testable import CodexUsageMonitor

/// Guards the defect AGENTS.md records twice now: a fixed-width trailing
/// control that exceeds the page's width budget pushes the whole card past
/// the trailing edge, leaving a leading gutter and none on the right.
final class SettingsWidthBudgetTests: XCTestCase {
    /// The default hidden-rail Settings width. Below compactWidthBreakpoint,
    /// so compact metrics apply — the case that actually shipped broken.
    private let defaultPageWidth: CGFloat = 499

    func testCompactBudgetMatchesTheDocumentedArithmetic() {
        // 499 - 32 page - 28 section - 168 leading - 36 spacing = 235
        XCTAssertEqual(
            SettingsLayoutMetrics.trailingControlBudget(pageWidth: defaultPageWidth, layout: .compact),
            235
        )
    }

    func testRegularLayoutUsesItsOwnPagePadding() {
        // Regular padding is 20 a side rather than 16, so the budget is 8 less.
        XCTAssertEqual(
            SettingsLayoutMetrics.trailingControlBudget(pageWidth: defaultPageWidth, layout: .regular),
            227
        )
    }

    func testBudgetNeverGoesNegativeOnAVeryNarrowPage() {
        XCTAssertEqual(
            SettingsLayoutMetrics.trailingControlBudget(pageWidth: 100, layout: .compact),
            0,
            "a negative budget would silently read as 'fits'"
        )
    }

    func testWiderPageYieldsMoreBudget() {
        let narrow = SettingsLayoutMetrics.trailingControlBudget(pageWidth: 499, layout: .compact)
        let wide = SettingsLayoutMetrics.trailingControlBudget(pageWidth: 700, layout: .compact)
        XCTAssertEqual(wide - narrow, 201)
    }
}
