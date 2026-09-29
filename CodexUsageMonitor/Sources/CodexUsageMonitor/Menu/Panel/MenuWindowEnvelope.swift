import CoreGraphics

/// The menu panel's height policy (ADR 0004). The window is never smaller than
/// committed content: it grows before a commit and shrinks only after the live
/// surface settles. A pre-measurement that proves too small grows late; the
/// caller logs it as a measurement bug.
struct MenuWindowEnvelope: Equatable {
    var cap: CGFloat
    private(set) var windowHeight: CGFloat = 0
    private(set) var committedContentHeight: CGFloat = 0
    /// Advanced by every `prepare`. A shrink proposed under an older generation
    /// would undercut content committed since, so it is dropped.
    private(set) var generation = 0
    static let tolerance: CGFloat = 0.5

    init(cap: CGFloat) {
        self.cap = cap
    }

    enum Settlement: Equatable {
        case unchanged
        /// Apply on the next run-loop turn through `applyShrink`.
        case shrink(to: CGFloat, generation: Int)
        /// Apply now; the pre-measured height was too small.
        case lateGrow(to: CGFloat, premeasured: CGFloat)
    }

    /// Call before publishing new content. Returns a height to apply first.
    mutating func prepare(committing premeasured: CGFloat) -> CGFloat? {
        generation += 1
        committedContentHeight = min(premeasured, cap)
        guard committedContentHeight > windowHeight + Self.tolerance else { return nil }
        windowHeight = committedContentHeight
        return windowHeight
    }

    /// Call with the live surface height once SwiftUI has laid it out.
    mutating func settle(measured: CGFloat) -> Settlement {
        let height = min(measured, cap)
        if height > windowHeight + Self.tolerance {
            let premeasured = committedContentHeight
            windowHeight = height
            committedContentHeight = height
            return .lateGrow(to: height, premeasured: premeasured)
        }
        committedContentHeight = height
        guard height < windowHeight - Self.tolerance else { return .unchanged }
        return .shrink(to: height, generation: generation)
    }

    /// Returns false, leaving the window unchanged, when newer content was
    /// prepared after this shrink was proposed.
    mutating func applyShrink(to height: CGFloat, generation proposed: Int) -> Bool {
        guard proposed == generation,
              height >= committedContentHeight - Self.tolerance else { return false }
        windowHeight = height
        return true
    }

    /// The screen budget changed; the window may not exceed the new cap.
    mutating func updateCap(_ newCap: CGFloat) -> CGFloat? {
        cap = newCap
        committedContentHeight = min(committedContentHeight, newCap)
        guard windowHeight > newCap + Self.tolerance else { return nil }
        windowHeight = newCap
        return newCap
    }
}
