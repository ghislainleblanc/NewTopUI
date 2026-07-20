import SwiftUI

struct ContentView: View {
    let model: ResourceMonitorModel
    let onClose: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ContentHeader(onQuit: onQuit, onClose: onClose)

            MetricCard {
                CPUSection(model: model)
            }

            HStack(alignment: .top, spacing: 10) {
                MetricCard {
                    GPUSection(model: model)
                }

                MetricCard {
                    MemorySection(memory: model.memory)
                }
            }

            MetricCard {
                NetworkSection(model: model)
            }

            ContentFooter()
        }
        .padding(16)
        .frame(width: 420)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.11), Color.indigo.opacity(0.055), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ContentHeader: View {
    let onQuit: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("System Pulse")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)

                    Text("LIVE · 1 SEC")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HeaderButton(symbol: "power", help: "Quit System Pulse", action: onQuit)

            HeaderButton(symbol: "xmark", help: "Hide monitor", action: onClose)
        }
        .contentShape(Rectangle())
    }
}

private struct ContentFooter: View {
    var body: some View {
        HStack {
            Image(systemName: "hand.draw")

            Text("Drag anywhere to move")

            Spacer()

            Text("Click the menu bar CPU icon to reopen")
        }
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 2)
    }
}

private struct HeaderButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 25, height: 25)
                .background(Color.primary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct MetricCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
    }
}

private struct SectionTitle: View {
    let title: String
    let symbol: String
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(color)

            Text(title.uppercased())
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .monospacedDigit()
    }
}

private struct CPUSection: View {
    let model: ResourceMonitorModel

    var body: some View {
        VStack(spacing: 9) {
            SectionTitle(
                title: "CPU · \(model.cores.count) cores",
                symbol: "cpu",
                color: .cyan,
                value: model.averageCPUFraction.formatted(.percent.precision(.fractionLength(0)))
            )

            CoreBarGraph(cores: model.cores)
        }
    }
}

private struct CoreBarGraph: View {
    let cores: [CoreUsage]

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = cores.count > 16 ? 3 : 5
            let availableWidth = proxy.size.width - CGFloat(max(cores.count - 1, 0)) * spacing
            let barWidth = max(availableWidth / CGFloat(max(cores.count, 1)), 4)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(cores) { core in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.primary.opacity(0.065))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .indigo],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: max(3, 54 * core.fraction))
                        }
                        .frame(width: barWidth, height: 54)
                        .help("Core \(core.id + 1): \(core.fraction.formatted(.percent.precision(.fractionLength(0))))")

                        Text("\(core.id + 1)")
                            .font(.system(size: cores.count > 16 ? 6.5 : 7.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .frame(width: barWidth)
                    }
                }
            }
        }
        .frame(height: 68)
    }
}

private struct GPUSection: View {
    let model: ResourceMonitorModel

    var body: some View {
        VStack(spacing: 10) {
            SectionTitle(
                title: "GPU",
                symbol: "square.3.layers.3d",
                color: .pink,
                value: model.gpuFraction?.formatted(.percent.precision(.fractionLength(0))) ?? "N/A"
            )

            MiniBarHistory(values: model.gpuHistory, color: .pink)
                .frame(height: 48)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MemorySection: View {
    let memory: MemoryUsage

    var body: some View {
        VStack(spacing: 10) {
            SectionTitle(
                title: "Memory",
                symbol: "memorychip",
                color: .orange,
                value: memory.fraction.formatted(.percent.precision(.fractionLength(0)))
            )

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.07))

                        Capsule()
                            .fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, proxy.size.width * memory.fraction))
                    }
                }
                .frame(height: 9)

                Text("\(ByteFormatting.compact(memory.usedBytes)) of \(ByteFormatting.compact(memory.totalBytes))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(height: 48, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MiniBarHistory: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 2
            let width = max((proxy.size.width - CGFloat(max(values.count - 1, 0)) * spacing) / CGFloat(max(values.count, 1)), 2)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(color.opacity(0.25 + value * 0.75))
                        .frame(width: width, height: max(3, proxy.size.height * value))
                }
            }
        }
    }
}

private struct NetworkSection: View {
    let model: ResourceMonitorModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("NETWORK", systemImage: "network")
                    .foregroundStyle(.secondary)

                Spacer()

                NetworkSpeed(label: "DOWN", symbol: "arrow.down", color: .green, bytes: model.receivedBytesPerSecond)

                NetworkSpeed(label: "UP", symbol: "arrow.up", color: .blue, bytes: model.sentBytesPerSecond)
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))

            NetworkLineGraph(points: model.networkHistory)
                .frame(height: 82)
        }
    }
}

private struct NetworkSpeed: View {
    let label: String
    let symbol: String
    let color: Color
    let bytes: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .foregroundStyle(color)

            Text(label)
                .foregroundStyle(.tertiary)

            Text(ByteFormatting.speed(bytes))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }
}

private struct NetworkLineGraph: View {
    let points: [NetworkPoint]

    var body: some View {
        Canvas { context, size in
            let received = points.map(\.receivedBytesPerSecond)
            let sent = points.map(\.sentBytesPerSecond)
            let peak = max((received + sent).max() ?? 0, 1024)

            for fraction in [0.25, 0.5, 0.75] {
                var gridLine = Path()
                let y = size.height * fraction
                gridLine.move(to: CGPoint(x: 0, y: y))
                gridLine.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(gridLine, with: .color(.white.opacity(0.055)), lineWidth: 0.5)
            }

            drawLine(values: received, peak: peak, size: size, color: .green, context: &context)
            drawLine(values: sent, peak: peak, size: size, color: .blue, context: &context)
        }
        .background(Color.black.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func drawLine(
        values: [Double],
        peak: Double,
        size: CGSize,
        color: Color,
        context: inout GraphicsContext
    ) {
        guard values.count > 1 else { return }
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = min(max(value / peak, 0), 1)
            let y = size.height - (size.height * CGFloat(normalized) * 0.88) - 4
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
    }
}

private enum ByteFormatting {
    static func compact(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }

    static func speed(_ bytesPerSecond: Double) -> String {
        let safeValue = UInt64(max(bytesPerSecond, 0))
        return "\(ByteCountFormatter.string(fromByteCount: Int64(clamping: safeValue), countStyle: .file))/s"
    }
}
