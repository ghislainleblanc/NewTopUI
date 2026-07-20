import Foundation
import Observation

struct CoreUsage: Identifiable, Equatable {
    let id: Int
    let fraction: Double
}

struct NetworkPoint: Identifiable, Equatable {
    let id: Int
    let receivedBytesPerSecond: Double
    let sentBytesPerSecond: Double
}

struct MemoryUsage: Equatable {
    var usedBytes: UInt64 = 0
    var totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory

    var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

struct SystemMetricsSample {
    let cores: [CoreUsage]
    let gpuFraction: Double?
    let receivedBytesPerSecond: Double
    let sentBytesPerSecond: Double
    let memory: MemoryUsage
}

@Observable
final class ResourceMonitorModel {
    private let reader = SystemMetricsReader()
    private var timer: Timer?
    private var sampleIndex = 0

    var cores: [CoreUsage]
    var gpuFraction: Double?
    var gpuHistory: [Double]
    var networkHistory: [NetworkPoint]
    var memory: MemoryUsage
    var isRunning = false

    var averageCPUFraction: Double {
        guard !cores.isEmpty else { return 0 }
        return cores.map(\.fraction).reduce(0, +) / Double(cores.count)
    }

    var receivedBytesPerSecond: Double {
        networkHistory.last?.receivedBytesPerSecond ?? 0
    }

    var sentBytesPerSecond: Double {
        networkHistory.last?.sentBytesPerSecond ?? 0
    }

    init() {
        let coreCount = max(ProcessInfo.processInfo.processorCount, 1)
        cores = (0 ..< coreCount).map { CoreUsage(id: $0, fraction: 0) }
        gpuFraction = nil
        gpuHistory = Array(repeating: 0, count: 28)
        networkHistory = (0 ..< 36).map {
            NetworkPoint(id: $0, receivedBytesPerSecond: 0, sentBytesPerSecond: 0)
        }
        memory = MemoryUsage()
        reader.primeCounters()
        refresh()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        timer?.tolerance = 0.08
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func refresh() {
        let sample = reader.sample()
        cores = sample.cores
        gpuFraction = sample.gpuFraction

        gpuHistory.append(sample.gpuFraction ?? 0)
        if gpuHistory.count > 28 {
            gpuHistory.removeFirst(gpuHistory.count - 28)
        }

        sampleIndex += 1
        networkHistory.append(
            NetworkPoint(
                id: sampleIndex,
                receivedBytesPerSecond: sample.receivedBytesPerSecond,
                sentBytesPerSecond: sample.sentBytesPerSecond
            )
        )
        if networkHistory.count > 36 {
            networkHistory.removeFirst(networkHistory.count - 36)
        }

        memory = sample.memory
    }
}
