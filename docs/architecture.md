# Architecture

## Product and build

System Pulse runs as an accessory application with a menu-bar status item and a
floating monitor panel. `NewTopUIApp` supplies an empty Settings scene; the real
interface is hosted by AppKit. There is no conventional main document window or
navigation stack.

`NewTopUI/NewTopUI.xcodeproj` contains one application target, `NewTopUI`, with
Debug and Release configurations and a shared scheme. The app target sets Swift
6, approachable concurrency and default `MainActor` isolation. Its deployment
target is macOS 26.0, overriding the project-level 26.5 setting; project settings
exclude `i386` and `x86_64`. App Sandbox and Hardened Runtime are enabled, and
`LSUIElement` is generated in the Info.plist. Inspect effective build settings
before changing platform support.

SwiftFormat is the only declared Swift package dependency. The requirement starts
at 0.62.1 and `Package.resolved` currently pins 0.63.0. Formatting settings live
in the root `.swiftformat`; there is no formatter build script. Source and asset
membership use Xcode's filesystem-synchronized `NewTopUI` group.

## Ownership and flow

```text
NewTopUIApp → AppDelegate → MonitorPanelController
                              ├─ NSStatusItem + DraggablePanel
                              └─ ResourceMonitorModel
                                   ├─ Timer → SystemMetricsReader.sample()
                                   └─ observed values → ContentView / MonitorContent
                                                           └─ ProcessDetailsPopover
                                                                → NSPopover + hosting controller
```

`AppDelegate` owns one `MonitorPanelController`. The controller owns the model,
panel, status item and pending resize/wake work. It installs the status button
after a short main-queue delay to allow macOS to connect the status-item scene.
Left click toggles visibility; right click opens the localized context menu.
Showing the panel starts sampling, hiding it stops sampling, and termination
calls `stop()`.

`ResourceMonitorModel` is an `@Observable` reference type passed directly to
SwiftUI views. It owns one reader and one repeating timer. Initialization primes
counter baselines and refreshes once. `start()` refreshes immediately before
scheduling the timer; `refreshInterval` restarts sampling through `stop()` and
`start()` even if the model was previously stopped. Views choose intervals of
1, 3 or 5 seconds. GPU history keeps 28 points and network history keeps 36;
these are sample counts, so their time span varies with refresh interval.

## Metric acquisition

`SystemMetricsReader` retains previous CPU ticks, interface totals, process CPU
counters, parent mappings and monotonic timestamps. Each synchronous `sample()`
returns a `SystemMetricsSample`; the model then updates observable properties.

| Metric | Source and interpretation |
| --- | --- |
| Per-core CPU | `host_processor_info`; non-idle tick delta divided by total delta, bounded to 0–1. Dashboard CPU is the arithmetic average across cores. |
| Application CPU | Regular applications from `NSWorkspace`, excluding this app; Darwin task counters plus discoverable descendants, converted from Mach ticks and divided by elapsed uptime. One busy core is fraction 1; multiple cores may exceed it. |
| Process resources | Readable `PROC_PIDTASKINFO` entries supply resident bytes, threads, CPU time, faults and context switches. Memory/threads sum the current readable tree; cumulative counters describe currently readable processes. |
| GPU | IOKit `IOAccelerator` performance statistics; maximum compatible device reading, or `nil` when unavailable. |
| Network | `getifaddrs` totals for unique, up, non-loopback link interfaces; byte deltas divided by elapsed uptime. These are system interface statistics, not HTTP traffic. |
| Memory | `host_statistics64` and host page size; application, wired, compressed and cached estimates bounded by physical memory. Available memory subtracts used and cached memory from total. |

Process discovery traverses `proc_listchildpids` with a visited set. Its sizing
call returns a PID count; buffer length is passed in bytes. CPU aggregation uses
the union of current and previous descendant sets but counts only PIDs present in
both CPU snapshots with nondecreasing counters. New or disappeared processes can
therefore contribute no delta for an interval. PID reuse remains an edge case
to consider if process identity handling changes.

The reader returns all matching applications sorted by CPU; `TopCPUUsersSection`
displays the first five. Details resolve the selected PID against the latest
sample, falling back to the last snapshot with a stale-data message when absent.

## Presentation and persistence

`ContentView.swift` contains separate structs for the header, metric cards,
graphs, process details and byte formatting. `monitorIsCompact` is persisted via
`@AppStorage`; compact mode scales content to 75%. Geometry changes notify the
panel controller, which defers resizing and preserves the panel's top edge.

The borderless, nonactivating `DraggablePanel` can become key but not main. It is
floating, appears across Spaces and supports dragging. Placement persists in
UserDefaults using `monitorPanelOrigin`, `monitorPanelScreen`,
`monitorPanelScreenOriginX` and `monitorPanelScreenOriginY`. Screen UUID and
relative coordinates support restoration; legacy absolute placement is retained
as a fallback. Wake restoration retries after display changes, with cancellation
and stability checks. Current visibility clamping corrects fully off-screen
placement, so do not assume every saved partially visible frame is repositioned.

`ProcessDetailsPopover` bridges SwiftUI to a transient native `NSPopover` through
an `NSViewRepresentable` coordinator. It defers presentation and teardown out of
SwiftUI update transactions, disables animation, and uses a 440 × 580 popover.
`ProcessDetailOverlay` lets AppKit draw the body and arrow background together.
Memory details currently use a separate SwiftUI popover.

## Constraints and extension points

- App Sandbox may prevent reading task information or discovering children.
  Current discovery does not expose a distinct permission-error model. An empty
  or partial result is not evidence that an application has no helpers.
- Unsupported GPU readings remain optional; current GPU history appends zero for
  unavailable samples even though the live value is `nil`.
- Sampling runs synchronously on the main actor. Baselines survive panel hiding,
  so the first resumed sample may cover the hidden interval.
- There is no backend, API router, HTTP client, persistence database, test target
  or CI workflow. Add one only when the feature calls for it.
- Add metric acquisition in Services, value semantics in Models and presentation
  in SwiftUI structs. Lifecycle and native window ownership belong in the panel
  controller or a dedicated AppKit bridge.

See [concurrency](concurrency.md) for execution constraints and
[testing](testing.md) for build and behavioral validation.
