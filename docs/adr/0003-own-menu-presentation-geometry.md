# Own menu presentation geometry

Status: Rejected (2026-09-28). The user reported that neither trial fixed the defect and both recreated the provider-switch artifact. Superseded by the [content-fitted menu panel plan](../superpowers/plans/2026-09-29-content-fitted-menu-panel.md); ADR 0004 is to be written from it.

**Why it failed:** the constraint "resizes to content immediately" with no transparent tail reintroduced the host resize that the July diagnosis identified as the cause. Both hosts resized after measuring, a run-loop turn later, while the unanchored root was centered in the stale window. See [Trial rejection and diagnosis](../development/provider-switch-diagnostic-results.md#trial-rejection-and-diagnosis--2026-09-28). The trial code is archived on the local branch `archive/rejected-menu-trials-2026-09-28`.

The fixed native host and independently sized visible shell have produced exposed window geometry. A native layout regression also reproduced failure content expanding its scroll viewport through the header and footer. We correct that viewport allocation independently and compare an owned custom panel with a native popover, preserving the same SwiftUI content and a persistent hosting controller. The panel preserves the pointerless design; the popover delegates exterior chrome and dismissal to macOS. Neither becomes the default until signed interaction evidence and the user's comparison support the choice.

## Constraints

- The 340-point menu resizes to content immediately, anchored below its status item and capped to that screen. Only provider content scrolls.
- Provider switches start at the top; same-provider updates preserve the scroll position where possible.
- One main-actor presentation owner applies native sizes after SwiftUI measurement. No selection identity workaround or oversized transparent tail is used in either trial.
- Normal launch retains the existing MenuBarExtra host during comparison, with the corrected viewport.
- Standalone hosts invoke the actual Settings command installed by the existing SwiftUI Settings scene through public NSMenu APIs; they do not create another Settings window owner or send private selectors.
- Fixture apps use the production card renderers with synthetic values and never construct the live view model. Live apps share ordinary provider state and must be run one at a time.
