# Agent guide

## Project

System Pulse is a native macOS menu-bar resource monitor. The Xcode project and
scheme are named `NewTopUI`; the built product is `System Pulse.app`. It uses
SwiftUI, AppKit, Observation, Darwin/Mach, and IOKit. There is no HTTP server,
database, or web frontend in this repository.

Read [architecture](docs/architecture.md) before changing component boundaries,
[testing](docs/testing.md) before validation, and [concurrency](docs/concurrency.md)
before changing sampling, callbacks, or AppKit presentation.

## Code map

| Responsibility | Location |
| --- | --- |
| Entry point, status item, floating panel, placement and wake restoration | `NewTopUI/NewTopUI/NewTopUIApp.swift` |
| Dashboard, cards, graphs, formatting and process detail content | `NewTopUI/NewTopUI/ContentView.swift` |
| Observable model, timer, bounded histories and metric types | `NewTopUI/NewTopUI/Models/SystemMetrics.swift` |
| Stateful system counter sampling | `NewTopUI/NewTopUI/Services/SystemMetricsReader.swift` |
| Deferred native process popover presentation and teardown | `NewTopUI/NewTopUI/ProcessDetailsPopover.swift` |
| English source strings and French/Spanish translations | `NewTopUI/NewTopUI/Localizable.xcstrings` |
| Localized bundle metadata | `NewTopUI/NewTopUI/InfoPlist.xcstrings` |

## Coding conventions

- Define extracted or logically distinct SwiftUI views as separate `View` structs.
  Do not implement subviews as computed properties returning `some View`; `body`
  is the normal exception. Computed data properties are fine.
- Put private helper methods and enums in private extensions. Keep protocol
  requirements and overrides where their visibility requires them.
- Localize user-visible strings, tooltips, and accessibility labels. Add French
  and Spanish translations with compatible interpolation placeholders to the
  string catalogs. Preserve English as the source language.
- Use locale-aware formatting for percentages, counts, dates, durations and byte
  quantities. Percent styles consume fractions: `1.0` represents 100%.
- Follow `.swiftformat`: Swift 6 language mode, four-space indentation and LF
  line endings. Format touched Swift files rather than unrelated files.
- Add app source under `NewTopUI/NewTopUI/`. Xcode uses a filesystem-synchronized
  group, so ordinary new Swift files do not need manual build-phase entries.

## Behavioral invariants

- Sampling starts when the panel is shown and stops when it is hidden or the app
  terminates. Keep `start()` idempotent and invalidate replaced timers.
- The app target defaults to `MainActor` isolation. UI and observable state stay
  on the main actor; the reader has mutable baselines and must not sample in
  parallel. See the concurrency guide before moving work off the main actor.
- Convert process CPU Mach ticks with `mach_timebase_info` for both instantaneous
  usage and cumulative seconds. Process CPU can exceed 100% across cores; clamp
  only visual bar widths. The overall CPU average uses per-core fractions.
- Measure elapsed sampling time with system uptime, not the chosen timer interval
  or wall-clock dates. Counter resets must not create unsigned underflow spikes.
- Process enumeration is best effort under App Sandbox. Include only readable
  descendants and distinguish denied access from an actually empty process tree.
  Do not disable the sandbox to make a metric appear to work.
- Preserve native popover background continuity with its arrow and the deferred
  show/close/cleanup lifecycle in `ProcessDetailsPopover`.
- Keep histories bounded and hardware-dependent GPU absence representable as
  `nil`. Do not silently relabel unavailable readings as measured zero.
- Preserve panel placement, compact mode, display-change and wake handling when
  changing layout or lifecycle code.

## Task skills

The requested skills live in `.agent/skills/`. Read the relevant `SKILL.md`
explicitly; their presence here does not assume automatic discovery by every
agent runner.

- [add-feature](.agent/skills/add-feature/SKILL.md): implement a feature across
  existing app layers.
- [add-api-endpoint](.agent/skills/add-api-endpoint/SKILL.md): distinguish native
  API integration, HTTP client work and an explicitly requested server endpoint.
- [add-swiftui-screen](.agent/skills/add-swiftui-screen/SKILL.md): add a panel,
  screen, card or detail view using the current presentation model.
- [debug-crash](.agent/skills/debug-crash/SKILL.md): reproduce and diagnose a
  runtime failure, especially lifecycle and native API failures.

## Validation and handoff

Use the commands and relevant manual checks in [testing](docs/testing.md). There
are currently no automated test targets; do not report a build as passing tests
or proof of runtime behavior. Documentation-only edits need link, structure and
whitespace checks, without an app rebuild.

Keep changes scoped to the request and preserve existing local edits. Report
what changed, which checks actually ran, and any behavior that remains unverified.
Update these guides when a change makes their architecture or commands inaccurate.
