import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: String {
    case enabled = "Enabled"
    case disabled = "Disabled"
    case requiresApproval = "Requires Approval"
    case unavailable = "Unavailable"
    case unknown = "Unknown"
}

enum LoginItemManagerError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Launch at login requires macOS 13 or later."
        }
    }
}

enum LoginItemManager {
    static func status() -> LaunchAtLoginStatus {
        guard #available(macOS 13.0, *) else {
            return .unavailable
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unknown
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw LoginItemManagerError.unavailable
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
