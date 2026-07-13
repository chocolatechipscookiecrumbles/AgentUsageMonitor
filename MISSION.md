# Mission: Edit the Codex Usage Monitor UI independently

## Why
Build enough practical SwiftUI fluency to change the Codex Usage Monitor's menu-bar interface and separate Settings window directly, while preserving its working state, notification behavior, and native macOS conventions.

## Success looks like
- Identify the source file responsible for any visible menu-bar or Settings element.
- Make copy, spacing, control, section, icon, and window-layout changes without accidentally changing application behavior.
- Build, relaunch, visually inspect, and revise a UI change independently.
- Recognize when a change affects native menu semantics, persisted settings, or documentation.

## Constraints
- Learn through small edits in the actual repository.
- Keep the current native inline menu presentation unless a panel-style redesign is intentional.
- Do not add or run automated test cases for the current project work.
- Document user-visible behavior changes in the README, how-to, and relevant plan.

## Out of scope
- Rewriting the quota collector or notification engine.
- Learning every Swift or SwiftUI feature before making useful UI changes.
- Implementing the future dashboard design in the first lesson.
