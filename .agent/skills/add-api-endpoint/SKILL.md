---
name: add-api-endpoint
description: Handle requests to add API access or an endpoint to System Pulse by identifying whether they concern native macOS APIs, an HTTP client, or an explicitly requested server contract.
---

# Add API access or an endpoint

Read [AGENTS.md](../../../AGENTS.md) and
[architecture](../../../docs/architecture.md). This repository is a local macOS
monitor: it has no HTTP server, route registry or existing HTTP client. Interface
network counters are OS statistics and do not constitute an API integration.

## Choose the actual integration

Use the request and current checkout to determine the intended boundary:

- A native system reading belongs in the Services/Models sampling path below.
- Calling a remote endpoint is HTTP client work; use the remote contract below.
- Exposing a server endpoint requires an explicitly requested server component
  and its contract. Locate that component if supplied. If language, host or
  semantics are missing and consequential, ask a focused question while preparing
  independent app-side work. Do not invent a backend framework or route layout.

## Native macOS API

1. Inspect similar calls in `SystemMetricsReader.swift`. Verify return codes,
   units, buffer-sizing semantics, availability, sandbox behavior and resource
   ownership against the SDK headers or authoritative documentation.
2. Keep unsafe pointers within their valid scopes. Pair Mach allocations, IOKit
   objects and interface lists with the appropriate deallocation/release, as the
   existing reader does.
3. Add a typed result and a deliberate unavailable/error representation; avoid
   treating access denial as proof of zero activity. Serialize mutable baselines.
4. Integrate model publication and any requested localized display. Test with
   actual sandboxed app behavior and hardware, not only an unrestricted probe.

For process CPU, convert Mach ticks with the timebase. For child PID lists, the
returned size is a PID count while the input buffer size is bytes. Neither
permission workarounds nor sandbox removal are routine fixes.

## HTTP client or explicitly requested server

- Establish URL/path, method, request/response schema, authentication, error
  behavior and timeout/cancellation from supplied requirements or an existing
  authoritative contract. Do not invent credentials or production addresses.
- For a client, keep transport/decoding in a dedicated service under the app's
  Services directory, use typed payloads, and publish UI state on the main actor.
  Separate transport, status and decoding failures; keep secrets out of sources,
  logs and query strings. Add only required network capabilities and describe them.
- For a server, implement within the expressly chosen component; define input
  validation and response/error semantics. Update architecture docs to describe
  the new boundary rather than claiming an existing server convention.
- Use deterministic mock transport or route tests for success, malformed data,
  failure and cancellation as applicable. Do not make repeated live requests or
  perform remote writes merely to prove a local implementation.

Read [concurrency](../../../docs/concurrency.md) for ownership/cancellation and
[testing](../../../docs/testing.md) for existing build limits. Deliver the concrete
contract, implementation and actual validation; identify any still-missing external
contract or infrastructure without describing it as implemented.
