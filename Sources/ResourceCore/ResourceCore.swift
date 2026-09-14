import Foundation
import SystemProbe

public enum ToolCategory: String, CaseIterable, Sendable, Identifiable {
    case codex = "Codex", cursor = "Cursor", claude = "Claude", other = "그 외"
    public var id: String { rawValue }
}

public struct ProcessSample: Sendable {
    public let pid: Int32
    public let parentPID: Int32
    public let name: String
    public let path: String
    public let startTime: UInt64
    public let cpuNanoseconds: UInt64?
    public let memoryBytes: UInt64?
    public init(pid: Int32, parentPID: Int32 = 0, name: String, path: String = "", startTime: UInt64 = 1, cpuNanoseconds: UInt64? = 0, memoryBytes: UInt64? = 0) {
        self.pid = pid; self.parentPID = parentPID; self.name = name; self.path = path
        self.startTime = startTime; self.cpuNanoseconds = cpuNanoseconds; self.memoryBytes = memoryBytes
    }
}

public enum Classifier {
    public static func direct(_ process: ProcessSample) -> ToolCategory? {
        let name = process.name.lowercased()
        let components = process.path.lowercased().split(separator: "/").map(String.init)
        // Exact app bundles and executable names avoid matching unrelated project folders.
        if components.contains("codex.app") || name == "codex" || name.hasPrefix("codex (") || name == "codex-code-mode-host" { return .codex }
        if components.contains("cursor.app") || name == "cursor" || name.hasPrefix("cursor helper") { return .cursor }
        if components.contains("claude.app") || name == "claude" || name.hasPrefix("claude helper") { return .claude }
        return nil
    }
    public static func categories(for processes: [ProcessSample]) -> [Int32: ToolCategory] {
        let lookup = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [Int32: ToolCategory] = [:]
        for process in processes {
            var current: ProcessSample? = process
            var visited = Set<Int32>()
            var category = ToolCategory.other
            while let candidate = current, visited.insert(candidate.pid).inserted {
                if let direct = direct(candidate) { category = direct; break }
                current = lookup[candidate.parentPID]
            }
            result[process.pid] = category
        }
        return result
    }
}

public struct ProcessUsage: Identifiable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double?
    public let memoryBytes: UInt64?
}

public struct CategoryUsage: Identifiable, Sendable {
    public var id: ToolCategory { category }
    public let category: ToolCategory
    public var processes: [ProcessUsage] = []
    public var cpuPercent: Double { processes.compactMap(\.cpuPercent).reduce(0, +) }
    public var memoryBytes: UInt64 { processes.compactMap(\.memoryBytes).reduce(0, +) }
    public var unreadableCount: Int { processes.filter { $0.memoryBytes == nil }.count }
    public var hasCPU: Bool { processes.isEmpty || processes.contains { $0.cpuPercent != nil } }
    public var hasMemory: Bool { processes.isEmpty || processes.contains { $0.memoryBytes != nil } }
}

public struct Snapshot: Sendable {
    public var categories: [CategoryUsage]
    public var systemCPU: Double?
    public var physicalMemory: UInt64
    public var usedMemory: UInt64?
    public var swapUsed: UInt64?
    public var timestamp: Date
    public var error: String?
    public static var empty: Snapshot { Snapshot(categories: ToolCategory.allCases.map { CategoryUsage(category: $0) }, physicalMemory: ProcessInfo.processInfo.physicalMemory, timestamp: Date()) }
}

public struct Aggregator: Sendable {
    private var previous: [Int32: ProcessSample] = [:]
    private var previousTime: Double?
    public init() {}
    public mutating func update(_ samples: [ProcessSample], time: Double, cores: Int) -> [CategoryUsage] {
        let categories = Classifier.categories(for: samples)
        let elapsed = previousTime.map { time - $0 }
        var groups = Dictionary(uniqueKeysWithValues: ToolCategory.allCases.map { ($0, CategoryUsage(category: $0)) })
        for process in samples {
            var cpu: Double?
            if let elapsed, elapsed > 0, let old = previous[process.pid], old.startTime == process.startTime,
               let now = process.cpuNanoseconds, let before = old.cpuNanoseconds, now >= before {
                cpu = min(100, Double(now - before) / 1_000_000_000 / elapsed / Double(max(1, cores)) * 100)
            }
            let row = ProcessUsage(pid: process.pid, name: process.name.isEmpty ? "PID \(process.pid)" : process.name, cpuPercent: cpu, memoryBytes: process.memoryBytes)
            groups[categories[process.pid] ?? .other]?.processes.append(row)
        }
        previous = Dictionary(samples.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        previousTime = time
        return ToolCategory.allCases.compactMap { groups[$0] }
    }
}

public actor Sampler {
    private var aggregator = Aggregator()
    private var previousCPU: (busy: UInt64, total: UInt64)?
    public init() {}
    public func sample() -> Snapshot {
        var result = Snapshot.empty
        var pointer: UnsafeMutablePointer<ARMProcess>?
        let count = arm_processes(&pointer)
        defer { arm_free_processes(pointer) }
        guard count >= 0, let pointer else { result.error = "프로세스 목록을 읽지 못했어요. 잠시 후 다시 시도합니다."; return result }
        var samples: [ProcessSample] = []
        for index in 0..<Int(count) {
            var raw = pointer[index]
            let name = withUnsafeBytes(of: &raw.name) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
            let path = withUnsafeBytes(of: &raw.path) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
            samples.append(ProcessSample(pid: raw.pid, parentPID: raw.parent_pid, name: name, path: path, startTime: raw.start_time,
                                         cpuNanoseconds: raw.readable == 1 ? raw.cpu_ns : nil, memoryBytes: raw.readable == 1 ? raw.footprint : nil))
        }
        result.categories = aggregator.update(samples, time: ProcessInfo.processInfo.systemUptime, cores: ProcessInfo.processInfo.activeProcessorCount)
        let system = arm_system()
        if system.cpu_valid == 1 {
            if let old = previousCPU, system.cpu_total > old.total, system.cpu_busy >= old.busy {
                result.systemCPU = min(100, Double(system.cpu_busy - old.busy) / Double(system.cpu_total - old.total) * 100)
            }
            previousCPU = (system.cpu_busy, system.cpu_total)
        }
        if system.memory_valid == 1 { result.physicalMemory = system.physical_memory; result.usedMemory = system.used_memory }
        if system.swap_valid == 1 { result.swapUsed = system.swap_used }
        return result
    }
}
