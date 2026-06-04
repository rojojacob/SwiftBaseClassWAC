import Foundation
import Testing
@testable import GateKit

@Test func allScreensEnumeratesFeatureSubdirectories() {
    let finder = FakeFileFinder()
    finder.subdirsByDirectory["/repo/App/App/Features"] = ["Posts", "Counter"]
    let resolver = ScopeResolver(
        config: makeTestConfig(),
        runner: FakeCommandRunner(),
        finder: finder,
        repoRoot: URL(fileURLWithPath: "/repo")
    )
    let screens = resolver.allScreens()
    #expect(screens.map(\.name) == ["Counter", "Posts"]) // sorted
    #expect(screens.first?.codePath == "App/App/Features/Counter")
}
