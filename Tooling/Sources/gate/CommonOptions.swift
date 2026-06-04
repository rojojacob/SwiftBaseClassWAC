import ArgumentParser

struct CommonOptions: ParsableArguments {
    @Option(name: .long, help: "Path to gate.yml (relative to the working directory).")
    var config: String = "gate.yml"
}
