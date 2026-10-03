---
name: debug-crash
description: Reproduce and fix System Pulse runtime crashes, hangs or SwiftUI/AppKit lifecycle warnings using crash evidence, actor ownership and native-resource checks.
---

# Debug a crash

Read [AGENTS.md](../../../AGENTS.md) and the relevant sections of
[architecture](../../../docs/architecture.md) and
[concurrency](../../../docs/concurrency.md).

## Establish evidence

Gather the action sequence, crash/warning text, macOS/hardware, build configuration
and whether the app was sandboxed. Use supplied logs first. Inspect relevant local
DiagnosticReports or reproduce in an isolated development build if needed; avoid
copying unrelated report contents. For a hang, collect thread stacks during the
hang rather than treating an earlier warning as its cause.

Identify the exception/termination reason, crashed thread and first relevant app
frames. Symbolicate with the matching binary/dSYM when required. A warning is a
clue, not proof of a crash cause. If a report or reproduction step is essential
and missing, request it and continue independent source investigation.

## Trace likely ownership failures

| Evidence or trigger | Inspect |
| --- | --- |
| Popover open/close, hosting-view release or SwiftUI commit | `ProcessDetailsPopover.Coordinator`: pending-update cancellation, anchor window, invalidation/closing flags and deferred host/binding cleanup. |
| Launch/status-item setup | Deferred status-button configuration in `installMenuBarItem`; remote-scene readiness and weak captures. |
| Geometry/layout recursion | `ContentView` geometry reporting and `schedulePanelResize`; avoid synchronous sizing during hosting-view attachment. |
| Sleep/wake or display movement | Wake work cancellation, placement state, stable attempts and screen UUID handling in the panel controller. |
| Timer/state isolation | Idempotent start/stop, interval replacement and main-run-loop assumptions; `assumeIsolated` does not hop actors. |
| Native sampling / memory access | Buffer byte counts, return values, pointer lifetimes, Mach deallocation, IOKit release and `freeifaddrs`. |
| Arithmetic / conversion trap | Unsigned counter deltas, counter reset/wrap, elapsed uptime, byte conversions and process identity changes. |

Empty process data under App Sandbox may be an access limitation rather than a
crash. Inspect return values and `errno` where the API defines it, and validate
actual helper processes before drawing conclusions. Keep metric correctness and
memory safety as separate questions.

## Fix and verify

Make a focused fix to the demonstrated ownership, ordering or arithmetic problem.
Preserve delayed native presentation/cleanup and cancellation guards. Do not
suppress warnings, disable sandboxing or silence actor checking as a substitute
for explaining the failure. Use Main Thread Checker, Thread Sanitizer or memory
diagnostics when their failure class fits the evidence.

Follow [testing](../../../docs/testing.md): build, repeat the original failure
sequence, then exercise neighboring lifecycle transitions. Add a deterministic
regression test when the failure can be isolated meaningfully; no test target is
currently configured. Distinguish confirmed cause and verified fix from remaining
hypotheses. Include the reproduction and actual validation in the handoff; if the
crash cannot be reproduced, state the limits of the proposed fix.
