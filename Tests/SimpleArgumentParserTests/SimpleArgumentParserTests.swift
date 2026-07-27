import Testing

@testable import SimpleArgumentParser

@Test("parses flags, a value option, and positional arguments together")
func parsesMixedArguments() throws {
    let parser = ArgumentParser(
        options: [
            Option(name: "v", isFlag: true),
            Option(name: "o", value: "default.txt"),
        ]
    )

    let result = try parser.parse(arguments: ["/usr/bin/tool", "-v", "-o", "out.txt", "input.txt"])

    #expect(result.isSet("v"))
    #expect(result["o"] == "out.txt")
    #expect(result.arguments == ["input.txt"])
    #expect(result.commandName == "tool")
}

@Test("unset options fall back to their default and are reported as not set")
func unsetOptionsUseDefaults() throws {
    let parser = ArgumentParser(
        options: [
            Option(name: "v", isFlag: true),
            Option(name: "o", value: "default.txt"),
        ]
    )

    let result = try parser.parse(arguments: ["tool"])

    #expect(!result.isSet("v"))
    #expect(result["o"] == "default.txt")
    #expect(result.arguments.isEmpty)
}

@Test("positional arguments can be interspersed with options in any order")
func positionalArgumentsCanBeInterspersed() throws {
    let parser = ArgumentParser(options: [Option(name: "v", isFlag: true)])

    let result = try parser.parse(arguments: ["tool", "first", "-v", "second"])

    #expect(result.arguments == ["first", "second"])
    #expect(result.isSet("v"))
}

@Test("a parser configured with no options only collects positional arguments")
func noOptionsConfigured() throws {
    let parser = ArgumentParser()

    let result = try parser.parse(arguments: ["tool", "a", "b", "c"])

    #expect(result.arguments == ["a", "b", "c"])
}

@Test("command name is derived from the last path component")
func commandNameDerivedFromPath() throws {
    let result = try ArgumentParser().parse(arguments: ["/usr/local/bin/tool"])

    #expect(result.commandName == "tool")
}

@Test("empty arguments produce an empty command name and no positional arguments")
func emptyArgumentsProduceEmptyState() throws {
    let result = try ArgumentParser().parse(arguments: [])

    #expect(result.commandName == "")
    #expect(result.arguments.isEmpty)
}

@Test("an unrecognized option throws unknownOption with the offending flag")
func unknownOptionThrows() throws {
    let parser = ArgumentParser(options: [Option(name: "v", isFlag: true)])

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool", "--bogus"])
    }

    guard case .unknownOption(let name) = error else {
        Issue.record("Expected .unknownOption, got \(error)")
        return
    }
    #expect(name == "--bogus")
}

@Test("passing the same option twice throws duplicateOption")
func duplicateOptionThrows() throws {
    let parser = ArgumentParser(options: [Option(name: "v", isFlag: true)])

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool", "-v", "-v"])
    }

    guard case .duplicateOption(let name) = error else {
        Issue.record("Expected .duplicateOption, got \(error)")
        return
    }
    #expect(name == "-v")
}

@Test("a value option with nothing following it throws missingValue")
func missingValueAtEndOfArgumentsThrows() throws {
    let parser = ArgumentParser(options: [Option(name: "o", value: "default.txt")])

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool", "-o"])
    }

    guard case .missingValue(let name) = error else {
        Issue.record("Expected .missingValue, got \(error)")
        return
    }
    #expect(name == "-o")
}

@Test("a value option followed by another option throws missingValue")
func missingValueFollowedByAnotherOptionThrows() throws {
    let parser = ArgumentParser(
        options: [
            Option(name: "o", value: "default.txt"),
            Option(name: "v", isFlag: true),
        ]
    )

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool", "-o", "-v"])
    }

    guard case .missingValue(let name) = error else {
        Issue.record("Expected .missingValue, got \(error)")
        return
    }
    #expect(name == "-o")
}

@Test("single- and multi-character option names derive the correct hyphen count", arguments: [
    ("v", "-v"),
    ("version", "--version"),
])
func optionCliNameHyphenCount(name: String, expectedCliName: String) {
    #expect(Option(name: name).cliName == expectedCliName)
}

@Test("ParseError descriptions are human readable")
func parseErrorDescriptions() {
    #expect(ParseError.unknownOption("--bogus").description == "unknown option '--bogus'.")
    #expect(ParseError.duplicateOption("-v").description == "option '-v' is already set.")
    #expect(
        ParseError.missingValue("-o").description
            == "option '-o' expects a value but none was given.")
}
