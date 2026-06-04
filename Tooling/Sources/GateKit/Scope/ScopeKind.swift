public enum ScopeKind: Equatable, Sendable {
    case all
    case screens([String])
    case branch(base: String)
    case staged
}
