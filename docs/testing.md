# Testing and validation

## Current coverage

The repository has one app target and no automated unit/UI test target, test
sources, test plan or CI workflow. The shared scheme's Test action contains no
testables. `swift test` is not applicable because there is no `Package.swift`;
`xcodebuild test` is not an existing test suite. A successful build establishes
compilation and linking only.

Use checks proportional to the change: documentation needs link and whitespace
validation; Swift changes need a build; UI, process metrics and lifecycle changes
also need relevant runtime checks.

## Build

Run commands from the repository root on a Mac with compatible Xcode and an
Apple Silicon destination. Current app settings target macOS 26.0 and Swift 6.

```sh
xcodebuild -version
git diff --check
xcodebuild \
  -project NewTopUI/NewTopUI.xcodeproj \
  -scheme NewTopUI \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/NewTopUI-validation \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Confirm exit status zero and `BUILD SUCCEEDED`; inspect warnings relevant to the
change. The unsigned build is useful for compilation. Use Xcode's normal signing
configuration for representative sandbox and permission checks.

### Offline package resolution

SwiftFormat resolution may require network access. Reuse an existing compatible
`SourcePackages` cache when offline; locate it rather than embedding a developer's
machine-specific path in scripts:

```sh
ls -d "$HOME"/Library/Developer/Xcode/DerivedData/NewTopUI-*/SourcePackages
```

Set `NEWTOPUI_PACKAGE_CACHE` to an actual cache directory from that output, then:

```sh
xcodebuild \
  -project NewTopUI/NewTopUI.xcodeproj \
  -scheme NewTopUI \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/NewTopUI-validation \
  -clonedSourcePackagesDirPath "$NEWTOPUI_PACKAGE_CACHE" \
  -disableAutomaticPackageResolution \
  -skipPackageUpdates \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Confirm the cache contains the pinned dependency. If unavailable, report the
dependency-resolution limitation rather than changing the pin or removing the
dependency to force a build.

## Formatting and resources

If a compatible SwiftFormat executable is available, use its `--lint` mode on
touched Swift files with the root `.swiftformat`. The package dependency alone
does not imply a command is installed or that formatting runs during the build.
After formatting, review the diff and run `git diff --check` again.

Parse changed `.xcstrings` files as JSON and verify added strings have French and
Spanish translations with matching placeholders. Check displayed numbers with
locale-aware formats. The shared Xcode Run action currently sets French; explicitly
exercise English and Spanish as well for localization changes.

For Markdown changes, check that linked files exist and that skill frontmatter
contains the matching folder name and a meaningful description. Run the
skill-creator's `quick_validate.py` when that tool is available.

## Manual checks by affected behavior

| Area | Exercise | Expected observation |
| --- | --- | --- |
| Launch and status item | Launch, left-click twice, then inspect the right-click menu | Panel appears/toggles; localized Show/Hide and About controls work. |
| Sampling lifecycle | Show, hide, show; select 1/3/5-second intervals | Sampling stops while hidden, resumes on show, and interval changes leave one timer. |
| Layout | Toggle compact/full size, drag, inspect both appearance modes | 75% compact scaling, appropriate panel size, usable controls and no clipping. |
| Process details | Open/close repeatedly; dismiss outside, with Escape, and with its close button during refresh | No transaction warnings/crash; state stays synchronized; body and pointer form one native surface. |
| Stale process data | Open details for an app that exits or is no longer sampled | Last snapshot remains identified as stale. |
| CPU units | Observe a real busy app with one and multiple busy cores over several intervals | One busy core is near 100% process usage; multicore values can exceed 100%; bars stay within bounds. |
| Descendant accounting | Compare a real helper-process application with Activity Monitor and process ancestry | Readable descendants contribute; missing data is investigated under the actual sandbox. |
| GPU and memory | Inspect idle/load and hardware without compatible GPU statistics when available | Unavailable GPU is displayed as unavailable; memory units and categories remain plausible. |
| Network | Generate known transfer activity, then inspect idle and interface changes | Rates are bytes per second, directional, nonnegative, and do not spike from counter underflow. |
| Placement | Relaunch after dragging; sleep/wake; disconnect/reconnect an external display | Placement restoration and resizing remain usable; obsolete delayed work does not move the panel later. |
| Localization/accessibility | Run English, French and Spanish; inspect tooltips and VoiceOver labels | Translations, interpolated values and control descriptions are usable without clipped content. |

Use an isolated development instance for quit, placement and lifecycle checks
when the user has a running monitor. A temporary bundle identifier can isolate
UserDefaults without committing a project-setting change. Avoid interpreting
results from a differently signed or unsandboxed probe as proof of app behavior.

Activity Monitor can use a different interval and process grouping. Compare over
several samples and inspect actual PIDs/parents; exact percentage equality is not
the acceptance criterion. Do not diagnose absent children using compilation alone.

## Adding automated coverage when warranted

For consequential sampling or lifecycle changes, add a macOS test target to the
project and its testables to the shared scheme. Choose Swift Testing or XCTest
as appropriate; neither is currently configured here. Run `xcodebuild test` only
after wiring that target, using the same project, scheme and macOS destination.

Prefer deterministic seams for counters, elapsed uptime and snapshots over tests
that depend on live OS load. Useful cases include:

- Mach timebase conversion and fractions above one for multicore process usage.
- Counter reset, missing baselines, zero elapsed time and changed core counts.
- Descendant deduplication, processes appearing/disappearing and unreadable data.
- Memory accounting bounds, zero totals and history-size limits.
- Idempotent start/stop, interval replacement and stale callbacks after teardown.

Keep native popover, display and permission checks manual unless a reliable UI
test demonstrates the actual failure. Avoid tests that only mirror implementation
details or assert exact documentation wording.

## Reporting

Record the command/configuration, pass/fail, runtime interactions exercised and
any limits caused by hardware, signing, permissions or missing test infrastructure.
Keep compilation, automated tests and manual behavior as separate evidence.
