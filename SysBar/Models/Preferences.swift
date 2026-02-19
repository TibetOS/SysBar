import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Sendable {
    case iconOnly = "icon_only"
    case cpu = "cpu"
    case ram = "ram"
    case network = "network"

    var label: String {
        switch self {
        case .iconOnly: "Icon Only"
        case .cpu: "CPU %"
        case .ram: "RAM %"
        case .network: "Network Speed"
        }
    }
}

enum RefreshRate: Double, CaseIterable, Sendable {
    case fast = 1.0
    case normal = 2.0
    case slow = 5.0
    case verySlow = 10.0

    var label: String {
        switch self {
        case .fast: "1 second"
        case .normal: "2 seconds"
        case .slow: "5 seconds"
        case .verySlow: "10 seconds"
        }
    }
}

enum Preferences {
    @MainActor static var menuBarDisplay: MenuBarDisplayMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "menuBarDisplay"),
                  let mode = MenuBarDisplayMode(rawValue: raw) else { return .iconOnly }
            return mode
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "menuBarDisplay") }
    }

    @MainActor static var refreshRate: RefreshRate {
        get {
            let raw = UserDefaults.standard.double(forKey: "refreshRate")
            return RefreshRate(rawValue: raw) ?? .normal
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "refreshRate") }
    }

    @MainActor static var cpuThreshold: Double {
        get {
            let val = UserDefaults.standard.double(forKey: "cpuThreshold")
            return val > 0 ? val : 0.90
        }
        set { UserDefaults.standard.set(newValue, forKey: "cpuThreshold") }
    }

    @MainActor static var ramThreshold: Double {
        get {
            let val = UserDefaults.standard.double(forKey: "ramThreshold")
            return val > 0 ? val : 0.90
        }
        set { UserDefaults.standard.set(newValue, forKey: "ramThreshold") }
    }

    @MainActor static var alertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "alertsEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "alertsEnabled") }
    }
}
