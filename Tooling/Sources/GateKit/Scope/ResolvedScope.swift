public struct ResolvedScope: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case all
        case screens
    }

    public let kind: Kind
    public let screens: [Screen]

    public init(kind: Kind, screens: [Screen]) {
        self.kind = kind
        self.screens = screens
    }

    public var isAll: Bool {
        kind == .all
    }
}
