import Foundation
import IOKit
import Darwin
import Metal

/// A service responsible for querying macOS kernel APIs to retrieve hardware statistics.
final class HardwareService {
    
    static let shared = HardwareService()
    
    private init() {
        setupIOHIDFunctions()
    }
    
    // State for CPU load calculation
    private var previousCpuTicks: [UInt32]?
    private var lastSampleTime: Date?
    
    // IOHID Private API Dynamic Bindings
    #if !APP_STORE
    private typealias IOHIDEventSystemClientRef = AnyObject
    private typealias IOHIDServiceClientRef = AnyObject
    private typealias IOHIDEventRef = AnyObject
    
    private var clientCreate: (@convention(c) (CFAllocator?) -> IOHIDEventSystemClientRef?)?
    private var clientSetMatching: (@convention(c) (IOHIDEventSystemClientRef, CFDictionary) -> UInt8)?
    private var clientCopyServices: (@convention(c) (IOHIDEventSystemClientRef) -> CFArray?)?
    private var serviceCopyProperty: (@convention(c) (IOHIDServiceClientRef, CFString) -> CFTypeRef?)?
    private var serviceCopyEvent: (@convention(c) (IOHIDServiceClientRef, UInt32, UInt32, UInt32) -> IOHIDEventRef?)?
    private var eventGetFloatValue: (@convention(c) (IOHIDEventRef, UInt32) -> Double)?
    #endif
    
    /// Dynamically load HID symbols from the IOKit framework to query temperatures.
    private func setupIOHIDFunctions() {
        #if !APP_STORE
        if let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) {
            if let symCreate = dlsym(handle, "IOHIDEventSystemClientCreate") {
                clientCreate = unsafeBitCast(symCreate, to: (@convention(c) (CFAllocator?) -> IOHIDEventSystemClientRef?).self)
            }
            if let symSetMatching = dlsym(handle, "IOHIDEventSystemClientSetMatching") {
                clientSetMatching = unsafeBitCast(symSetMatching, to: (@convention(c) (IOHIDEventSystemClientRef, CFDictionary) -> UInt8).self)
            }
            if let symCopyServices = dlsym(handle, "IOHIDEventSystemClientCopyServices") {
                clientCopyServices = unsafeBitCast(symCopyServices, to: (@convention(c) (IOHIDEventSystemClientRef) -> CFArray?).self)
            }
            if let symCopyProperty = dlsym(handle, "IOHIDServiceClientCopyProperty") {
                serviceCopyProperty = unsafeBitCast(symCopyProperty, to: (@convention(c) (IOHIDServiceClientRef, CFString) -> CFTypeRef?).self)
            }
            if let symCopyEvent = dlsym(handle, "IOHIDServiceClientCopyEvent") {
                serviceCopyEvent = unsafeBitCast(symCopyEvent, to: (@convention(c) (IOHIDServiceClientRef, UInt32, UInt32, UInt32) -> IOHIDEventRef?).self)
            }
            if let symGetFloat = dlsym(handle, "IOHIDEventGetFloatValue") {
                eventGetFloatValue = unsafeBitCast(symGetFloat, to: (@convention(c) (IOHIDEventRef, UInt32) -> Double).self)
            }
        }
        #endif
    }
    
    /// Checks if the current machine is running Apple Silicon.
    func isAppleSilicon() -> Bool {
        var isArm64: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm64", &isArm64, &size, nil, 0)
        return isArm64 == 1
    }
    
    /// Fetches the current CPU information including per-core usage.
    func fetchCPUInfo() -> CPUInfo {
        let model = getSysctlString(name: "machdep.cpu.brand_string") ?? "Apple Silicon CPU"
        let coresCount = Int(getSysctlInt(name: "hw.physicalcpu"))
        let arch = getSysctlString(name: "hw.machine") ?? "arm64"
        
        var coreUsages: [Double] = []
        
        if let currentTicks = getProcessorTicksRaw() {
            if let previous = previousCpuTicks, lastSampleTime != nil {
                let valuesPerCore = 4 
                
                for i in 0..<coresCount where (i * valuesPerCore + 3) < currentTicks.count && (i * valuesPerCore + 3) < previous.count {
                    let offset = i * valuesPerCore
                    
                    let userDelta = Int64(currentTicks[offset]) - Int64(previous[offset])
                    let sysDelta  = Int64(currentTicks[offset + 1]) - Int64(previous[offset + 1])
                    let idleDelta = Int64(currentTicks[offset + 2]) - Int64(previous[offset + 2])
                    let niceDelta = Int64(currentTicks[offset + 3]) - Int64(previous[offset + 3])
                    
                    let totalDelta = abs(userDelta + sysDelta + idleDelta + niceDelta)
                    
                    if totalDelta > 0 {
                        let usage = Double(abs(userDelta + sysDelta + niceDelta)) / Double(totalDelta)
                        coreUsages.append(max(0, min(1.0, usage)))
                    } else {
                        coreUsages.append(0.0)
                    }
                }
            }
            previousCpuTicks = currentTicks
            lastSampleTime = Date()
        }
        
        if coreUsages.count < coresCount {
            coreUsages = Array(repeating: 0.0, count: coresCount)
        }
        
        let avgUsage = coreUsages.isEmpty ? 0.0 : (coreUsages.reduce(0, +) / Double(coreUsages.count))
        
        return CPUInfo(model: model, cores: coresCount, architecture: arch, usage: avgUsage, perCoreUsage: coreUsages)
    }
    
    /// Fetches the current Memory information.
    func fetchMemoryInfo() -> MemoryInfo {
        let total = ProcessInfo.processInfo.physicalMemory
        
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            let freeVal = total / 4
            let usedVal = total - freeVal
            return MemoryInfo(total: total, used: usedVal, free: freeVal, wired: total / 8, compressed: total / 8)
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        
        // Memory Used = Active + Wired + Compressed
        let used = active + wired + compressed
        let freeMem = total > used ? total - used : free
        
        return MemoryInfo(total: total, used: used, free: freeMem, wired: wired, compressed: compressed)
    }
    
    /// Fetches information about mounted disks.
    func fetchDiskInfo() -> [DiskInfo] {
        let fileManager = FileManager.default
        let keysToFetch: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        
        guard let volumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: Array(keysToFetch)) else {
            return []
        }
        
        return volumes.compactMap { url in
            let resourceValues = try? url.resourceValues(forKeys: keysToFetch)
            let name = resourceValues?.volumeName ?? url.lastPathComponent
            
            guard let totalRaw = resourceValues?.volumeTotalCapacity,
                  let availableRaw = resourceValues?.volumeAvailableCapacity else {
                return nil
            }
            
            let total = UInt64(totalRaw)
            let available = UInt64(availableRaw)
            
            guard total > 0 else { return nil }
            
            return DiskInfo(
                name: name,
                totalCapacity: total,
                availableCapacity: available
            )
        }
    }
    
    /// Fetches GPU information using IOKit or Metal.
    func fetchGPUInfo() -> GPUInfo {
        #if APP_STORE
        // App Store Safe: Use public Metal API to get GPU model name
        let model = MTLCreateSystemDefaultDevice()?.name ?? "Apple M-Series GPU"
        return GPUInfo(model: model, usage: 0.0, coreCount: nil, rendererUsage: nil, tilerUsage: nil)
        #else
        // Direct Distribution: Query detailed IOKit properties
        let serviceMatching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, serviceMatching, &iterator)
        
        var model = "Apple M-Series GPU"
        var coreCount: Int? = nil
        var usage = 0.0
        var rendererUsage: Double? = nil
        var tilerUsage: Double? = nil
        
        if result == kIOReturnSuccess {
            let regEntry = IOIteratorNext(iterator)
            if regEntry != 0 {
                var properties: Unmanaged<CFMutableDictionary>?
                let kr = IORegistryEntryCreateCFProperties(regEntry, &properties, kCFAllocatorDefault, 0)
                if kr == kIOReturnSuccess, let dict = properties?.takeRetainedValue() as? [String: Any] {
                    // Extract GPU model name
                    if let gpuModel = dict["model"] as? String {
                        model = gpuModel
                    } else if let gpuModelData = dict["model"] as? Data {
                        model = String(decoding: gpuModelData, as: UTF8.self).trimmingCharacters(in: .controlCharacters)
                    }
                    
                    // Extract core count
                    if let cores = dict["gpu-core-count"] as? Int {
                        coreCount = cores
                    } else if let coresVal = dict["gpu-core-count"] as? NSNumber {
                        coreCount = coresVal.intValue
                    }
                    
                    // Extract usage statistics
                    if let perfStats = dict["PerformanceStatistics"] as? [String: Any] {
                        if let devUtil = perfStats["Device Utilization %"] as? Int {
                            usage = Double(devUtil) / 100.0
                        } else if let devUtilNum = perfStats["Device Utilization %"] as? NSNumber {
                            usage = devUtilNum.doubleValue / 100.0
                        }
                        
                        if let rendUtil = perfStats["Renderer Utilization %"] as? Int {
                            rendererUsage = Double(rendUtil) / 100.0
                        } else if let rendUtilNum = perfStats["Renderer Utilization %"] as? NSNumber {
                            rendererUsage = rendUtilNum.doubleValue / 100.0
                        }
                        
                        if let tileUtil = perfStats["Tiler Utilization %"] as? Int {
                            tilerUsage = Double(tileUtil) / 100.0
                        } else if let tileUtilNum = perfStats["Tiler Utilization %"] as? NSNumber {
                            tilerUsage = tileUtilNum.doubleValue / 100.0
                        }
                    }
                }
                IOObjectRelease(regEntry)
            }
            IOObjectRelease(iterator)
        }
        
        return GPUInfo(model: model, usage: usage, coreCount: coreCount, rendererUsage: rendererUsage, tilerUsage: tilerUsage)
        #endif
    }
    
    /// Fetches NPU (Neural Engine) information.
    func fetchNPUInfo() -> NPUInfo {
        #if APP_STORE
        // App Store Safe: Return generic info since IOKit private class matching is restricted
        return NPUInfo(model: "Apple Neural Engine", coreCount: 16, architecture: "Apple Silicon ANE", version: nil)
        #else
        // Direct Distribution: Query private IOKit driver properties
        let serviceMatching = IOServiceMatching("H11ANEIn")
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, serviceMatching, &iterator)
        
        var model: String? = "Apple Neural Engine"
        var coreCount: Int? = nil
        var architecture: String? = nil
        var version: Int? = nil
        
        if result == kIOReturnSuccess {
            let regEntry = IOIteratorNext(iterator)
            if regEntry != 0 {
                var properties: Unmanaged<CFMutableDictionary>?
                let kr = IORegistryEntryCreateCFProperties(regEntry, &properties, kCFAllocatorDefault, 0)
                if kr == kIOReturnSuccess, let dict = properties?.takeRetainedValue() as? [String: Any] {
                    if let deviceProps = dict["DeviceProperties"] as? [String: Any] {
                        if let cores = deviceProps["ANEDevicePropertyNumANECores"] as? Int {
                            coreCount = cores
                        } else if let coresNum = deviceProps["ANEDevicePropertyNumANECores"] as? NSNumber {
                            coreCount = coresNum.intValue
                        }
                        
                        if let arch = deviceProps["ANEDevicePropertyTypeANEArchitectureTypeStr"] as? String {
                            architecture = arch
                        }
                        
                        if let ver = deviceProps["ANEDevicePropertyANEVersion"] as? Int {
                            version = ver
                        } else if let verNum = deviceProps["ANEDevicePropertyANEVersion"] as? NSNumber {
                            version = verNum.intValue
                        }
                        
                        if let archStr = architecture {
                            model = "Apple Neural Engine (\(archStr))"
                        }
                    }
                }
                IOObjectRelease(regEntry)
            }
            IOObjectRelease(iterator)
        }
        
        return NPUInfo(model: model, coreCount: coreCount, architecture: architecture, version: version)
        #endif
    }
    
    /// Fetches active temperature sensors.
    func fetchSensors() -> [SensorInfo] {
        #if APP_STORE
        // App Store Safe: Sandbox limits direct connection to HID Event System for sensors
        return []
        #else
        // Direct Distribution: Query private IOHID services
        var sensorList: [SensorInfo] = []
        
        guard let create = clientCreate,
              let setMatching = clientSetMatching,
              let copyServices = clientCopyServices,
              let copyProperty = serviceCopyProperty,
              let copyEvent = serviceCopyEvent,
              let getFloat = eventGetFloatValue else {
            return []
        }
        
        guard let client = create(kCFAllocatorDefault) else {
            return []
        }
        
        let matchingDict: [String: Any] = [
            "PrimaryUsagePage": 0xff00,
            "PrimaryUsage": 5
        ]
        
        _ = setMatching(client, matchingDict as CFDictionary)
        
        guard let services = copyServices(client) as? [IOHIDServiceClientRef] else {
            return []
        }
        
        for service in services {
            if let name = copyProperty(service, "Product" as CFString) as? String {
                if let event = copyEvent(service, 15, 0, 0) {
                    let temp = getFloat(event, 983040)
                    
                    // Sanity check temperature value
                    guard temp > 0.0 && temp < 150.0 else { continue }
                    
                    let type: SensorType
                    let cleanName: String
                    
                    if name.contains("tdie") || name.contains("DEV") || name.contains("tdev") || name.contains("die") {
                        type = .cpu
                        cleanName = name.replacingOccurrences(of: "PMU ", with: "")
                    } else if name.contains("gpu") || name.contains("GPU") {
                        type = .gpu
                        cleanName = name
                    } else if name.contains("battery") || name.contains("gas gauge") {
                        type = .battery
                        cleanName = "Battery"
                    } else if name.contains("NAND") || name.contains("disk") || name.contains("storage") {
                        type = .nand
                        cleanName = "SSD Storage"
                    } else {
                        type = .other
                        cleanName = name
                    }
                    
                    sensorList.append(SensorInfo(name: cleanName, value: temp, type: type))
                }
            }
        }
        
        return sensorList.sorted { $0.name < $1.name }
        #endif
    }
    
    // MARK: - Private Helpers
    
    /// Safely retrieves raw CPU tick counts from the Mach kernel.
    private func getProcessorTicksRaw() -> [UInt32]? {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCpuInfo)
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return nil
        }
        
        var ticks: [UInt32] = []
        ticks.reserveCapacity(Int(numCpuInfo))
        
        for i in 0..<Int(numCpuInfo) {
            ticks.append(UInt32(cpuInfo[i]))
        }
        
        let size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        
        return ticks
    }
    
    private func getSysctlString(name: String) -> String? {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var response = [CChar](repeating: 0, count: size)
        if sysctlbyname(name, &response, &size, nil, 0) == 0 {
            return String(cString: response)
        }
        return nil
    }
    
    private func getSysctlInt(name: String) -> Int32 {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }
}
