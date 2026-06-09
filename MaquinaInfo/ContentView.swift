//
//  ContentView.swift
//  MaquinaInfo
//
//  Created by Roberto Antonio Berrospe Machin on 6/1/26.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var monitor = HardwareMonitor()
    @State private var selectedItem: SidebarItem? = .dashboard
    @State private var lm = LanguageManager.shared
    @State private var showAboutSheet = false
    @State private var showHelpSheet = false
    
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
                                SettingsView(monitor: monitor, snapshot: snapshot, lm: lm)
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
            .sheet(isPresented: $showAboutSheet) {
                AboutView(lm: lm, isPresented: $showAboutSheet)
            }
            .sheet(isPresented: $showHelpSheet) {
                HelpView(lm: lm, isPresented: $showHelpSheet)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAboutPanel"))) { _ in
                showAboutSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowHelpPanel"))) { _ in
                showHelpSheet = true
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
                HStack {
                    Text(lm.translate("Overview"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: {
                        exportToPDF(snapshot: snapshot)
                    }) {
                        Label(lm.translate("ExportPDF"), systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .help("Export system snapshot report to a PDF file")
                }
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
                            
                            #if !APP_STORE
                            ProgressGaugeRow(
                                title: lm.translate("Device Usage"),
                                value: snapshot.gpu.usage,
                                color: .purple
                            )
                            #endif
                            
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
                                    Text("\(primaryDisk.formattedAvailable) \(lm.translate("FreeStorage"))")
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
                                    Text(lm.translate("AverageCPUTemp"))
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
                        
                        #if !APP_STORE
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
                        #endif
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
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lm.translate("Realtime Activity"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            
                            GeometryReader { geo in
                                let totalWidth = geo.size.width
                                let usedPercent = Double(memory.used) / Double(memory.total)
                                let wiredPercent = Double(memory.wired) / Double(memory.total)
                                let compPercent = Double(memory.compressed) / Double(memory.total)
                                
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.green.opacity(0.8))
                                        .frame(width: totalWidth * wiredPercent)
                                    Rectangle()
                                        .fill(Color.green.opacity(0.5))
                                        .frame(width: max(0, totalWidth * (usedPercent - wiredPercent - compPercent)))
                                    Rectangle()
                                        .fill(Color.teal)
                                        .frame(width: totalWidth * compPercent)
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.15))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .frame(height: 16)
                            
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
                InfoCard(title: lm.translate("Thermal Health"), icon: "gauge.medium", tintColor: .red) {
                    HStack {
                        Text(lm.translate("Thermal Health"))
                        Spacer()
                        ThermalBadge(state: ProcessInfo.processInfo.thermalState, lm: lm)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                #if !APP_STORE
                if !sensors.isEmpty {
                    Text(lm.translate("Sensor Details"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
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
                #endif
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
    let snapshot: SystemSnapshot
    var lm: LanguageManager
    
    var body: some View {
        Form {
            Section(header: Text(lm.translate("Settings Options")).font(.headline).bold()) {
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
            
            Section(header: Text("Actions").font(.headline).bold()) {
                Button(action: {
                    exportToPDF(snapshot: snapshot)
                }) {
                    Label(lm.translate("ExportPDF"), systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.vertical, 6)
            }
            .padding()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Custom About View
struct AboutView: View {
    var lm: LanguageManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                } else {
                    Image(systemName: "cpu")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("MaquinaInfo")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 10)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(lm.translate("Developer") + ":")
                        .fontWeight(.bold)
                        .frame(width: 120, alignment: .leading)
                    Text("Roberto Berrospe")
                }
                
                HStack(alignment: .top) {
                    Text(lm.translate("Company") + ":")
                        .fontWeight(.bold)
                        .frame(width: 120, alignment: .leading)
                    Text("Ruta Internet S.R.L.")
                }
                
                HStack(alignment: .top) {
                    Text(lm.translate("Address") + ":")
                        .fontWeight(.bold)
                        .frame(width: 120, alignment: .leading)
                    Text("18 de Julio 3306\nFlorida, Uruguay")
                        .lineLimit(2)
                }
            }
            .font(.body)
            .padding(.horizontal)
            
            Divider()
            
            Button("OK") {
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .frame(width: 100)
            .padding(.bottom, 10)
        }
        .padding(24)
        .frame(width: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Custom Help View
struct HelpView: View {
    var lm: LanguageManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                }
                Text(lm.translate("HelpTitle"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.top, 10)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HelpItemRow(title: lm.translate("CPU"), description: lm.translate("HelpCPUDesc"), icon: "cpu", color: .blue)
                    HelpItemRow(title: lm.translate("GPU"), description: lm.translate("HelpGPUDesc"), icon: "bolt.fill", color: .purple)
                    HelpItemRow(title: lm.translate("NPU"), description: lm.translate("HelpNPUDesc"), icon: "brain.head.profile", color: .cyan)
                    HelpItemRow(title: lm.translate("Memory"), description: lm.translate("HelpRAMDesc"), icon: "memorychip", color: .green)
                    HelpItemRow(title: lm.translate("Disk"), description: lm.translate("HelpDiskDesc"), icon: "internaldrive", color: .orange)
                    HelpItemRow(title: lm.translate("Sensors"), description: lm.translate("HelpSensorsDesc"), icon: "thermometer.medium", color: .red)
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 350)
            
            Divider()
            
            Button("OK") {
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .frame(width: 100)
            .padding(.bottom, 10)
        }
        .padding(24)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct HelpItemRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 28, alignment: .center)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - PDF Report Generation & Export

@MainActor
func exportToPDF(snapshot: SystemSnapshot) {
    print("[PDF Export] Starting export panel...")
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.pdf]
    savePanel.nameFieldStringValue = "MaquinaInfo_Report.pdf"
    
    let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
        print("[PDF Export] Save response received: \(response.rawValue)")
        if response == .OK, let url = savePanel.url {
            print("[PDF Export] Selected destination URL: \(url.path)")
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
            print("[PDF Export] Temporary URL: \(tempURL.path)")
            
            let reportView = ReportView(snapshot: snapshot)
                .frame(width: 612, height: 792)
            let renderer = ImageRenderer(content: reportView)
            
            // Render to temp URL first
            renderer.render { size, context in
                print("[PDF Export] Starting ImageRenderer rendering with size: \(size)")
                var mediaBox = CGRect(origin: .zero, size: size)
                guard let pdfContext = CGContext(tempURL as CFURL, mediaBox: &mediaBox, nil) else {
                    print("[PDF Export] Failed to create CGContext for temp URL")
                    return
                }
                
                pdfContext.beginPDFPage(nil)
                context(pdfContext)
                pdfContext.endPDFPage()
                pdfContext.closePDF()
                print("[PDF Export] Temporary PDF written successfully.")
            }
            
            // Verify temp file was written
            guard FileManager.default.fileExists(atPath: tempURL.path) else {
                print("[PDF Export] Error: Temp PDF file was not created.")
                return
            }
            
            // Copy temp file to destination
            let accessing = url.startAccessingSecurityScopedResource()
            print("[PDF Export] Accessing security-scoped resource: \(accessing)")
            
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try FileManager.default.copyItem(at: tempURL, to: url)
                print("[PDF Export] PDF report exported successfully to: \(url.path)")
            } catch {
                print("[PDF Export] Failed to copy temp PDF to destination: \(error.localizedDescription)")
            }
            
            if accessing {
                url.stopAccessingSecurityScopedResource()
                print("[PDF Export] Stopped accessing security-scoped resource")
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        } else {
            print("[PDF Export] Save panel cancelled or invalid URL chosen")
        }
    }
    
    if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
        print("[PDF Export] Presenting save panel as sheet modal on key window")
        savePanel.beginSheetModal(for: window, completionHandler: handleResponse)
    } else {
        print("[PDF Export] Fallback: presenting save panel as standalone window")
        savePanel.begin(completionHandler: handleResponse)
    }
}

struct ReportView: View {
    let snapshot: SystemSnapshot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MaquinaInfo - Hardware Report")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Generated on \(snapshot.timestamp.formatted())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "cpu")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            
            Divider()
            
            // Section 1: System Info
            VStack(alignment: .leading, spacing: 10) {
                Text("System Information")
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Processor (CPU)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Model: \(snapshot.cpu.model)")
                        Text("Cores: \(snapshot.cpu.cores)")
                        Text("Architecture: \(snapshot.cpu.architecture)")
                        Text("Average Usage: \(Int(snapshot.cpu.usage * 100))%")
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Graphics (GPU)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Model: \(snapshot.gpu.model)")
                        if let cores = snapshot.gpu.coreCount {
                            Text("Cores: \(cores)")
                        }
                        Text("Device Usage: \(Int(snapshot.gpu.usage * 100))%")
                    }
                }
            }
            
            Divider()
            
            // Section 2: Memory & Storage
            VStack(alignment: .leading, spacing: 10) {
                Text("Memory & Storage")
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Memory (RAM)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Total: \(snapshot.memory.formattedTotal)")
                        Text("Used: \(snapshot.memory.formattedUsed)")
                        Text("Free: \(snapshot.memory.formattedFree)")
                        Text("Wired: \(snapshot.memory.formattedWired)")
                        Text("Compressed: \(snapshot.memory.formattedCompressed)")
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Storage (Disks)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        ForEach(snapshot.disks) { disk in
                            Text("\(disk.name): \(disk.formattedAvailable) free of \(disk.formattedTotal)")
                        }
                    }
                }
            }
            
            Divider()
            
            // Section 3: Thermal Sensors (Only if available)
            if !snapshot.sensors.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Thermal & Sensors")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    
                    let cpuTemps = snapshot.sensors.filter { $0.type == .cpu }
                    if !cpuTemps.isEmpty {
                        Text("CPU Temperatures:")
                            .fontWeight(.bold)
                        let chunked = cpuTemps.chunked(into: 4)
                        ForEach(0..<chunked.count, id: \.self) { rowIdx in
                            HStack(spacing: 20) {
                                ForEach(chunked[rowIdx]) { sensor in
                                    Text("\(sensor.name): \(String(format: "%.1f°C", sensor.value))")
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Divider()
            
            // Footer with User & Company Info
            VStack(alignment: .center, spacing: 4) {
                Text("Licenciado para / Licensed to:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Roberto Berrospe - Ruta Internet S.R.L.")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("18 de Julio 3306, Florida, Uruguay")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(40)
        .frame(width: 612, height: 792)
        .background(Color.white)
        .foregroundColor(.black)
    }
}

// MARK: - Array Chunk Helper
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
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
