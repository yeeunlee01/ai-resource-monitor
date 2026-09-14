import SwiftUI
import AppKit
import ResourceCore

@MainActor
final class MonitorModel: ObservableObject {
    @Published var snapshot = Snapshot.empty
    @Published var history: [Double] = []
    private let sampler = Sampler()
    private var task: Task<Void, Never>?
    init(live: Bool = true) {
        guard live else { return }
        task = Task { [weak self, sampler] in
            while !Task.isCancelled {
                let next = await sampler.sample()
                guard let self else { return }
                self.snapshot = next
                if let value = next.systemCPU { self.history = Array((self.history + [value]).suffix(30)) }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}

enum Metric: String, CaseIterable {
    case cpu = "CPU", memory = "메모리"
    var symbol: String { self == .cpu ? "cpu" : "memorychip" }
}

extension ToolCategory {
    var color: Color {
        switch self {
        case .codex: Color(red: 0.17, green: 0.45, blue: 0.34)
        case .cursor: Color(red: 0.34, green: 0.38, blue: 0.69)
        case .claude: Color(red: 0.76, green: 0.40, blue: 0.27)
        case .other: Color(red: 0.49, green: 0.49, blue: 0.46)
        }
    }
    var symbol: String {
        switch self {
        case .codex: "terminal"
        case .cursor: "cursorarrow"
        case .claude: "asterisk"
        case .other: "square.grid.2x2"
        }
    }
}

func bytes(_ value: UInt64) -> String {
    // Match macOS's conventional binary memory units (displayed as GB / MB).
    let gb = Double(value) / 1_073_741_824
    return gb >= 1 ? String(format: "%.2f GB", gb) : String(format: "%.0f MB", Double(value) / 1_048_576)
}
func percent(_ value: Double?) -> String { value.map { String(format: "%.1f%%", $0) } ?? "—" }

struct Dashboard: View {
    @ObservedObject var model: MonitorModel
    @State var metric: Metric = .cpu
    @State private var expanded: ToolCategory?
    var preview = false
    private let ink = Color(red: 0.16, green: 0.19, blue: 0.18)
    private let muted = Color(red: 0.47, green: 0.49, blue: 0.46)
    private let paper = Color(red: 0.96, green: 0.96, blue: 0.94)
    private var snapshot: Snapshot { model.snapshot }
    private var unreadable: Int { snapshot.categories.reduce(0) { $0 + $1.unreadableCount } }
    private var total: String {
        metric == .cpu ? percent(snapshot.systemCPU) : snapshot.usedMemory.map(bytes) ?? "—"
    }
    private var fraction: Double {
        metric == .cpu ? (snapshot.systemCPU ?? 0) / 100 : Double(snapshot.usedMemory ?? 0) / Double(max(1, snapshot.physicalMemory))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 11) {
                Image(systemName: "waveform.path").font(.system(size: 20, weight: .semibold))
                    .frame(width: 38, height: 38).background(ink).foregroundStyle(paper).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI Monitor").font(.system(size: 18, weight: .semibold))
                    Text("내 Mac의 작은 사용량 창").font(.system(size: 11)).foregroundStyle(muted)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(preview ? Color.orange : ToolCategory.codex.color).frame(width: 5, height: 5)
                    Text(preview ? "예시 데이터" : "실시간").font(.system(size: 10, weight: .medium))
                }.foregroundStyle(muted)
            }
            HStack(spacing: 4) {
                ForEach(Metric.allCases, id: \.self) { item in
                    Button { metric = item } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(metric == item ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .shadow(color: .black.opacity(metric == item ? 0.04 : 0), radius: 3, y: 1)
                    }.buttonStyle(.plain).accessibilityAddTraits(metric == item ? .isSelected : [])
                }
            }.padding(4).background(ink.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(metric == .cpu ? "전체 CPU 사용량" : "전체 메모리 사용량 · 추정").font(.system(size: 12)).foregroundStyle(muted)
                    Spacer()
                    Text(metric == .cpu ? "\(ProcessInfo.processInfo.activeProcessorCount)코어" : "\(bytes(snapshot.physicalMemory)) 장착")
                        .font(.system(size: 10)).foregroundStyle(muted)
                }
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(total).font(.system(size: 40, weight: .medium, design: .rounded)).monospacedDigit()
                    Spacer()
                    if metric == .cpu {
                        Sparkline(values: model.history).stroke(ToolCategory.codex.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(width: 112, height: 34).accessibilityLabel("최근 1분 CPU 추이")
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ink.opacity(0.06))
                        Capsule().fill(ToolCategory.codex.color).frame(width: geo.size.width * min(1, max(0, fraction)))
                    }
                }.frame(height: 6)
                Text(metric == .cpu ? "Mac 전체 성능을 100%로 표시해요." : "스왑 \(snapshot.swapUsed.map(bytes) ?? "—") · 앱별 수치는 아래에서 확인하세요.")
                    .font(.system(size: 10)).foregroundStyle(muted)
            }.padding(19).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 17))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("카테고리별 사용량").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("클릭해서 자세히").font(.system(size: 10)).foregroundStyle(muted)
                }.padding(.horizontal, 2)
                if preview || expanded == nil {
                    categoryList
                } else {
                    ScrollView { categoryList }.frame(height: 280)
                }
                Text(metric == .cpu
                     ? "앱과 하위 프로세스를 합산해요. 시스템 전체와는 차이가 있을 수 있어요."
                     : "앱별 메모리 점유량을 합산해요. 압축·스왑·공유 메모리 때문에 전체 수치와 다를 수 있어요.")
                    .font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                if unreadable > 0 {
                    Label("권한 등으로 읽지 못한 프로세스 \(unreadable)개는 합계에서 제외했어요.", systemImage: "info.circle")
                        .font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                }
                if let error = snapshot.error { Text(error).font(.system(size: 11)).foregroundStyle(.orange) }
            }
            HStack {
                Text("2초마다 업데이트").font(.system(size: 10)).foregroundStyle(muted)
                Spacer()
                Button("종료") { NSApp.terminate(nil) }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(muted)
            }
        }
        .padding(24).frame(width: 420).background(paper).foregroundStyle(ink)
        .preferredColorScheme(.light)
    }

    private var categoryList: some View {
        VStack(spacing: 8) {
            ForEach(snapshot.categories) { group in categoryRow(group) }
        }
    }

    @ViewBuilder private func categoryRow(_ group: CategoryUsage) -> some View {
        let available = metric == .cpu ? group.hasCPU : group.hasMemory
        let value = metric == .cpu ? percent(available ? group.cpuPercent : nil) : (available ? bytes(group.memoryBytes) : "—")
        let ratio = metric == .cpu ? group.cpuPercent / 100 : Double(group.memoryBytes) / Double(max(1, snapshot.physicalMemory))
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.18)) { expanded = expanded == group.category ? nil : group.category } } label: {
                HStack(spacing: 12) {
                    Image(systemName: group.category.symbol).font(.system(size: 17, weight: .medium))
                        .frame(width: 36, height: 36).foregroundStyle(group.category.color)
                        .background(group.category.color.opacity(0.09)).clipShape(RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(group.category.rawValue).font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                        }
                        HStack {
                            Text(group.processes.isEmpty ? "실행 중인 프로세스 없음" : "프로세스 \(group.processes.count)개\(group.unreadableCount > 0 ? " · 일부 제외" : "")")
                                .font(.system(size: 10)).foregroundStyle(muted)
                            Spacer()
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(group.category.color.opacity(0.08))
                                    Capsule().fill(group.category.color.opacity(0.7)).frame(width: geo.size.width * min(1, max(0, ratio)))
                                }
                            }.frame(width: 68, height: 4)
                        }
                    }
                    Image(systemName: expanded == group.category ? "chevron.up" : "chevron.down").font(.system(size: 8, weight: .semibold)).foregroundStyle(muted)
                }.padding(13).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(group.category.rawValue), \(value), 프로세스 \(group.processes.count)개")
            if expanded == group.category {
                Divider().padding(.horizontal, 13)
                if group.processes.isEmpty {
                    Text("실행 중인 프로세스가 없어요.").font(.system(size: 11)).foregroundStyle(muted).padding(15)
                } else {
                    VStack(spacing: 10) {
                        ForEach(group.processes.sorted { a, b in metric == .cpu ? (a.cpuPercent ?? -1) > (b.cpuPercent ?? -1) : (a.memoryBytes ?? 0) > (b.memoryBytes ?? 0) }) { process in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(process.name).font(.system(size: 10)).lineLimit(1)
                                    Text("PID \(process.pid)").font(.system(size: 9)).foregroundStyle(muted)
                                }
                                Spacer()
                                Text(metric == .cpu ? percent(process.cpuPercent) : process.memoryBytes.map(bytes) ?? "읽기 불가")
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
                            }
                        }
                    }.padding(14)
                }
            }
        }.background(Color.white.opacity(0.72)).clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

struct Sparkline: Shape {
    var values: [Double]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: rect.width * Double(index) / Double(values.count - 1), y: rect.height * (1 - min(100, max(0, value)) / 100))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A first window makes the app immediately discoverable. Closing it leaves the menu item running.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 710), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "AI Monitor"
        window.contentView = NSHostingView(rootView: Dashboard(model: MonitorApp.model))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

@main
struct MonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @MainActor static let model = MonitorModel()
    init() {
        if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > index + 1 {
            let model = MonitorModel(live: false)
            var aggregator = Aggregator()
            let baseline = [
                ProcessSample(pid: 101, name: "codex", cpuNanoseconds: 0, memoryBytes: 3_280_000_000),
                ProcessSample(pid: 102, name: "Cursor", cpuNanoseconds: 0, memoryBytes: 1_860_000_000),
                ProcessSample(pid: 103, name: "claude", cpuNanoseconds: 0, memoryBytes: 740_000_000),
                ProcessSample(pid: 104, name: "Other apps", cpuNanoseconds: 0, memoryBytes: 8_420_000_000)
            ]
            _ = aggregator.update(baseline, time: 0, cores: 8)
            let values: [UInt64] = [2_688_000_000, 1_024_000_000, 192_000_000, 1_568_000_000]
            let next = baseline.enumerated().map { index, process in
                ProcessSample(pid: process.pid, name: process.name, cpuNanoseconds: values[index], memoryBytes: process.memoryBytes)
            }
            model.snapshot.categories = aggregator.update(next, time: 2, cores: 8)
            model.snapshot.systemCPU = 34.2
            model.snapshot.physicalMemory = 24 * 1_073_741_824
            model.snapshot.usedMemory = 14_300_000_000
            model.snapshot.swapUsed = 1_200_000_000
            model.history = [13, 15, 14, 21, 19, 26, 20, 22, 18, 34, 29, 41, 32, 37, 34]
            let metric: Metric = CommandLine.arguments.contains("--memory") ? .memory : .cpu
            let renderer = ImageRenderer(content: Dashboard(model: model, metric: metric, preview: true).fixedSize())
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
            do { try data.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0) }
            catch { print(error); exit(1) }
        }
    }
    var body: some Scene {
        MenuBarExtra("AI Monitor", systemImage: "waveform.path") {
            Dashboard(model: Self.model)
        }.menuBarExtraStyle(.window)
    }
}
