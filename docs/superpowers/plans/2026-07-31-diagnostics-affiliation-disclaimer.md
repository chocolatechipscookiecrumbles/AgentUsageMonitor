# Diagnostics affiliation disclaimer implementation plan

**Status:** Planned; no Swift implementation is authorized by the public-repository
readiness change.

**Goal:** Add this exact independent-project notice to Diagnostics:

> AgentUsageMonitor is an independent project and is not affiliated with, endorsed
> by, or supported by OpenAI, Anthropic, GitHub, or Apple. Provider names and marks
> belong to their respective owners.

## Scope and ownership

- Place the notice in the existing Diagnostics Settings destination. Do not add a
  second Settings navigation owner or a new window.
- Use the shared `SettingsPage`, `SettingsSection`, `SettingsSectionRow`, and
  wrapping text components and metrics already required by `AGENTS.md`.
- Treat this as informational copy. It must not imply support, certification,
  provider ownership, or a change to the MIT licence.
- Use `swiftui-pro` and `writing-for-interfaces` before implementation. Use
  `figma-to-swiftui` only if an approved Figma node is supplied for this change.

## Acceptance

- Build and inspect the signed `.app`; a raw SwiftPM executable is not visual
  acceptance.
- Inspect Diagnostics at the default 680 × 560-point Settings content size in
  Light and Dark appearance with the Context Rail both hidden and visible.
- Confirm the complete notice wraps without clipping, truncation, a widened card,
  or content hidden below the viewport.
- Confirm the notice remains reachable by keyboard and is announced coherently by
  VoiceOver.
- Preserve the selected destination, search query, scroll position, preview state,
  and focus across appearance changes.
- Record any state not directly exercised as unverified.

## Non-goals

- No Swift, signing, entitlement, bundle-identifier, or provider-connection change
  belongs to the repository-publication work.
- Do not substitute a screenshot, README-only statement, or hidden accessibility
  label for the visible Diagnostics notice.
