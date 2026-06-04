import Testing
@testable import GateKit

@Test func severitiesOrderCriticalHighestAndCarryWeight() {
    #expect(AuditSeverity.critical > AuditSeverity.high)
    #expect(AuditSeverity.high > AuditSeverity.medium)
    #expect(AuditSeverity.medium > AuditSeverity.low)
    #expect(AuditSeverity.critical.weight > AuditSeverity.low.weight)
    #expect(AuditSeverity.allCases.count == 4)
}
