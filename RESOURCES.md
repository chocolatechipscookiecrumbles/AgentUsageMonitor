# Codex Usage Monitor Development Resources

## Knowledge

- [SwiftUI overview — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui)
  Apple's framework overview for views, modifiers, controls, data flow, app structure, and scenes. Use for: looking up the role of an unfamiliar SwiftUI type.
- [MenuBarExtra — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/menubarextra)
  The primary reference for native menu extras and the intentionally different window-style presentation. Use for: deciding whether content should behave like menu commands or a custom panel.
- [Settings — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/settings)
  Explains the macOS Settings scene and tabbed settings layouts. Use for: adding or reorganizing the separate Settings window.
- [OpenSettingsAction — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/opensettingsaction)
  Shows how a view opens or focuses the app's Settings scene and selects a tab. Use for: editing the **Settings…** action.
- [ViewBuilder — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/viewbuilder)
  Explains how SwiftUI turns declarative child-view statements and conditionals into view content. Use for: understanding `body`, `Group`, `if`, and `ForEach`.

### Neighboring projects

The projects below helped shape AgentUsageMonitor's ideas and supplied independent
research and comparison points. They are references, not bundled runtime
dependencies; their inclusion does not imply endorsement or direct code
contribution.

- [Token Monitor — Javis603](https://github.com/Javis603/token-monitor)
  Electron dashboard that separates local usage collection, quota probing, aggregation, synchronization, and presentation. Use for: studying broad product coverage and a watch-triggered collector pipeline.
- [Token Monitor `AGENTS.md`](https://github.com/Javis603/token-monitor/blob/main/AGENTS.md)
  Records architectural contracts, collector performance constraints, compatibility surfaces, verification commands, and PR conventions. Use for: seeing what durable coding-agent context looks like.
- [Token Monitor PR #144](https://github.com/Javis603/token-monitor/pull/144)
  Evidence-driven performance fix with a measured baseline, root cause, test-first checks, and bounded follow-up. Use for: studying a strong diagnose-to-verification change narrative.
- [Token Monitor PR #122](https://github.com/Javis603/token-monitor/pull/122)
  A multi-layer feature slice covering source metadata, normalized contracts, privacy, UI, compatibility, documentation, and review follow-ups. Use for: tracing a feature through a complete system.
- [CodexBar](https://github.com/steipete/CodexBar)
  Native Swift menu-bar reference with quota RPC, optional OAuth/web paths, local cost scanning, tests, packaging, and release automation. Use for: macOS-specific provider and menu architecture research.
- [CodexBar Codex provider notes](https://github.com/steipete/CodexBar/blob/main/docs/codex.md)
  Documents distinct quota, authentication, web, diagnostic, and local JSONL cost paths. Use for: avoiding accidental coupling between unrelated data sources.
- [CodexBar vision](https://github.com/steipete/CodexBar/blob/main/VISION.md)
  A short boundary between routine contributions and changes requiring product sign-off. Use for: constraining agent-assisted expansion.
- [Tokscale](https://github.com/junhoyeo/tokscale)
  MIT-licensed multi-agent token and cost scanner with JSON output and provider-specific source discovery. Use for: format research, coverage comparisons, and optional CLI-oracle experiments.
- [ccusage](https://github.com/ccusage/ccusage)
  MIT-licensed Rust-first local usage analyzer with Codex daily, monthly, and session reports. Use for: mature parser, fixture, pricing, and adapter patterns.
- [ccusage adapter design](https://github.com/ccusage/ccusage/blob/main/rust/crates/ccusage/src/adapter/README.md)
  Separates discovery, parsing, loading, source-local types, and shared aggregation. Use for: designing a narrow provider adapter in this project.
- [ccusage `AGENTS.md`](https://github.com/ccusage/ccusage/blob/main/AGENTS.md)
  Keeps root instructions short and routes specialized work to repo-local skills and nested guidance. Use for: scaling agent instructions without one unbounded root file.

### Repository workflows

- [Evidence-Rich Pull Requests](docs/development/evidence-rich-pull-requests.md)
  Detailed repository workflow from problem framing and branch isolation through regression proof, signed-app acceptance, review follow-up, and rollback. Use for: preparing a Draft or Ready PR whose claims can be checked.
- [Preparing Evidence-Rich PRs skill](.agents/skills/preparing-evidence-rich-prs/SKILL.md)
  Compact execution contract that routes agents to the guide and PR template. Use for: drafting, reviewing, or updating a repository pull request.

## Wisdom (Communities)

- [Apple Developer Forums: SwiftUI](https://developer.apple.com/forums/tags/swiftui)
  Apple-hosted discussions with framework engineers and platform developers. Use for: checking platform-specific behavior that is unclear from the API reference.
- [Token Monitor issues](https://github.com/Javis603/token-monitor/issues)
  Real user reports and maintainer decisions around collection, performance, privacy, and cross-platform behavior. Use for: testing assumptions against production experience.
- [ccusage discussions](https://github.com/ccusage/ccusage/discussions)
  User and contributor feedback about local usage reporting and agent sources. Use for: checking format edge cases before designing a parser.

## Gaps

- The app does not yet have Xcode previews or a dedicated visual sandbox for rapidly comparing menu and Settings variants.
- The project has no documented Codex session-log schema survey or fixture corpus for local usage analytics.
- The current no-automated-tests constraint prevents adopting the parser regression workflow used by the comparison projects; revisit it before maintaining a large log parser.
- No product decision has yet selected quota-only monitoring, a small local session pulse, or a full cost/history surface.
