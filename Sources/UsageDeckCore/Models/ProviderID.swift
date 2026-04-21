import Foundation

/// Unique identifier for each supported AI provider.
public enum ProviderID: String, CaseIterable, Sendable, Codable, Hashable {
    case claude
    case codex
    case cursor
    case copilot
    case kiro

    /// Human-readable display name for the provider.
    public var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .cursor: "Cursor"
        case .copilot: "Copilot"
        case .kiro: "Kiro"
        }
    }

    /// CLI command name for the provider.
    public var cliName: String {
        self.rawValue
    }
}

/// Visual style for provider icons.
public enum IconStyle: String, Sendable, CaseIterable, Codable {
    case claude
    case codex
    case cursor
    case copilot
    case kiro

    public init(from provider: ProviderID) {
        switch provider {
        case .claude: self = .claude
        case .codex: self = .codex
        case .cursor: self = .cursor
        case .copilot: self = .copilot
        case .kiro: self = .kiro
        }
    }
}
