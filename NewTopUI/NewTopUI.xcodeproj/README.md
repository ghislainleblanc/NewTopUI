# System Pulse

System Pulse is a lightweight macOS menu-bar monitor built with SwiftUI and AppKit. It provides a compact, always-available view of the Mac's current system activity.

## Features

- Per-core CPU utilization with an average CPU percentage
- Top CPU-consuming applications, including their app icons
- GPU utilization when supported by the hardware
- Memory usage, including application, wired, compressed, cached, and available memory
- Network upload and download rates with short history graphs
- Refresh intervals of 1, 3, or 5 seconds
- Menu-bar controls for showing, hiding, and quitting the monitor
- Persistent panel placement across launches, display changes, and wake from sleep
- Localized interface resources for English, French, and Spanish

## Requirements

- macOS
- Xcode
- A Mac target capable of running the app's AppKit and IOKit-based system metrics code

## Getting started

1. Open the project in Xcode.
2. Select the **NewTopUI** app scheme.
3. Choose a macOS run destination.
4. Build and run the app.
5. Click the CPU icon in the menu bar to show or hide the monitor.

The monitor opens near the menu-bar item the first time it runs. Its position is restored on subsequent launches.

## Project structure

- `NewTopUI/NewTopUI/ContentView.swift` — SwiftUI dashboard and metric cards
- `NewTopUI/NewTopUI/Models/SystemMetrics.swift` — observable monitoring model and metric types
- `NewTopUI/NewTopUI/Services/SystemMetricsReader.swift` — CPU, GPU, memory, network, and process sampling
- `NewTopUI/NewTopUI/NewTopUIApp.swift` — menu-bar item, panel window, placement restoration, and app lifecycle
- `NewTopUI/NewTopUI/Localizable.xcstrings` — user-facing interface translations
- `NewTopUI/NewTopUI/InfoPlist.xcstrings` — localized bundle metadata

## Implementation notes

System Pulse uses native macOS APIs:

- Mach host processor information for per-core CPU usage
- IOKit accelerator statistics for GPU utilization
- Darwin process APIs and `NSWorkspace` for application CPU usage
- Network interface statistics for transfer rates
- Host statistics for memory usage
- SwiftUI with the Observation framework for the live dashboard

GPU utilization is hardware-dependent and may display as unavailable on systems that do not expose compatible accelerator statistics.

## License

No license has been specified for this project.
