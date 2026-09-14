import Testing
import Foundation
import Darwin
import SystemProbe
@testable import ResourceCore

@Test func nativeCPUUnitsMatchThePOSIXProcessClock() throws {
    // Use a measurable amount of actual CPU time, then compare independent APIs.
    let start = clock()
    while clock() - start < CLOCKS_PER_SEC / 5 {}
    var pointer: UnsafeMutablePointer<ARMProcess>?
    let count = arm_processes(&pointer)
    defer { arm_free_processes(pointer) }
    #expect(count > 0)
    guard let pointer, count > 0 else { return }
    let own = UnsafeBufferPointer(start: pointer, count: Int(count)).first { $0.pid == getpid() }
    let expectedSeconds = Double(clock()) / Double(CLOCKS_PER_SEC)
    let measuredSeconds = Double(try #require(own).cpu_ns) / 1_000_000_000
    #expect(measuredSeconds > expectedSeconds * 0.8)
    #expect(measuredSeconds < expectedSeconds * 1.2)
}

@Test func childrenInheritButRecognizedToolsOverrideParent() {
    let samples = [
        ProcessSample(pid: 1, name: "Codex"),
        ProcessSample(pid: 2, parentPID: 1, name: "node"),
        ProcessSample(pid: 3, parentPID: 2, name: "python"),
        ProcessSample(pid: 4, parentPID: 1, name: "claude"),
        ProcessSample(pid: 5, name: "node", path: "/tmp/codex-project/node"),
        ProcessSample(pid: 6, name: "Helper", path: "/Applications/Cursor.app/Contents/Frameworks/Helper"),
        ProcessSample(pid: 7, parentPID: 8, name: "a"),
        ProcessSample(pid: 8, parentPID: 7, name: "b")
    ]
    let result = Classifier.categories(for: samples)
    #expect(result[1] == .codex)
    #expect(result[2] == .codex)
    #expect(result[3] == .codex)
    #expect(result[4] == .claude)
    #expect(result[5] == .other)
    #expect(result[6] == .cursor)
    #expect(result[7] == .other)
}

@Test func normalizeCPUAndSumMemoryWithoutDoubleCountingChildren() {
    var aggregator = Aggregator()
    _ = aggregator.update([
        ProcessSample(pid: 1, name: "codex", cpuNanoseconds: 0, memoryBytes: 100),
        ProcessSample(pid: 2, parentPID: 1, name: "node", cpuNanoseconds: 0, memoryBytes: 200)
    ], time: 10, cores: 8)
    let groups = aggregator.update([
        ProcessSample(pid: 1, name: "codex", cpuNanoseconds: 2_000_000_000, memoryBytes: 150),
        ProcessSample(pid: 2, parentPID: 1, name: "node", cpuNanoseconds: 2_000_000_000, memoryBytes: 250)
    ], time: 12, cores: 8)
    #expect(groups[0].cpuPercent == 25)
    #expect(groups[0].memoryBytes == 400)
    #expect(groups[0].processes.count == 2)
    #expect(groups[3].memoryBytes == 0)
}

@Test func recycledPIDAndUnreadableCountersAreNotReportedAsZero() {
    var aggregator = Aggregator()
    _ = aggregator.update([ProcessSample(pid: 1, name: "codex", startTime: 1, cpuNanoseconds: 100)], time: 10, cores: 8)
    let groups = aggregator.update([
        ProcessSample(pid: 1, name: "codex", startTime: 2, cpuNanoseconds: 200),
        ProcessSample(pid: 2, name: "claude", cpuNanoseconds: nil, memoryBytes: nil)
    ], time: 12, cores: 8)
    #expect(groups[0].processes[0].cpuPercent == nil)
    #expect(groups[2].unreadableCount == 1)
    #expect(!groups[2].hasCPU)
    #expect(!groups[2].hasMemory)
}

@Test func countersDoNotUnderflowAndExitedProcessesDisappear() {
    var aggregator = Aggregator()
    _ = aggregator.update([
        ProcessSample(pid: 1, name: "codex", cpuNanoseconds: 1000),
        ProcessSample(pid: 2, name: "cursor", memoryBytes: 500)
    ], time: 10, cores: 8)
    let groups = aggregator.update([ProcessSample(pid: 1, name: "codex", cpuNanoseconds: 500)], time: 12, cores: 8)
    #expect(groups[0].processes[0].cpuPercent == nil)
    #expect(groups[1].processes.isEmpty)
}

@Test func liveSamplerReadsPhysicalMemoryAndOwnFootprint() async throws {
    let sampler = Sampler()
    let first = await sampler.sample()
    #expect(first.error == nil)
    #expect(first.physicalMemory > 0)
    #expect(first.usedMemory != nil)
    let own = first.categories.flatMap(\.processes).first { $0.pid == ProcessInfo.processInfo.processIdentifier }
    #expect(own != nil)
    #expect((own?.memoryBytes ?? 0) > 0)
    try await Task.sleep(for: .milliseconds(250))
    let second = await sampler.sample()
    #expect(second.systemCPU != nil)
    #expect((second.systemCPU ?? -1) >= 0 && (second.systemCPU ?? 101) <= 100)
}
