import SwiftUI

/// Shared palette for every graph and its legend. Raw values are persisted in UserDefaults.
enum GraphTheme: String, CaseIterable {
    case space, ocean, sunset, forest

    var title: String {
        switch self {
        case .space: String(localized: "Space", comment: "Cosmic graph colour theme")
        case .ocean: String(localized: "Ocean", comment: "Blue graph colour theme")
        case .sunset: String(localized: "Sunset", comment: "Warm graph colour theme")
        case .forest: String(localized: "Forest", comment: "Green graph colour theme")
        }
    }

    var palette: GraphPalette {
        switch self {
        case .space:
            GraphPalette(cpu: .purple, cpuEnd: .indigo, gpu: .cyan, memory: .indigo,
                         memoryEnd: .purple, compressed: .pink, cached: .cyan, available: .mint,
                         download: .cyan, upload: .purple)
        case .ocean:
            GraphPalette(cpu: .cyan, cpuEnd: .blue, gpu: .blue, memory: .blue,
                         memoryEnd: .indigo, compressed: .purple, cached: .cyan, available: .mint,
                         download: .cyan, upload: .indigo)
        case .sunset:
            GraphPalette(cpu: .orange, cpuEnd: .pink, gpu: .pink, memory: .yellow,
                         memoryEnd: .orange, compressed: .purple, cached: .pink, available: .red,
                         download: .orange, upload: .pink)
        case .forest:
            GraphPalette(cpu: .mint, cpuEnd: .green, gpu: .green, memory: .green,
                         memoryEnd: .teal, compressed: .yellow, cached: .mint, available: .cyan,
                         download: .green, upload: .teal)
        }
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
    @Entry var graphPalette: GraphPalette = GraphTheme.space.palette
}

struct GraphThemeMenu: View {
    @AppStorage("monitorGraphTheme") private var theme: GraphTheme = .space

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
