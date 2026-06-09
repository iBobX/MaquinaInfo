import Foundation
import Observation

/// Available application languages.
enum Language: String, CaseIterable, Identifiable {
    case system = "System"
    case en = "English"
    case es = "Español"
    case pt = "Português"
    
    var id: String { self.rawValue }
    
    var code: String {
        switch self {
        case .system:
            let preferred = Bundle.main.preferredLocalizations.first ?? "en"
            if preferred.hasPrefix("es") { return "es" }
            if preferred.hasPrefix("pt") { return "pt" }
            return "en"
        case .en: return "en"
        case .es: return "es"
        case .pt: return "pt"
        }
    }
    
    func displayName(in currentLangCode: String) -> String {
        switch self {
        case .system:
            switch currentLangCode {
            case "es": return "Predeterminado (Sistema)"
            case "pt": return "Padrão (Sistema)"
            default: return "Default (System)"
            }
        case .en: return "English"
        case .es: return "Español"
        case .pt: return "Português"
        }
    }
}

/// Dynamic localization controller.
@Observable
final class LanguageManager {
    static let shared = LanguageManager()
    
    var selectedLanguage: Language = .system {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "selectedLanguage")
        }
    }
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let lang = Language(rawValue: raw) {
            self.selectedLanguage = lang
        } else {
            self.selectedLanguage = .system
        }
    }
    
    var currentLanguageCode: String {
        selectedLanguage.code
    }
    
    func translate(_ key: String) -> String {
        let lang = currentLanguageCode
        return Translations.dict[key]?[lang] ?? key
    }
}

/// Master translation dictionary.
struct Translations {
    static let dict: [String: [String: String]] = [
        "Dashboard": [
            "en": "Dashboard",
            "es": "Panel Principal",
            "pt": "Painel de Controle"
        ],
        "CPU": [
            "en": "Processor (CPU)",
            "es": "Procesador (CPU)",
            "pt": "Processador (CPU)"
        ],
        "Memory": [
            "en": "Memory (RAM)",
            "es": "Memoria (RAM)",
            "pt": "Memória (RAM)"
        ],
        "Disk": [
            "en": "Storage (Disk)",
            "es": "Almacenamiento (Disco)",
            "pt": "Armazenamento (Disco)"
        ],
        "GPU": [
            "en": "Graphics (GPU)",
            "es": "Gráficos (GPU)",
            "pt": "Gráficos (GPU)"
        ],
        "NPU": [
            "en": "Neural Engine (NPU)",
            "es": "Motor Neuronal (NPU)",
            "pt": "Motor Neuronal (NPU)"
        ],
        "Sensors": [
            "en": "Sensors (Temps)",
            "es": "Sensores (Temps)",
            "pt": "Sensores (Temps)"
        ],
        "Settings": [
            "en": "Settings",
            "es": "Configuración",
            "pt": "Configurações"
        ],
        "Overview": [
            "en": "System Overview",
            "es": "Vista General del Sistema",
            "pt": "Visão Geral do Sistema"
        ],
        "Model": [
            "en": "Model",
            "es": "Modelo",
            "pt": "Modelo"
        ],
        "Cores": [
            "en": "Physical Cores",
            "es": "Núcleos Físicos",
            "pt": "Núcleos Físicos"
        ],
        "Architecture": [
            "en": "Architecture",
            "es": "Arquitectura",
            "pt": "Arquitetura"
        ],
        "Total RAM": [
            "en": "Total Capacity",
            "es": "Capacidad Total",
            "pt": "Capacidade Total"
        ],
        "Used": [
            "en": "Used Memory",
            "es": "Memoria Usada",
            "pt": "Memória Usada"
        ],
        "Free": [
            "en": "Free Memory",
            "es": "Memoria Libre",
            "pt": "Memória Livre"
        ],
        "Wired": [
            "en": "Wired Memory",
            "es": "Memoria Cableada",
            "pt": "Memória com Fio"
        ],
        "Compressed": [
            "en": "Compressed",
            "es": "Comprimida",
            "pt": "Comprimida"
        ],
        "Graphics Model": [
            "en": "GPU Model",
            "es": "Modelo de GPU",
            "pt": "Modelo de GPU"
        ],
        "Device Usage": [
            "en": "GPU Utilization",
            "es": "Utilización del GPU",
            "pt": "Utilização do GPU"
        ],
        "Renderer Usage": [
            "en": "Renderer Utilization",
            "es": "Uso de Renderización",
            "pt": "Uso de Renderização"
        ],
        "Tiler Usage": [
            "en": "Tiler Utilization",
            "es": "Uso de Tiling",
            "pt": "Uso de Tiling"
        ],
        "NPU Model": [
            "en": "Neural Engine Model",
            "es": "Modelo de Motor Neuronal",
            "pt": "Modelo de Motor Neuronal"
        ],
        "NPU Cores": [
            "en": "ANE Core Count",
            "es": "Núcleos del Motor Neuronal",
            "pt": "Núcleos do Motor Neuronal"
        ],
        "NPU Version": [
            "en": "Firmware Version",
            "es": "Versión de Firmware",
            "pt": "Versão de Firmware"
        ],
        "Sensor Name": [
            "en": "Sensor Name",
            "es": "Sensor",
            "pt": "Sensor"
        ],
        "Temperature": [
            "en": "Temperature",
            "es": "Temperatura",
            "pt": "Temperatura"
        ],
        "Language": [
            "en": "Language",
            "es": "Idioma",
            "pt": "Idioma"
        ],
        "Select Language": [
            "en": "Application Language",
            "es": "Idioma de la Aplicación",
            "pt": "Idioma do Aplicativo"
        ],
        "Apple Silicon Only": [
            "en": "Hardware Compatibility Check",
            "es": "Verificación de Compatibilidad",
            "pt": "Verificação de Compatibilidade"
        ],
        "Intel Error": [
            "en": "This application is only compatible with Apple Silicon Macs (M1, M2, M3, M4...).",
            "es": "Esta aplicación es compatible únicamente con Macs con chip Apple Silicon (M1, M2, M3, M4...).",
            "pt": "Este aplicativo é compatível apenas com Macs com chip Apple Silicon (M1, M2, M3, M4...)."
        ],
        "Initializing": [
            "en": "Initializing system telemetry...",
            "es": "Inicializando telemetría del sistema...",
            "pt": "Inicializando telemetria do sistema..."
        ],
        "Realtime Activity": [
            "en": "Real-time Core Activity",
            "es": "Actividad de Núcleos en Tiempo Real",
            "pt": "Atividade de Núcleos em Tempo Real"
        ],
        "Available": [
            "en": "Available",
            "es": "Disponible",
            "pt": "Disponível"
        ],
        "Capacity": [
            "en": "Capacity",
            "es": "Capacidad",
            "pt": "Capacidade"
        ],
        "Sensor Details": [
            "en": "System Temperatures",
            "es": "Temperaturas del Sistema",
            "pt": "Temperaturas do Sistema"
        ],
        "Thermal Health": [
            "en": "Thermal Pressure State",
            "es": "Presión Térmica del Sistema",
            "pt": "Estado de Pressão Térmica"
        ],
        "Nominal": [
            "en": "Nominal (Normal)",
            "es": "Nominal (Normal)",
            "pt": "Nominal (Normal)"
        ],
        "Fair": [
            "en": "Fair (Elevated)",
            "es": "Moderado (Elevado)",
            "pt": "Moderado (Elevado)"
        ],
        "Serious": [
            "en": "Serious (Throttling possible)",
            "es": "Alto (Bajo rendimiento posible)",
            "pt": "Alto (Redução de desempenho possível)"
        ],
        "Critical": [
            "en": "Critical (Overheating warning)",
            "es": "Crítico (Alerta de sobrecalentamiento)",
            "pt": "Crítico (Alerta de superaquecimento)"
        ],
        "Refresh Rate": [
            "en": "Refresh Frequency",
            "es": "Frecuencia de Actualización",
            "pt": "Frequência de Atualização"
        ],
        "Seconds": [
            "en": "seconds",
            "es": "segundos",
            "pt": "segundos"
        ],
        "Main Storage": [
            "en": "Main Drive",
            "es": "Disco Principal",
            "pt": "Disco Principal"
        ],
        "App Memory": [
            "en": "App Memory",
            "es": "Memoria de Aplicaciones",
            "pt": "Memória de Aplicativos"
        ],
        "Hardware Info": [
            "en": "Hardware Info",
            "es": "Información de Hardware",
            "pt": "Informação de Hardware"
        ],
        "Active Cores": [
            "en": "Cores Active",
            "es": "Núcleos Activos",
            "pt": "Núcleos Ativos"
        ],
        "Average Usage": [
            "en": "Average Usage",
            "es": "Uso Promedio",
            "pt": "Uso Médio"
        ],
        "Menu": [
            "en": "Select a menu item",
            "es": "Selecciona una opción del menú",
            "pt": "Selecione um item do menu"
        ],
        "FreeStorage": [
            "en": "Free Space",
            "es": "Espacio Libre",
            "pt": "Espaço Livre"
        ],
        "AverageCPUTemp": [
            "en": "Average CPU Temp",
            "es": "Temp. Promedio de CPU",
            "pt": "Temp. Média da CPU"
        ],
        "ExportPDF": [
            "en": "Export PDF Report",
            "es": "Exportar Reporte PDF",
            "pt": "Exportar Relatório PDF"
        ],
        "AboutTitle": [
            "en": "About MaquinaInfo",
            "es": "Acerca de MaquinaInfo",
            "pt": "Sobre o MaquinaInfo"
        ],
        "Address": [
            "en": "Address",
            "es": "Dirección",
            "pt": "Endereço"
        ],
        "Company": [
            "en": "Company",
            "es": "Compañía",
            "pt": "Empresa"
        ],
        "Developer": [
            "en": "Developer",
            "es": "Desarrollador",
            "pt": "Desenvolvedor"
        ],
        "DirectDistOnly": [
            "en": "Detailed diagnostics available in direct version",
            "es": "Diagnósticos detallados disponibles en versión directa",
            "pt": "Diagnósticos detalhados disponíveis na versão direta"
        ],
        "AppStoreWarning": [
            "en": "Due to App Store sandbox rules, detailed temperatures and hardware counters are restricted in this version.",
            "es": "Debido a las reglas de sandbox de la App Store, las temperaturas detalladas y contadores de hardware están restringidos en esta versión.",
            "pt": "Devido às regras de sandbox da App Store, temperaturas detalhadas e contadores de hardware estão restritos nesta versão."
        ]
    ]
}
