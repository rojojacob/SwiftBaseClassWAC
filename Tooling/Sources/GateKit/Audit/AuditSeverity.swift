/// Four-level audit priority, ordered so `.critical` is the highest.
public enum AuditSeverity: Int, Codable, Comparable, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Penalty applied to the 0–100 health score per finding at this severity.
    public var weight: Int {
        switch self {
        case .critical: return 15
        case .high: return 7
        case .medium: return 3
        case .low: return 1
        }
    }

    /// Stable display label.
    public var label: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}
