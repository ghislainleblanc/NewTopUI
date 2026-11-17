import SwiftUI

/// Colour choices for the dashboard graphs. Raw values are persisted in UserDefaults.
enum GraphTheme: String, CaseIterable {
    case system, multicolour, blue, purple, pink, red, orange, yellow, green, graphite

    var title: String {
        switch self {
        case .system: String(localized: "Use System Colour", comment: "Graph theme that follows the macOS accent colour")
        case .multicolour: String(localized: "Multicolour", comment: "Graph theme option")
        case .blue: String(localized: "Blue", comment: "Graph theme option")
        case .purple: String(localized: "Purple", comment: "Graph theme option")
        case .pink: String(localized: "Pink", comment: "Graph theme option")
        case .red: String(localized: "Red", comment: "Graph theme option")
        case .orange: String(localized: "Orange", comment: "Graph theme option")
        case .yellow: String(localized: "Yellow", comment: "Graph theme option")
        case .green: String(localized: "Green", comment: "Graph theme option")
        case .graphite: String(localized: "Graphite", comment: "Graph theme option")
        }
    }

    var palette: GraphPalette {
        switch self {
        case .system: Self.accentPalette(.accentColor)
        case .multicolour: Self.accentPalette(.accent)
        case .blue: Self.accentPalette(.blue)
        case .purple: Self.accentPalette(.purple)
        case .pink: Self.accentPalette(.pink)
        case .red: Self.accentPalette(.red)
        case .orange: Self.accentPalette(.orange)
        case .yellow: Self.accentPalette(.yellow)
        case .green: Self.accentPalette(.green)
        case .graphite: Self.accentPalette(.gray)
        }
    }
}

private extension GraphTheme {
    static func accentPalette(_ accent: Color) -> GraphPalette {
        let shadedAccent = accent.mix(with: .primary, by: 0.25)
        let contrastingAccent = accent.mix(with: .primary, by: 0.75)

        return GraphPalette(
            cpu: accent,
            cpuEnd: shadedAccent,
            gpu: accent,
            memory: accent,
            memoryEnd: shadedAccent,
            compressed: contrastingAccent,
            cached: accent.opacity(0.65),
            available: .secondary,
            download: accent,
            upload: contrastingAccent
        )
    }
}

struct GraphPalette {
    let cpu: Color
    let cpuEnd: Color
    let gpu: Color
    let memory: Color
    let memoryEnd: Color
    let compressed: Color
    let cached: Color
    let available: Color
    let download: Color
    let upload: Color
}

extension EnvironmentValues {
    @Entry var graphPalette: GraphPalette = GraphTheme.system.palette
}

struct GraphThemeMenu: View {
    @AppStorage("monitorGraphTheme") private var theme: GraphTheme = .system

    var body: some View {
        Menu {
            Picker(String(localized: "Colour theme"), selection: $theme) {
                ForEach(GraphTheme.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 25, height: 25)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 25, height: 25)
        .background(Color.primary.opacity(0.07), in: Circle())
        .help(String(localized: "Colour theme"))
        .accessibilityLabel(String(localized: "Colour theme"))
        .accessibilityValue(theme.title)
    }
}
