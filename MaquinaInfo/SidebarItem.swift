import Foundation

/// Defines the navigation sections in the app sidebar.
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case gpu = "GPU"
    case npu = "NPU"
    case sensors = "Sensors"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .gpu: return "bolt.fill"
        case .npu: return "brain.head.profile"
        case .sensors: return "thermometer.medium"
        case .settings: return "gearshape.fill"
        }
    }
    
    var localizedName: String {
        LanguageManager.shared.translate(self.rawValue)
    }
}
