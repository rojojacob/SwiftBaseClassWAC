import Testing
@testable import GateKit

@Test func singleStarPatternMatchesPrefixAndSuffix() {
    #expect(Glob.matches("Posts*Tests.swift", name: "PostsViewModelTests.swift"))
    #expect(Glob.matches("Posts*Tests.swift", name: "PostsTests.swift"))
    #expect(Glob.matches("Counter*Tests.swift", name: "CounterUITests.swift"))
    #expect(Glob.matches("Posts*Tests.swift", name: "OrdersViewModelTests.swift") == false)
    #expect(Glob.matches("Posts*Tests.swift", name: "PostsView.swift") == false)
}

@Test func noStarRequiresExactMatch() {
    #expect(Glob.matches("Exact.swift", name: "Exact.swift"))
    #expect(Glob.matches("Exact.swift", name: "Other.swift") == false)
}

@Test func multiStarMatchesInteriorSegmentsInOrder() {
    #expect(Glob.matches("A*B*C", name: "AxxByyC"))
    #expect(Glob.matches("A*B*C", name: "ABC"))
    #expect(Glob.matches("A*B*C", name: "AxxCyyB") == false) // does not end with C
    #expect(Glob.matches("Posts*Model*Tests.swift", name: "PostsViewModelTests.swift"))
    #expect(Glob.matches("Posts*Model*Tests.swift", name: "PostsViewTests.swift") == false)
}
