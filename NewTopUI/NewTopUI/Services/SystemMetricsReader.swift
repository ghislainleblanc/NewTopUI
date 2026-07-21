import Darwin
import Foundation
import IOKit

final class SystemMetricsReader {
    private var previousCPUTicks: [[UInt64]]?
    private var previousNetworkBytes: (received: UInt64, sent: UInt64)?
    private var previousNetworkTime: TimeInterval?

    func primeCounters() {
        previousCPUTicks = currentCPUTicks()
        previousNetworkBytes = currentNetworkBytes()
        previousNetworkTime = ProcessInfo.processInfo.systemUptime
    }

    func sample() -> SystemMetricsSample {
        let cores = sampleCPU()
        let gpuFraction = sampleGPU()
        let network = sampleNetwork()

        return SystemMetricsSample(
            cores: cores,
            gpuFraction: gpuFraction,
            receivedBytesPerSecond: network.received,
            sentBytesPerSecond: network.sent,
            memory: sampleMemory()
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
