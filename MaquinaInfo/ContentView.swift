//
//  ContentView.swift
//  MaquinaInfo
//
//  Created by Roberto Antonio Berrospe Machin on 6/1/26.
//

import SwiftUI

struct ContentView: View {
    @State private var monitor = HardwareMonitor()
    @State private var selectedItem: SidebarItem? = .dashboard
    @State private var lm = LanguageManager.shared
    
    // Check compatibility at launch
    private let isSilicon = HardwareService.shared.isAppleSilicon()
    
    var body: some View {
        if !isSilicon {
            UnsupportedPlatformView(lm: lm)
        } else {
            NavigationSplitView {
                List(SidebarItem.allCases, selection: $selectedItem) { item in
                    NavigationLink(value: item) {
                        Label(item.localizedName, systemImage: item.icon)
                            .padding(.vertical, 4)
                    }
                }
                .navigationTitle("MaquinaInfo")
                .frame(minWidth: 200)
            } detail: {
                ZStack {
                    // Modern dark aesthetic background
                    LinearGradient(
                        colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    Group {
                        if let snapshot = monitor.snapshot {
                            switch selectedItem {
                            case .dashboard:
                                DashboardView(snapshot: snapshot, lm: lm)
                            case .cpu:
                                CPUDetailView(cpu: snapshot.cpu, lm: lm)
                            case .memory:
                                MemoryDetailView(memory: snapshot.memory, lm: lm)
                            case .disk:
                                DiskDetailView(disks: snapshot.disks, lm: lm)
                            case .gpu:
                                GPUDetailView(gpu: snapshot.gpu, lm: lm)
                            case .npu:
                                NPUDetailView(npu: snapshot.npu, lm: lm)
                            case .sensors:
                                SensorsDetailView(sensors: snapshot.sensors, lm: lm)
                            case .settings:
                                SettingsView(monitor: monitor, lm: lm)
                            case .none:
                                Text(lm.translate("Menu"))
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .controlSize(.large)
                                Text(lm.translate("Initializing"))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle(selectedItem?.localizedName ?? "MaquinaInfo")
            }
            .onAppear {
                monitor.start()
            }
            .onDisappear {
                monitor.stop()
            }
        }
    }
}

// MARK: - Unsupported Platform Block View
struct UnsupportedPlatformView: View {
    var lm: LanguageManager
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "cpu.badge.exclamationmark")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text(lm.translate("Apple Silicon Only"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(lm.translate("Intel Error"))
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)
                .padding(.horizontal)
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("OK")
                    .fontWeight(.semibold)
                    .frame(width: 120, height: 32)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding()
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    let snapshot: SystemSnapshot
    var lm: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(lm.translate("Overview"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    // CPU Card
                    InfoCard(title: lm.translate("CPU"), icon: "cpu", tintColor: .blue) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(snapshot.cpu.model)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            ProgressGaugeRow(
                                title: lm.translate("Average Usage"),
                                value: snapshot.cpu.usage,
                                color: .blue
                            )
                            
                            HStack {
                                Text("\(snapshot.cpu.cores) \(lm.translate("Cores"))")
                                Spacer()
                                Text(snapshot.cpu.architecture)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .clipShape(Capsule())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    // GPU Card
                    InfoCard(title: lm.translate("GPU"), icon: "bolt.fill", tintColor: .purple) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(snapshot.gpu.model)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            ProgressGaugeRow(
                                title: lm.translate("Device Usage"),
                                value: snapshot.gpu.usage,
                                color: .purple
                            )
                            
                            if let cores = snapshot.gpu.coreCount {
                                Text("\(cores) \(lm.translate("Cores"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Memory Card
                    InfoCard(title: lm.translate("Memory"), icon: "memorychip", tintColor: .green) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(snapshot.memory.formattedUsed)
                                    .fontWeight(.bold)
                                Text("/")
                                    .foregroundStyle(.tertiary)
                                Text(snapshot.memory.formattedTotal)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            
                            ProgressGaugeRow(
                                title: lm.translate("App Memory"),
                                value: snapshot.memory.usagePercentage,
                                color: .green
                            )
                            
                            Text("\(Int(snapshot.memory.usagePercentage * 100))% \(lm.translate("Used"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Storage Card
                    if let primaryDisk = snapshot.disks.first {
                        InfoCard(title: lm.translate("Disk"), icon: "internaldrive", tintColor: .orange) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(primaryDisk.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                ProgressGaugeRow(
                                    title: lm.translate("Main Storage"),
                                    value: primaryDisk.usagePercentage,
                                    color: .orange
                                )
                                
                                HStack {
                                    Text("\(primaryDisk.formattedAvailable) \(lm.translate("Free"))")
                                    Spacer()
                                    Text(primaryDisk.formattedTotal)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Thermal Card
                    InfoCard(
                        title: lm.translate("Sensors"),
                        icon: "thermometer.medium",
                        tintColor: .red
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(lm.translate("Thermal Health"))
                                Spacer()
                                ThermalBadge(state: ProcessInfo.processInfo.thermalState, lm: lm)
                            }
                            
                            // Average cpu temp if available
                            let cpuTemps = snapshot.sensors.filter { $0.type == .cpu }
                            if !cpuTemps.isEmpty {
                                let avgTemp = cpuTemps.map(\.value).reduce(0, +) / Double(cpuTemps.count)
                                HStack {
                                    Text(lm.translate("Average Usage") + " Temp")
                                    Spacer()
                                    Text(String(format: "%.1f °C", avgTemp))
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundStyle(tempColor(avgTemp))
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func tempColor(_ temp: Double) -> Color {
        if temp < 45 { return .green }
        if temp < 75 { return .yellow }
        if temp < 90 { return .orange }
        return .red
    }
}

// MARK: - CPU Detail View
struct CPUDetailView: View {
    let cpu: CPUInfo
    var lm: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Info Card
                InfoCard(title: lm.translate("Hardware Info"), icon: "cpu", tintColor: .blue) {
                    VStack(spacing: 12) {
                        DetailRow(label: lm.translate("Model"), value: cpu.model)
                        DetailRow(label: lm.translate("Cores"), value: "\(cpu.cores)")
                        DetailRow(label: lm.translate("Architecture"), value: cpu.architecture)
                        ProgressGaugeRow(
                            title: lm.translate("Average Usage"),
                            value: cpu.usage,
                            color: .blue
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Real-time Cores Grid
                Text(lm.translate("Realtime Activity"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(0..<cpu.cores, id: \.self) { idx in
                        let coreLoad = idx < cpu.perCoreUsage.count ? cpu.perCoreUsage[idx] : 0.0
                        VStack(spacing: 8) {
                            Text("Core \(idx + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            
                            // Visual load indicator (donut ring style)
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(coreLoad))
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.3), value: coreLoad)
                                
                                Text("\(Int(coreLoad * 100))%")
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.bold)
                            }
                            .frame(width: 60, height: 60)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: .black.opacity(0.05), radius: 2)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - GPU Detail View
struct GPUDetailView: View {
    let gpu: GPUInfo
    var lm: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InfoCard(title: lm.translate("GPU"), icon: "bolt.fill", tintColor: .purple) {
                    VStack(spacing: 12) {
                        DetailRow(label: lm.translate("Graphics Model"), value: gpu.model)
                        if let cores = gpu.coreCount {
                            DetailRow(label: lm.translate("Cores"), value: "\(cores)")
                        }
                        
                        ProgressGaugeRow(
                            title: lm.translate("Device Usage"),
                            value: gpu.usage,
                            color: .purple
                        )
                        
                        if let renderer = gpu.rendererUsage {
                            ProgressGaugeRow(
                                title: lm.translate("Renderer Usage"),
                                value: renderer,
                                color: .indigo
                            )
                        }
                        
                        if let tiler = gpu.tilerUsage {
                            ProgressGaugeRow(
                                title: lm.translate("Tiler Usage"),
                                value: tiler,
                                color: .pink
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
        }
    }
}

// MARK: - NPU Detail View
struct NPUDetailView: View {
    let npu: NPUInfo
    var lm: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InfoCard(title: lm.translate("NPU"), icon: "brain.head.profile", tintColor: .cyan) {
                    VStack(spacing: 12) {
                        DetailRow(label: lm.translate("NPU Model"), value: npu.model ?? "Apple Neural Engine")
                        if let cores = npu.coreCount {
                            DetailRow(label: lm.translate("NPU Cores"), value: "\(cores)")
                        }
                        if let arch = npu.architecture {
                            DetailRow(label: lm.translate("Architecture"), value: arch)
                        }
                        if let ver = npu.version {
                            DetailRow(label: lm.translate("NPU Version"), value: "\(ver)")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
        }
    }
}

// MARK: - Memory Detail View
struct MemoryDetailView: View {
    let memory: MemoryInfo
    var lm: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InfoCard(title: lm.translate("Memory"), icon: "memorychip", tintColor: .green) {
                    VStack(spacing: 14) {
                        DetailRow(label: lm.translate("Total RAM"), value: memory.formattedTotal)
                        DetailRow(label: lm.translate("Used"), value: memory.formattedUsed)
                        DetailRow(label: lm.translate("Free"), value: memory.formattedFree)
                        DetailRow(label: lm.translate("Wired"), value: memory.formattedWired)
                        DetailRow(label: lm.translate("Compressed"), value: memory.formattedCompressed)
                        
                        // Stacked memory bar chart
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lm.translate("Realtime Activity"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            
                            // Visual memory allocation gauge
                            GeometryReader { geo in
                                let totalWidth = geo.size.width
                                let usedPercent = Double(memory.used) / Double(memory.total)
                                let wiredPercent = Double(memory.wired) / Double(memory.total)
                                let compPercent = Double(memory.compressed) / Double(memory.total)
                                
                                HStack(spacing: 0) {
                                    // Wired (dark green)
                                    Rectangle()
                                        .fill(Color.green.opacity(0.8))
                                        .frame(width: totalWidth * wiredPercent)
                                    
                                    // App/Other Used (green)
                                    Rectangle()
                                        .fill(Color.green.opacity(0.5))
                                        .frame(width: max(0, totalWidth * (usedPercent - wiredPercent - compPercent)))
                                    
                                    // Compressed (yellow-green)
                                    Rectangle()
                                        .fill(Color.teal)
                                        .frame(width: totalWidth * compPercent)
                                    
                                    // Free (transparent/grey)
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.15))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .frame(height: 16)
                            
                            // Legend
                            HStack(spacing: 12) {
                                LegendItem(name: lm.translate("Wired"), color: .green.opacity(0.8))
                                LegendItem(name: lm.translate("App Memory"), color: .green.opacity(0.5))
                                LegendItem(name: lm.translate("Compressed"), color: .teal)
                                LegendItem(name: lm.translate("Free"), color: .secondary.opacity(0.15))
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
        }
    }
}

struct LegendItem: View {
    let name: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Storage Detail View
struct DiskDetailView: View {
    let disks: [DiskInfo]
    var lm: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(lm.translate("Disk"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                ForEach(disks) { disk in
                    InfoCard(title: disk.name, icon: "internaldrive", tintColor: .orange) {
                        VStack(spacing: 12) {
                            ProgressGaugeRow(
                                title: lm.translate("Capacity"),
                                value: disk.usagePercentage,
                                color: .orange
                            )
                            
                            HStack {
                                DetailRow(label: lm.translate("Used"), value: ByteCountFormatter.string(fromByteCount: Int64(disk.totalCapacity - disk.availableCapacity), countStyle: .binary))
                                Spacer()
                                DetailRow(label: lm.translate("Available"), value: disk.formattedAvailable)
                            }
                            DetailRow(label: lm.translate("Total RAM"), value: disk.formattedTotal)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Sensors Detail View
struct SensorsDetailView: View {
    let sensors: [SensorInfo]
    var lm: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Thermal pressure card
                InfoCard(title: lm.translate("Thermal Health"), icon: "gauge.medium", tintColor: .red) {
                    HStack {
                        Text(lm.translate("Thermal Health"))
                        Spacer()
                        ThermalBadge(state: ProcessInfo.processInfo.thermalState, lm: lm)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                Text(lm.translate("Sensor Details"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Group by type
                let grouped = Dictionary(grouping: sensors, by: { $0.type })
                
                ForEach(SensorType.allCases, id: \.rawValue) { type in
                    if let list = grouped[type], !list.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lm.translate(type.rawValue))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 1) {
                                ForEach(list) { sensor in
                                    HStack {
                                        Text(sensor.name)
                                            .font(.body)
                                        Spacer()
                                        Text(String(format: "%.1f °C", sensor.value))
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundStyle(tempColor(sensor.value))
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color(NSColor.controlBackgroundColor))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }
    
    private func tempColor(_ temp: Double) -> Color {
        if temp < 45 { return .green }
        if temp < 75 { return .yellow }
        if temp < 90 { return .orange }
        return .red
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Bindable var monitor: HardwareMonitor
    var lm: LanguageManager
    
    var body: some View {
        Form {
            Section(header: Text(lm.translate("Settings Options")).font(.headline).bold()) {
                // Language selection
                Picker(lm.translate("Select Language"), selection: Binding(
                    get: { lm.selectedLanguage },
                    set: { lm.selectedLanguage = $0 }
                )) {
                    ForEach(Language.allCases) { lang in
                        Text(lang.displayName(in: lm.currentLanguageCode)).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .padding(.vertical, 6)
                
                // Refresh rate
                Picker(lm.translate("Refresh Rate"), selection: $monitor.updateInterval) {
                    Text("0.5 \(lm.translate("Seconds"))").tag(0.5)
                    Text("1.0 \(lm.translate("Seconds"))").tag(1.0)
                    Text("2.0 \(lm.translate("Seconds"))").tag(2.0)
                    Text("5.0 \(lm.translate("Seconds"))").tag(5.0)
                }
                .pickerStyle(.radioGroup)
                .padding(.vertical, 6)
            }
            .padding()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Custom Reusable Components

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let tintColor: Color
    let content: Content
    
    init(title: String, icon: String, tintColor: Color = .accentColor, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tintColor = tintColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tintColor)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
    }
}

struct ProgressGaugeRow: View {
    let title: String
    let value: Double // 0.0 to 1.0
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(value), height: 8)
                        .animation(.linear(duration: 0.2), value: value)
                }
            }
            .frame(height: 8)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct ThermalBadge: View {
    let state: ProcessInfo.ThermalState
    var lm: LanguageManager
    
    var body: some View {
        Text(localizedState)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }
    
    private var localizedState: String {
        switch state {
        case .nominal: return lm.translate("Nominal")
        case .fair: return lm.translate("Fair")
        case .serious: return lm.translate("Serious")
        case .critical: return lm.translate("Critical")
        @unknown default: return "Unknown"
        }
    }
    
    private var badgeColor: Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }
}

#Preview {
    ContentView()
}
