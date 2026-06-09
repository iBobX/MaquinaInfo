import Foundation
import Observation

/// Periodically queries the hardware service to update the system snapshot.
@Observable
final class HardwareMonitor {
    private(set) var snapshot: SystemSnapshot?
    private var monitoringTask: Task<Void, Never>?
    
    var updateInterval: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: "updateInterval")
            start()
        }
    }
    
    init() {
        let saved = UserDefaults.standard.double(forKey: "updateInterval")
        self.updateInterval = saved > 0.0 ? saved : 1.0
    }
    
    /// Starts the background monitoring loop.
    func start() {
        stop()
        monitoringTask = Task {
            while !Task.isCancelled {
                let updatedSnapshot = await fetchCurrentSnapshot()
                
                await MainActor.run {
                    self.snapshot = updatedSnapshot
                }
                
                // Use milliseconds to support finer-grained sleep intervals
                let ms = Int(updateInterval * 1000)
                try? await Task.sleep(for: .milliseconds(ms))
            }
        }
    }
    
    /// Stops the background monitoring loop.
    func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    private func fetchCurrentSnapshot() async -> SystemSnapshot {
        let task = Task.detached(priority: .userInitiated) {
            SystemSnapshot(
                cpu: await HardwareService.shared.fetchCPUInfo(),
                memory: await HardwareService.shared.fetchMemoryInfo(),
                disks: await HardwareService.shared.fetchDiskInfo(),
                gpu: await HardwareService.shared.fetchGPUInfo(),
                npu: await HardwareService.shared.fetchNPUInfo(),
                sensors: await HardwareService.shared.fetchSensors(),
                timestamp: Date()
            )
        }
        return await task.value
    }
    
    deinit {
        stop()
    }
}
