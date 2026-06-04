import Foundation
import Testing
@testable import GateKit

private func makeResolver(runner: CommandRunner, finder: FileFinder) -> ScopeResolver {
    ScopeResolver(
        config: makeTestConfig(),
        runner: runner,
        finder: finder,
        repoRoot: URL(fileURLWithPath: "/repo")
    )
}

@Test func resolvesNamedScreenWithDiscoveredTestClasses() throws {
    let finder = FakeFileFinder()
    finder.filesByDirectory["/repo/App/AppTests"] = [
        "/repo/App/AppTests/Features/PostsViewModelTests.swift",
        "/repo/App/AppTests/Features/OrdersViewModelTests.swift" // decoy: must NOT match "Posts*Tests.swift"
    ]
    finder.filesByDirectory["/repo/App/AppUITests"] = [
        "/repo/App/AppUITests/PostsUITests.swift"
    ]
    let resolver = makeResolver(runner: FakeCommandRunner(), finder: finder)

    let scope = try resolver.resolve(.screens(["Posts"]))

    #expect(scope.kind == .screens)
    #expect(scope.screens.count == 1)
    #expect(scope.screens[0].codePath == "App/App/Features/Posts")
    #expect(scope.screens[0].unitTestClasses == ["PostsViewModelTests"])
    #expect(scope.screens[0].uiTestClasses == ["PostsUITests"])
    #expect(scope.screens[0].unitTestFiles == ["/repo/App/AppTests/Features/PostsViewModelTests.swift"])
    #expect(scope.screens[0].uiTestFiles == ["/repo/App/AppUITests/PostsUITests.swift"])
}

@Test func branchMapsChangedFilesToOwningScreens() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 0,
        stdout: "App/App/Features/Posts/PostsView.swift\nApp/App/Features/Counter/CounterView.swift\n",
        stderr: ""
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())

    let scope = try resolver.resolve(.branch(base: "main"))

    #expect(scope.kind == .screens)
    #expect(scope.screens.map(\.name) == ["Counter", "Posts"]) // sorted
}

@Test func changeUnderSharedDirEscalatesToAll() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 0,
        stdout: "App/App/Core/Networking/APIClient.swift\n",
        stderr: ""
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())

    let scope = try resolver.resolve(.branch(base: "main"))

    #expect(scope.isAll)
}

@Test func branchWithNoMappableChangesFallsBackToAll() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 0, stdout: "README.md\n", stderr: ""
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())

    #expect(try resolver.resolve(.branch(base: "main")).isAll)
}

@Test func allScopeReturnsAll() throws {
    let resolver = makeResolver(runner: FakeCommandRunner(), finder: FakeFileFinder())
    #expect(try resolver.resolve(.all).isAll)
}

@Test func featuresRootSourceFileEscalatesToAll() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 0,
        stdout: "App/App/Features/FeatureRoute.swift\n",
        stderr: ""
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())
    #expect(try resolver.resolve(.branch(base: "main")).isAll)
}

@Test func branchDedupesFilesFromSameScreen() throws {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 0,
        stdout: "App/App/Features/Posts/PostsView.swift\nApp/App/Features/Posts/PostsViewModel.swift\n",
        stderr: ""
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())
    let scope = try resolver.resolve(.branch(base: "main"))
    #expect(scope.screens.map(\.name) == ["Posts"])
}

@Test func branchThrowsWhenGitFails() {
    let runner = FakeCommandRunner()
    runner.stub(whenContains: "diff", result: ProcessResult(
        exitCode: 128, stdout: "", stderr: "fatal: bad revision"
    ))
    let resolver = makeResolver(runner: runner, finder: FakeFileFinder())
    #expect(throws: ScopeError.self) {
        _ = try resolver.resolve(.branch(base: "nope"))
    }
}
