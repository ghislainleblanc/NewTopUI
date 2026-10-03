---
name: add-feature
description: Implement a System Pulse feature across its macOS sampling, observable model, SwiftUI interface and AppKit lifecycle, with validation appropriate to the affected behavior.
---

# Add a feature

Read [AGENTS.md](../../../AGENTS.md) and
[architecture](../../../docs/architecture.md). Locate the existing component
closest to the requested behavior before introducing another abstraction.

## Implementation

- Turn the request into observable acceptance criteria, including unavailable or
  stale data where relevant. Resolve routine choices from existing code; ask for
  missing product behavior only when it materially blocks implementation.
- Trace the full data path. Add native acquisition in `SystemMetricsReader`,
  metric fields in `SystemMetrics.swift`, model publication/history in
  `ResourceMonitorModel`, and separate SwiftUI structs for presentation.
- For window/menu behavior, work in `MonitorPanelController`. For process details,
  preserve the native `ProcessDetailsPopover` bridge and its delayed lifecycle.
- Preserve metric units, monotonic elapsed time, bounded histories, readable-only
  descendant accounting and optional GPU availability. Keep process CPU uncapped
  even when the UI bar saturates.
- Read [concurrency](../../../docs/concurrency.md) if adding callbacks, changing
  polling or moving work. Keep one owner for timer and sampling state.
- Add English-source catalog entries with French/Spanish translations, localized
  formatting and accessible control labels. Put new Swift sources in the existing
  filesystem-synchronized app directory.
- Update relevant docs if ownership, build steps or user behavior change. Do not
  introduce a backend, dependency or general refactor without a feature need.

## Completion

Follow [testing](../../../docs/testing.md): build code changes and exercise the
affected UI or real metric path. Add deterministic regression tests for consequential
logic when useful; currently a test target must be created and wired before tests
can run. Report behavior delivered, checks run and any unverified acceptance
criteria. A successful build alone does not establish runtime correctness.
