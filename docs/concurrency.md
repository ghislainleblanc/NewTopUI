# Concurrency and lifecycle

## Current execution model

The app target sets `SWIFT_VERSION = 6.0`,
`SWIFT_APPROACHABLE_CONCURRENCY = YES`, and
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in Debug and Release. App-owned types
such as `ResourceMonitorModel` and `SystemMetricsReader` therefore rely on target
defaults even without an explicit `@MainActor` annotation. Recheck isolation if
moving code into a different target or package. Observation tracks changes; it
does not independently provide synchronization.

There are no background sampling actors, detached tasks or async network requests
today. A repeating Foundation timer drives synchronous sampling on the main run
loop. `MainActor.assumeIsolated` inside its callback asserts the existing execution
context; it does not dispatch arbitrary work to the main actor.

## Sampling ownership

`ResourceMonitorModel` owns its timer and one `SystemMetricsReader`. The timer
captures the model weakly and has tolerance 0.08 seconds. `start()` returns early
when running; `stop()` invalidates the timer, clears it and marks the model stopped.
Changing `refreshInterval` calls `stop()` followed by `start()` unconditionally.
The panel controller calls these methods on show/hide and termination.

The reader mutates previous CPU ticks, process counters and parents, network
totals and timestamps. Keep `primeCounters()` and `sample()` serialized with the
same owner. Parallel reads of one reader can corrupt the interval used to calculate
deltas even if each individual OS API appears safe.

Use `ProcessInfo.processInfo.systemUptime` for rates. Wall-clock `Date` values
serve display metadata such as `sampledAt`, not elapsed rate calculation. Timer
fires can be delayed, so use measured elapsed time rather than assuming the selected
refresh interval. `stop()` leaves baselines intact; the next refresh may average
over time spent hidden. Change that policy only deliberately and validate it.

## AppKit and SwiftUI reentrancy

Main-actor execution alone does not make it safe to mutate native presentation
inside a SwiftUI update transaction. The project deliberately defers several
operations to a later turn of the main queue:

- Status-item setup waits 0.25 seconds for the remote scene to connect.
- `schedulePanelResize` cancels its previous work item and queues resizing, rather
  than synchronously measuring/resizing the hosting controller during attachment.
- Wake restoration cancels/replaces delayed work and checks restoration state,
  saved placement and stable attempts before completing.
- `ProcessDetailsPopover.updateNSView` schedules an update through its coordinator;
  it does not synchronously show/close the native popover.

The popover coordinator cancels obsolete pending updates, weakly captures its
anchor and checks `isInvalidated` and `isClosing`. It presents only once the anchor
has a window. `popoverWillClose` cancels updates; `popoverDidClose` defers hosting
controller release and binding mutation to avoid AppKit close-callback reentrancy.
`invalidate()` defers final close/release and intentionally retains the coordinator
for that cleanup closure. Preserve these guards when modifying the bridge.

Cancellation is cooperative: canceling a `DispatchWorkItem` does not stop a body
that is already executing. State/validity checks and object ownership matter in
addition to cancellation. Avoid retaining transient views or controllers in
recurring callbacks; use weak captures where callbacks should not prolong lifetime.

`MonitorPanelController.stop()` cancels wake/resize work and stops sampling.
Observers are removed in `deinit`. Keep default and `NSWorkspace` notification
centers paired with their registration/removal sites.

## If sampling needs to move off the main actor

First measure responsiveness and sampling cost. An unstructured `Task` created
from main-actor code can inherit that isolation and still run synchronous work on
the main actor. Adding `Task.detached` around the current reader is not a safe
drop-in change.

A suitable design for a measured need is:

1. Give counter baselines a single serial owner, such as a dedicated actor.
2. Separate UI-bound application discovery/metadata from work whose native API
   thread requirements have been verified. Keep `NSImage`, `NSRunningApplication`,
   views and windows out of the worker transport contract.
3. Define explicit `Sendable` value snapshots for worker inputs/results.
   `ProcessCPUUsage` currently includes `NSImage`; the existing sample contract
   should not simply be declared safe to cross actors without an audit.
4. Allow at most one sampling operation in flight. Apply complete results on the
   main actor and associate them with a generation/session so an obsolete result
   cannot overwrite state after stop, restart or interval changes.
5. Store and cancel the worker task at its lifecycle owner. Recheck cancellation
   before publishing and preserve measured uptime and bounded histories.

This is guidance for a future change, not a description of implemented worker
infrastructure. Do not silence isolation diagnostics with `@unchecked Sendable`,
`nonisolated(unsafe)` or extra `assumeIsolated` calls without proving the relevant
ownership and execution guarantees.

## Validation

For concurrency changes, build with the target's existing Swift 6 settings and
exercise fast show/hide, refresh-interval replacement, repeated popover dismissal,
resize and sleep/wake paths as relevant. Main Thread Checker helps catch native UI
access on other threads; Thread Sanitizer can help if shared worker state is
introduced. Neither replaces reproducing transaction/reentrancy failures. See
[testing](testing.md) for the manual checks and reporting requirements.
