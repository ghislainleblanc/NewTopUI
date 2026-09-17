import SwiftUI

struct ContentView: View {
    let model: ResourceMonitorModel
    let onClose: () -> Void
    let onQuit: () -> Void
    let onSizeChange: (CGSize) -> Void

    @State private var isCompact = false
    @State private var unscaledSize = CGSize(width: 420, height: 494)

    private var scale: CGFloat {
        isCompact ? 0.75 : 1
    }

    private var scaledSize: CGSize {
        CGSize(width: unscaledSize.width * scale, height: unscaledSize.height * scale)
    }

    var body: some View {
        MonitorContent(
            model: model,
            isCompact: $isCompact,
            onClose: onClose,
            onQuit: onQuit
        )
        .fixedSize(horizontal: true, vertical: true)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            unscaledSize = newSize
        }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: scaledSize.width, height: scaledSize.height, alignment: .topLeading)
        .onChange(of: scaledSize, initial: true) { _, newSize in
            onSizeChange(newSize)
        }
    }
}

private struct MonitorContent: View {
    let model: ResourceMonitorModel
    @Binding var isCompact: Bool
    let onClose: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ContentHeader(
                isCompact: $isCompact,
                onQuit: onQuit,
                onClose: onClose,
                onRefreshIntervalChange: { newRefreshInterval in
                    model.refreshInterval = newRefreshInterval
                }
            )

            MetricCard {
                CPUSection(model: model)
            }

            MetricCard(showsBorder: false) {
                TopCPUUsersSection(users: model.topCPUUsers)
            }
            .zIndex(1)

            HStack(alignment: .top, spacing: 10) {
                MetricCard {
                    GPUSection(model: model)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                MemoryCard(memory: model.memory)
                    .frame(maxWidth: .infinity, alignment: .top)
            }

            MetricCard {
                NetworkSection(model: model)
            }
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
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)
    }
}

private struct ContentHeader: View {
    @Binding var isCompact: Bool
    let onQuit: () -> Void
    let onClose: () -> Void
    let onRefreshIntervalChange: (TimeInterval) -> Void

    static let options = [
        RefreshOption(title: String(localized: "LIVE · 1 SEC", comment: "1 second duration"), refreshInterval: 1),
        RefreshOption(title: String(localized: "LIVE · 3 SEC", comment: "3 second duration"), refreshInterval: 3),
        RefreshOption(title: String(localized: "LIVE · 5 SEC", comment: "5 second duration"), refreshInterval: 5),
    ]

    @State private var selectedOption = Self.options.first!

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
                    .padding(.bottom, 2)

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)

                    Menu {
                        ForEach(Self.options, id: \.self) { option in
                            Button {
                                selectedOption = option
                            } label: {
                                HStack(alignment: .top) {
                                    Text(option.title)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))

                                    Spacer()

                                    if selectedOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(selectedOption.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                }
            }

            Spacer()

            HeaderButton(
                symbol: isCompact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                help: isCompact
                    ? String(localized: "Use full size", comment: "Tooltip for switching the monitor to full size")
                    : String(localized: "Use small size", comment: "Tooltip for switching the monitor to 75 percent size"),
                action: { isCompact.toggle() }
            )

            HeaderButton(
                symbol: "power",
                help: String(localized: "Quit System Pulse", comment: "Tooltip for the button that quits the app"),
                action: onQuit
            )

            HeaderButton(
                symbol: "xmark",
                help: String(localized: "Hide monitor", comment: "Tooltip for the button that hides the monitor panel"),
                action: onClose
            )
        }
        .contentShape(Rectangle())
        .onChange(of: selectedOption.refreshInterval) { _, newValue in
            onRefreshIntervalChange(newValue)
        }
    }
}

private struct RefreshOption: Hashable, Equatable {
    let title: String
    var refreshInterval: TimeInterval
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
    let showsBorder: Bool
    @ViewBuilder let content: () -> Content

    init(showsBorder: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.showsBorder = showsBorder
        self.content = content
    }

    var body: some View {
        content()
            .padding(12)
            .background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                }
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
                title: coreCountTitle,
                symbol: "cpu",
                color: .cyan,
                value: model.averageCPUFraction.formatted(.percent.precision(.fractionLength(0)))
            )

            CoreBarGraph(cores: model.cores)
        }
    }

    private var coreCountTitle: String {
        let format = if model.cores.count == 1 {
            String(localized: "CPU · %lld core", comment: "CPU heading for a computer with one core")
        } else {
            String(localized: "CPU · %lld cores", comment: "CPU heading followed by the number of processor cores")
        }
        return String(format: format, locale: .current, Int64(model.cores.count))
    }
}

private struct TopCPUUsersSection: View {
    let users: [ProcessCPUUsage]

    @State private var selectedUser: ProcessCPUUsage?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .foregroundStyle(.cyan)

                Text(String(localized: "Top CPU consumers", comment: "Heading for the processes using the most CPU"))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))

            if users.isEmpty {
                    Text(String(localized: "Waiting for process data…", comment: "Message shown before process CPU data is available"))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 5) {
                        ForEach(users) { user in
                            ProcessCPUUserRow(user: user) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedUser = user
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if let selectedUser {
                ProcessDetailOverlay(user: selectedUser) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.selectedUser = nil
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
            }
        }
        .onExitCommand {
            selectedUser = nil
        }
    }
}

private struct ProcessCPUUserRow: View {
    let user: ProcessCPUUsage
    let onShowDetails: () -> Void

    var body: some View {
        Button(action: onShowDetails) {
            HStack(spacing: 7) {
                Image(nsImage: user.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(user.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GeometryReader { proxy in
                    UnevenRoundedRectangle(
                        cornerRadii: RectangleCornerRadii(
                            topLeading: 0,
                            bottomLeading: 0,
                            bottomTrailing: 3,
                            topTrailing: 3
                        ),
                        style: .continuous
                    )
                    .fill(Color.primary.opacity(0.07))
                    .overlay(alignment: .leading) {
                        UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: 0,
                                bottomLeading: 0,
                                bottomTrailing: 3,
                                topTrailing: 3
                            ),
                            style: .continuous
                        )
                        .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(3, proxy.size.width * user.fraction))
                    }
                }
                .frame(width: 76, height: 7)

                Text(user.fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .buttonStyle(.plain)
        .help(
            String(
                format: String(
                    localized: "Show details for %1$@, using %2$@ CPU",
                    comment: "Tooltip for a top CPU user entry. The first placeholder is the app name and the second is CPU usage."
                ),
                locale: .current,
                user.name,
                user.fraction.formatted(.percent.precision(.fractionLength(0)))
            )
        )
        .accessibilityLabel(
            String(
                localized: "Show details for \(user.name)",
                comment: "Accessibility label for a top CPU user entry. The placeholder is the app name."
            )
        )
    }
}

private struct ProcessDetailOverlay: View {
    let user: ProcessCPUUsage
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                ProcessDetailHeader(name: user.name, icon: user.icon)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(localized: "Close process details", comment: "Accessibility label for closing process details")
                )
            }

            VStack(spacing: 8) {
                ProcessDetailRow(
                    title: String(localized: "CPU Usage", comment: "Label for an app's current CPU usage."),
                    value: user.fraction.formatted(.percent.precision(.fractionLength(1)))
                )
                ProcessDetailRow(
                    title: String(localized: "Memory Usage", comment: "Label for an app's current memory usage."),
                    value: ByteFormatting.compact(user.memoryBytes)
                )
                ProcessDetailRow(
                    title: String(localized: "Threads", comment: "Label for the number of threads used by an app."),
                    value: user.threadCount.formatted()
                )
                ProcessDetailRow(
                    title: String(localized: "Process ID", comment: "Label for an app's process identifier."),
                    value: String(user.id)
                )

                if let bundleIdentifier = user.bundleIdentifier {
                    ProcessDetailRow(
                        title: String(localized: "Bundle ID", comment: "Label for an app's bundle identifier."),
                        value: bundleIdentifier
                    )
                }

                if let executableURL = user.executableURL {
                    ProcessDetailRow(
                        title: String(localized: "Executable", comment: "Label for an app's executable path."),
                        value: executableURL.path,
                        lineLimit: nil
                    )
                }

                if let launchDate = user.launchDate {
                    ProcessDetailRow(
                        title: String(localized: "Launched", comment: "Label for the date and time an app was launched."),
                        value: launchDate.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(0.65)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
    }
}

private struct ProcessDetailHeader: View {
    let name: String
    let icon: NSImage

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(name)
                .font(.headline)
                .lineLimit(2)
        }
    }
}

private struct ProcessDetailRow: View {
    let title: String
    let value: String
    var lineLimit: Int? = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    let barHeight = max(3, 54 * core.fraction)
                    let trackCornerRadius = min(5, barWidth / 4)
                    let fillCornerRadius = min(trackCornerRadius, barHeight / 4)

                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            UnevenRoundedRectangle(
                                cornerRadii: RectangleCornerRadii(
                                    topLeading: trackCornerRadius,
                                    topTrailing: trackCornerRadius
                                ),
                                style: .continuous
                            )
                            .fill(Color.primary.opacity(0.065))

                            UnevenRoundedRectangle(
                                cornerRadii: RectangleCornerRadii(
                                    topLeading: fillCornerRadius,
                                    topTrailing: fillCornerRadius
                                ),
                                style: .continuous
                            )
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .indigo],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: barHeight)
                        }
                        .frame(width: barWidth, height: 54)
                        .help(coreHelp(core))

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

    private func coreHelp(_ core: CoreUsage) -> String {
        let format = String(
            localized: "Core %lld: %@",
            comment: "Tooltip for a processor core followed by its number and usage percentage"
        )
        return String(
            format: format,
            locale: .current,
            Int64(core.id + 1),
            core.fraction.formatted(.percent.precision(.fractionLength(0)))
        )
    }
}

private struct GPUSection: View {
    let model: ResourceMonitorModel

    var body: some View {
        VStack(spacing: 10) {
            SectionTitle(
                title: String(localized: "GPU", comment: "Graphics processor section heading"),
                symbol: "square.3.layers.3d",
                color: .pink,
                value: model.gpuFraction?.formatted(.percent.precision(.fractionLength(0)))
                    ?? String(localized: "N/A", comment: "Abbreviation shown when a metric is unavailable")
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
                title: String(localized: "Memory", comment: "Memory section heading"),
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

                HStack(spacing: 5) {
                    Text(memoryUsageSummary)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.orange.opacity(0.8))
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .frame(height: 48, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
    }

    private var memoryUsageSummary: String {
        let format = String(
            localized: "%1$@ of %2$@",
            comment: "Memory usage: the first value is used memory and the second is total memory"
        )
        return String(
            format: format,
            locale: .current,
            ByteFormatting.compact(memory.usedBytes),
            ByteFormatting.compact(memory.totalBytes)
        )
    }
}

private struct MemoryCard: View {
    let memory: MemoryUsage

    @State private var isShowingDetails = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.42)) {
                isShowingDetails.toggle()
            }
        } label: {
            ZStack {
                MetricCard {
                    MemorySection(memory: memory)
                        .frame(height: 70)
                }
                .opacity(isShowingDetails ? 0 : 1)

                MetricCard {
                    MemoryBreakdownSection(memory: memory)
                        .frame(height: 70)
                }
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isShowingDetails ? 1 : 0)
            }
            .rotation3DEffect(
                .degrees(isShowingDetails ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(
            isShowingDetails
                ? String(localized: "Click to show memory summary", comment: "Tooltip for the memory details card")
                : String(localized: "Click for a detailed memory breakdown", comment: "Tooltip for the memory summary card")
        )
        .accessibilityHint(
            isShowingDetails
                ? String(localized: "Shows the memory summary", comment: "Accessibility hint for the memory details card")
                : String(localized: "Shows memory categories", comment: "Accessibility hint for the memory summary card")
        )
    }
}

private struct MemoryBreakdownSection: View {
    let memory: MemoryUsage

    var body: some View {
        VStack(spacing: 5) {
            SectionTitle(
                title: String(localized: "Memory details", comment: "Detailed memory section heading"),
                symbol: "arrow.uturn.backward.circle",
                color: .orange,
                value: ByteFormatting.compact(memory.totalBytes)
            )

            VStack(spacing: 1) {
                MemoryBreakdownRow(
                    title: String(localized: "App", comment: "Memory used by apps category"),
                    color: .orange,
                    bytes: memory.applicationBytes,
                    totalBytes: memory.totalBytes,
                    help: String(
                        localized: "Anonymous, non-purgeable memory used by apps and system processes",
                        comment: "Tooltip explaining the app memory category"
                    )
                )

                MemoryBreakdownRow(
                    title: String(localized: "Wired", comment: "Wired memory category"),
                    color: .pink,
                    bytes: memory.wiredBytes,
                    totalBytes: memory.totalBytes,
                    help: String(
                        localized: "Memory that must remain in physical RAM",
                        comment: "Tooltip explaining the wired memory category"
                    )
                )

                MemoryBreakdownRow(
                    title: String(localized: "Compressed", comment: "Compressed memory category"),
                    color: .purple,
                    bytes: memory.compressedBytes,
                    totalBytes: memory.totalBytes,
                    help: String(
                        localized: "Physical RAM occupied by compressed memory",
                        comment: "Tooltip explaining the compressed memory category"
                    )
                )

                MemoryBreakdownRow(
                    title: String(localized: "Cached", comment: "Cached memory category"),
                    color: .cyan,
                    bytes: memory.cachedBytes,
                    totalBytes: memory.totalBytes,
                    help: String(
                        localized: "File-backed and purgeable memory that macOS can quickly reuse",
                        comment: "Tooltip explaining the cached memory category"
                    )
                )

                MemoryBreakdownRow(
                    title: String(localized: "Available", comment: "Available memory category"),
                    color: .green,
                    bytes: memory.availableBytes,
                    totalBytes: memory.totalBytes,
                    help: String(
                        localized: "Physical RAM not currently assigned to another category",
                        comment: "Tooltip explaining the available memory category"
                    )
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MemoryBreakdownRow: View {
    let title: String
    let color: Color
    let bytes: UInt64
    let totalBytes: UInt64
    let help: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 2)

            Text(ByteFormatting.compact(bytes))
                .foregroundStyle(.primary)

            Text(memoryFraction.formatted(.percent.precision(.fractionLength(0))))
                .foregroundStyle(.tertiary)
                .frame(width: 25, alignment: .trailing)
        }
        .font(.system(size: 8, weight: .medium, design: .rounded))
        .monospacedDigit()
        .help(help)
    }

    private var memoryFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(bytes) / Double(totalBytes), 0), 1)
    }
}

private struct MiniBarHistory: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 2
            let textDescenderInset: CGFloat = 3
            let graphHeight = proxy.size.height - textDescenderInset
            let width = max((proxy.size.width - CGFloat(max(values.count - 1, 0)) * spacing) / CGFloat(max(values.count, 1)), 2)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(color.opacity(0.25 + value * 0.75))
                        .frame(width: width, height: max(3, graphHeight * value))
                }
            }
            .padding(.bottom, textDescenderInset)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
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

                NetworkSpeed(
                    label: String(localized: "DOWN", comment: "Abbreviated network download label"),
                    symbol: "arrow.down",
                    color: .green,
                    bytes: model.receivedBytesPerSecond
                )

                NetworkSpeed(
                    label: String(localized: "UP", comment: "Abbreviated network upload label"),
                    symbol: "arrow.up",
                    color: .blue,
                    bytes: model.sentBytesPerSecond
                )
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
