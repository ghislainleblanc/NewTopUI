import AppKit
import Darwin
import Foundation
import IOKit

final class SystemMetricsReader {
    private var previousCPUTicks: [[UInt64]]?
    private var previousNetworkBytes: (received: UInt64, sent: UInt64)?
    private var previousNetworkTime: TimeInterval?
    private var previousProcessCPU: [pid_t: UInt64] = [:]
    private var previousProcessParents: [pid_t: pid_t] = [:]
    private var previousProcessTime: TimeInterval?

    func primeCounters() {
        previousCPUTicks = currentCPUTicks()
        previousNetworkBytes = currentNetworkBytes()
        let now = ProcessInfo.processInfo.systemUptime
        previousNetworkTime = now
        let processSnapshot = currentProcessSnapshot()
        previousProcessCPU = processSnapshot.cpu
        previousProcessParents = processSnapshot.parents
        previousProcessTime = now
    }

    func sample() -> SystemMetricsSample {
        let cores = sampleCPU()
        let gpuFraction = sampleGPU()
        let network = sampleNetwork()
        let topCPUUsers = sampleTopCPUUsers()

        return SystemMetricsSample(
            cores: cores,
            gpuFraction: gpuFraction,
            receivedBytesPerSecond: network.received,
            sentBytesPerSecond: network.sent,
            memory: sampleMemory(),
            topCPUUsers: topCPUUsers
        )
    }

    private func currentCPUTicks() -> [[UInt64]]? {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let processorInfo else { return nil }
        defer {
            let byteCount = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorInfo), byteCount)
        }

        return (0 ..< Int(processorCount)).map { core in
            let offset = core * Int(CPU_STATE_MAX)
            return (0 ..< Int(CPU_STATE_MAX)).map { state in
                UInt64(UInt32(bitPattern: processorInfo[offset + state]))
            }
        }
    }

    private func sampleCPU() -> [CoreUsage] {
        guard let current = currentCPUTicks() else { return [] }
        defer { previousCPUTicks = current }
        guard let previous = previousCPUTicks, previous.count == current.count else {
            return current.indices.map { CoreUsage(id: $0, fraction: 0) }
        }

        return current.indices.map { core in
            let currentCore = current[core]
            let previousCore = previous[core]
            let differences = currentCore.indices.map { state in
                currentCore[state] >= previousCore[state] ? currentCore[state] - previousCore[state] : 0
            }
            let total = differences.reduce(0, +)
            let idle = differences[Int(CPU_STATE_IDLE)]
            let fraction = total > 0 ? Double(total - idle) / Double(total) : 0
            return CoreUsage(id: core, fraction: min(max(fraction, 0), 1))
        }
    }

    private func sampleGPU() -> Double? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var readings: [Double] = []
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let property = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue(),
                let statistics = property as? [String: Any]
            else { continue }

            let preferredKeys = [
                "Device Utilization %",
                "GPU Core Utilization",
                "Renderer Utilization %",
            ]
            for key in preferredKeys {
                if let number = statistics[key] as? NSNumber {
                    readings.append(min(max(number.doubleValue / 100, 0), 1))
                    break
                }
            }
        }

        return readings.max()
    }

    private func currentProcessSnapshot() -> (
        cpu: [pid_t: UInt64],
        parents: [pid_t: pid_t],
        resources: [pid_t: (memoryBytes: UInt64, threadCount: Int)]
    ) {
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier > 0
                && $0.processIdentifier != ownProcessID
                && $0.activationPolicy == .regular
        }

        var queue: [(pid: pid_t, parent: pid_t?)] = applications.map {
            (pid: $0.processIdentifier, parent: nil)
        }
        var visited = Set<pid_t>()
        var cpu: [pid_t: UInt64] = [:]
        var parents: [pid_t: pid_t] = [:]
        var resources: [pid_t: (memoryBytes: UInt64, threadCount: Int)] = [:]

        while let entry = queue.first {
            queue.removeFirst()
            guard visited.insert(entry.pid).inserted else { continue }

            var taskInfo = proc_taskinfo()
            let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.stride)
            if proc_pidinfo(entry.pid, PROC_PIDTASKINFO, 0, &taskInfo, taskInfoSize) == taskInfoSize {
                cpu[entry.pid] = taskInfo.pti_total_user &+ taskInfo.pti_total_system
                resources[entry.pid] = (
                    memoryBytes: taskInfo.pti_resident_size,
                    threadCount: Int(taskInfo.pti_threadnum)
                )
            }
            if let parent = entry.parent {
                parents[entry.pid] = parent
            }

            let bufferSize = proc_listchildpids(entry.pid, nil, 0)
            guard bufferSize > 0 else { continue }

            let pidCount = Int(bufferSize) / MemoryLayout<pid_t>.stride
            var childPIDs = [pid_t](repeating: 0, count: pidCount)
            let actualSize = childPIDs.withUnsafeMutableBytes { buffer in
                proc_listchildpids(entry.pid, buffer.baseAddress, Int32(buffer.count))
            }
            guard actualSize > 0 else { continue }

            let actualPIDCount = Int(actualSize) / MemoryLayout<pid_t>.stride
            queue.append(contentsOf: childPIDs.prefix(actualPIDCount).map {
                (pid: $0, parent: entry.pid)
            })
        }

        return (cpu, parents, resources)
    }

    private func descendantPIDs(
        for pid: pid_t,
        parents: [pid_t: pid_t]
    ) -> Set<pid_t> {
        var included = Set([pid])
        var changed = true

        while changed {
            changed = false
            for (candidate, parent) in parents where parent == pid || included.contains(parent) {
                guard included.insert(candidate).inserted else { continue }
                changed = true
            }
        }

        return included
    }

    private func aggregateCPUChange(
        for pid: pid_t,
        currentCPU: [pid_t: UInt64],
        currentParents: [pid_t: pid_t],
        previousCPU: [pid_t: UInt64],
        previousParents: [pid_t: pid_t]
    ) -> UInt64 {
        let processIDs = descendantPIDs(for: pid, parents: currentParents)
            .union(descendantPIDs(for: pid, parents: previousParents))

        return processIDs.reduce(0) { total, processID in
            guard
                let current = currentCPU[processID],
                let previous = previousCPU[processID],
                current >= previous
            else {
                return total
            }
            return total &+ (current - previous)
        }
    }

    private func sampleTopCPUUsers() -> [ProcessCPUUsage] {
        let applications = NSWorkspace.shared.runningApplications.filter { application in
            application.processIdentifier > 0
                && application.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && application.activationPolicy == .regular
                && application.icon != nil
                && application.localizedName != nil
        }
        let processSnapshot = currentProcessSnapshot()
        let now = ProcessInfo.processInfo.systemUptime
        defer {
            previousProcessCPU = processSnapshot.cpu
            previousProcessParents = processSnapshot.parents
            previousProcessTime = now
        }

        guard let previousProcessTime else {
            return applications.compactMap { application in
                guard let icon = application.icon, let name = application.localizedName else { return nil }
                return ProcessCPUUsage(
                    id: application.processIdentifier,
                    name: name,
                    icon: icon,
                    fraction: 0,
                    memoryBytes: processSnapshot.resources[application.processIdentifier]?.memoryBytes ?? 0,
                    threadCount: processSnapshot.resources[application.processIdentifier]?.threadCount ?? 0,
                    bundleIdentifier: application.bundleIdentifier,
                    executableURL: application.executableURL,
                    launchDate: application.launchDate
                )
            }
            .prefix(5)
            .map { $0 }
        }
        let elapsed = max(now - previousProcessTime, 0.001)

        return applications.compactMap { application in
            let cpuTicks = aggregateCPUChange(
                for: application.processIdentifier,
                currentCPU: processSnapshot.cpu,
                currentParents: processSnapshot.parents,
                previousCPU: previousProcessCPU,
                previousParents: previousProcessParents
            )
            guard
                let icon = application.icon,
                let name = application.localizedName
            else { return nil }

            let cpuNanoseconds = machTicksToNanoseconds(cpuTicks)
            let cpuFraction = cpuNanoseconds / 1_000_000_000 / elapsed
            return ProcessCPUUsage(
                id: application.processIdentifier,
                name: name,
                icon: icon,
                fraction: min(max(cpuFraction, 0), 1),
                memoryBytes: processSnapshot.resources[application.processIdentifier]?.memoryBytes ?? 0,
                threadCount: processSnapshot.resources[application.processIdentifier]?.threadCount ?? 0,
                bundleIdentifier: application.bundleIdentifier,
                executableURL: application.executableURL,
                launchDate: application.launchDate
            )
        }
        .sorted { $0.fraction > $1.fraction }
        .prefix(5)
        .map { $0 }
    }

    private func machTicksToNanoseconds(_ ticks: UInt64) -> Double {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(ticks) * Double(timebase.numer) / Double(timebase.denom)
    }

    private func currentNetworkBytes() -> (received: UInt64, sent: UInt64) {
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&firstAddress) == 0, let firstAddress else { return (0, 0) }
        defer { freeifaddrs(firstAddress) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var seenInterfaces = Set<String>()
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let address = cursor {
            defer { cursor = address.pointee.ifa_next }
            let interface = address.pointee
            guard let socketAddress = interface.ifa_addr,
                  socketAddress.pointee.sa_family == UInt8(AF_LINK),
                  interface.ifa_flags & UInt32(IFF_UP) != 0,
                  interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  let dataPointer = interface.ifa_data
            else { continue }

            let name = String(cString: interface.ifa_name)
            guard seenInterfaces.insert(name).inserted else { continue }
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            received &+= UInt64(data.ifi_ibytes)
            sent &+= UInt64(data.ifi_obytes)
        }

        return (received, sent)
    }

    private func sampleNetwork() -> (received: Double, sent: Double) {
        let current = currentNetworkBytes()
        let now = ProcessInfo.processInfo.systemUptime
        defer {
            previousNetworkBytes = current
            previousNetworkTime = now
        }

        guard let previousNetworkBytes, let previousNetworkTime else { return (0, 0) }
        let elapsed = max(now - previousNetworkTime, 0.001)
        let receivedDelta = current.received >= previousNetworkBytes.received
            ? current.received - previousNetworkBytes.received : 0
        let sentDelta = current.sent >= previousNetworkBytes.sent
            ? current.sent - previousNetworkBytes.sent : 0
        return (Double(receivedDelta) / elapsed, Double(sentDelta) / elapsed)
    }

    private func sampleMemory() -> MemoryUsage {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else { return MemoryUsage(totalBytes: total) }

        var hostPageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &hostPageSize) == KERN_SUCCESS else {
            return MemoryUsage(totalBytes: total)
        }
        let pageSize = UInt64(hostPageSize)
        let internalPages = UInt64(statistics.internal_page_count)
        let purgeablePages = min(UInt64(statistics.purgeable_count), internalPages)

        return MemoryUsage(
            applicationBytes: min((internalPages - purgeablePages) * pageSize, total),
            wiredBytes: min(UInt64(statistics.wire_count) * pageSize, total),
            compressedBytes: min(UInt64(statistics.compressor_page_count) * pageSize, total),
            cachedBytes: min(
                (UInt64(statistics.external_page_count) + purgeablePages) * pageSize,
                total
            ),
            totalBytes: total
        )
    }
}
