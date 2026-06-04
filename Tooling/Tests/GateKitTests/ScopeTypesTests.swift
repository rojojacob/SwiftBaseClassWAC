import Testing
@testable import GateKit

@Test func screenHoldsConventionDerivedPaths() {
    let screen = Screen(
        name: "Posts",
        codePath: "App/App/Features/Posts",
        unitTestClasses: ["PostsViewModelTests"],
        uiTestClasses: ["PostsUITests"]
    )
    #expect(screen.name == "Posts")
    #expect(screen.unitTestClasses == ["PostsViewModelTests"])
    #expect(screen.codePath == "App/App/Features/Posts")
    #expect(screen.uiTestClasses == ["PostsUITests"])
}

@Test func resolvedScopeReportsAll() {
    let scope = ResolvedScope(kind: .all, screens: [])
    #expect(scope.isAll)
}
