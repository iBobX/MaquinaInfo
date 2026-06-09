import Foundation

/// Represents the state of the CPU hardware.
struct CPUInfo {
    let model: String
    let cores: Int
    let architecture: String
    let usage: Double // Total average (0.0 to 1.0)
    let perCoreUsage: [Double] // Usage for each individual core (0.0 to 1.0)
}

/// Represents the state of the system RAM.
struct MemoryInfo {
    let total: UInt64
    let used: UInt64
    let free: UInt64
    let wired: UInt64
    let compressed: UInt64
    let appMemory: UInt64
    let cachedFiles: UInt64
    let swapUsed: UInt64
    let swapTotal: UInt64
    
    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .binary)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .binary)
    }
    
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .binary)
    }
    
    var formattedWired: String {
        ByteCountFormatter.string(fromByteCount: Int64(wired), countStyle: .binary)
    }
    
    var formattedCompressed: String {
        ByteCountFormatter.string(fromByteCount: Int64(compressed), countStyle: .binary)
    }
    
    var formattedAppMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(appMemory), countStyle: .binary)
    }
    
    var formattedCachedFiles: String {
        ByteCountFormatter.string(fromByteCount: Int64(cachedFiles), countStyle: .binary)
    }
    
    var formattedSwapUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(swapUsed), countStyle: .binary)
    }
    
    var formattedSwapTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(swapTotal), countStyle: .binary)
    }
}

/// Represents a single disk partition/volume.
struct DiskInfo: Identifiable {
    let id = UUID()
    let name: String
    let totalCapacity: UInt64
    let availableCapacity: UInt64
    
    var usagePercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(totalCapacity - availableCapacity) / Double(totalCapacity)
    }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalCapacity), countStyle: .binary)
    }
    
    var formattedAvailable: String {
        ByteCountFormatter.string(fromByteCount: Int64(availableCapacity), countStyle: .binary)
    }
}

/// Represents the GPU information.
struct GPUInfo {
    let model: String
    let usage: Double // 0.0 to 1.0
    let coreCount: Int?
    let rendererUsage: Double? // 0.0 to 1.0
    let tilerUsage: Double? // 0.0 to 1.0
}

/// Represents Neural Engine (NPU) information.
struct NPUInfo {
    let model: String?
    let coreCount: Int?
    let architecture: String?
    let version: Int?
    let activity: String?
}

/// Category type for hardware sensors.
enum SensorType: String, CaseIterable, Codable {
    case cpu = "CPU / SoC"
    case gpu = "GPU"
    case battery = "Battery"
    case nand = "Storage"
    case other = "Other"
}

/// Represents a single hardware sensor reading.
struct SensorInfo: Identifiable {
    let id = UUID()
    let name: String
    let value: Double // Temperature in °C
    let type: SensorType
}

/// A comprehensive snapshot of the system hardware.
struct SystemSnapshot {
    let cpu: CPUInfo
    let memory: MemoryInfo
    let disks: [DiskInfo]
    let gpu: GPUInfo
    let npu: NPUInfo
    let sensors: [SensorInfo]
    let timestamp: Date
}
