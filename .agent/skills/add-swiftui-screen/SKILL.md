---
name: add-swiftui-screen
description: Add or modify a System Pulse SwiftUI screen, metric card or detail view within its AppKit-hosted macOS panel and popover conventions.
---

# Add a SwiftUI screen

Read [AGENTS.md](../../../AGENTS.md),
[architecture](../../../docs/architecture.md) and the adjacent view structs in
`ContentView.swift`. The visible interface lives in an AppKit-owned floating
panel; the app's Settings scene is empty.

## Presentation and state

- Determine whether the requested view belongs in the dashboard, a detail
  popover, Settings or a new window. Follow requested navigation; adding a screen
  does not automatically call for a `NavigationStack` or `WindowGroup`.
- Use separate `View` structs for extracted UI. Share card/header patterns where
  they fit; a larger independent screen can have its own file under the app group.
- Pass observed model or value snapshots into views. Use `@State` for transient
  selection/presentation, `@Binding` for shared editing and `@AppStorage` only
  when persistence is intended. Keep OS sampling out of `body` and view helpers.
- Route native window creation/lifecycle through the panel controller or a
  dedicated bridge. Process details use `ProcessDetailsPopover`; inspect its
  coordinator before changing show, dismissal or host lifetime. Let the native
  popover draw a continuous body/arrow surface.
- Preserve the 420-point dashboard and compact scaling behavior where applicable.
  Notify panel sizing through `onSizeChange` and the deferred resize path. Place
  scroll-view content padding inside the scroll view when the scrollbar should
  remain at the outer edge.
- Include empty, unavailable and stale states that the actual model can produce.
  Prefer stable identities for lists and selection; process details currently
  resolve the latest snapshot by PID and retain a labeled stale fallback.

## Resources and checks

Localize titles, buttons, help text and accessibility labels with English source
strings and French/Spanish translations. Preserve placeholder types/order and use
locale-aware numeric formats. Add descriptive labels to icon-only controls and
support appropriate dismissal, including Escape for process details.

Follow [testing](../../../docs/testing.md): build, inspect full/compact size and
light/dark appearance, check affected locales, and exercise presentation/dismissal
while samples refresh. If sizing or native presentation changes, read
[concurrency](../../../docs/concurrency.md) and check repeated interaction for
transaction warnings or reentrancy. Report visual/runtime checks separately from
compilation, including anything unavailable for verification.
