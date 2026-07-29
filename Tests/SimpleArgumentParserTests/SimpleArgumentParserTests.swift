import Testing

@testable import SimpleArgumentParser

@Test("parses flags, a value option, and positional arguments together")
func parsesMixedArguments() throws {
    let parser = ArgumentParser(
        options: [
            Option(name: "v", isFlag: true),
            Option(name: "o", defaultValue: "default.txt"),
        ],
        arguments: [Argument(name: "ARGUMENTS", isVariadic: true)]
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
            Option(name: "o", defaultValue: "default.txt"),
        ]
    )

    let result = try parser.parse(arguments: ["tool"])

    #expect(!result.isSet("v"))
    #expect(result["o"] == "default.txt")
    #expect(result.arguments.isEmpty)
}

@Test("positional arguments can be interspersed with options in any order")
func positionalArgumentsCanBeInterspersed() throws {
    let parser = ArgumentParser(
        options: [Option(name: "v", isFlag: true)],
        arguments: [Argument(name: "ARGUMENTS", isVariadic: true)]
    )

    let result = try parser.parse(arguments: ["tool", "first", "-v", "second"])

    #expect(result.arguments == ["first", "second"])
    #expect(result.isSet("v"))
}

@Test("a parser configured with a variadic argument and no options only collects positionals")
func noOptionsConfigured() throws {
    let parser = ArgumentParser(arguments: [Argument(name: "ARGUMENTS", isVariadic: true)])

    let result = try parser.parse(arguments: ["tool", "a", "b", "c"])

    #expect(result.arguments == ["a", "b", "c"])
}

@Test("a parser configured with no arguments (the default) rejects any positional argument")
func noArgumentsConfiguredRejectsPositionals() throws {
    let parser = ArgumentParser()

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool", "unexpected"])
    }

    guard case .wrongArgumentCount(let expectedDescription, let got) = error else {
        Issue.record("Expected .wrongArgumentCount, got \(error)")
        return
    }
    #expect(expectedDescription == "no arguments")
    #expect(got == 1)
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
    let parser = ArgumentParser(options: [Option(name: "o", defaultValue: "default.txt")])

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
            Option(name: "o", defaultValue: "default.txt"),
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

@Test("a non-flag option with no default that's never passed throws missingRequiredOption")
func missingRequiredOptionThrows() throws {
    let parser = ArgumentParser(options: [Option(name: "tag")])

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool"])
    }

    guard case .missingRequiredOption(let name) = error else {
        Issue.record("Expected .missingRequiredOption, got \(error)")
        return
    }
    #expect(name == "--tag")
}

@Test("exact-arity arguments accept the right count and are collected in order")
func exactArityAcceptsRightCount() throws {
    let parser = ArgumentParser(
        arguments: [Argument(name: "INPUTPATH"), Argument(name: "OUTPUTPATH")])

    let result = try parser.parse(arguments: ["tool", "in.txt", "out.txt"])

    #expect(result.arguments == ["in.txt", "out.txt"])
}

@Test("too few positional arguments throws wrongArgumentCount")
func exactArityRejectsTooFewThrows() throws {
    let parser = ArgumentParser(
        arguments: [Argument(name: "INPUTPATH"), Argument(name: "OUTPUTPATH")])

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool", "in.txt"])
    }

    guard case .wrongArgumentCount(let expectedDescription, let got) = error else {
        Issue.record("Expected .wrongArgumentCount, got \(error)")
        return
    }
    #expect(expectedDescription == "2 arguments (INPUTPATH, OUTPUTPATH)")
    #expect(got == 1)
}

@Test("too many positional arguments throws wrongArgumentCount")
func exactArityRejectsTooManyThrows() throws {
    let parser = ArgumentParser(arguments: [Argument(name: "INPUTPATH")])

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool", "in.txt", "extra"])
    }

    guard case .wrongArgumentCount(_, let got) = error else {
        Issue.record("Expected .wrongArgumentCount, got \(error)")
        return
    }
    #expect(got == 2)
}

@Test("a variadic last argument accepts zero or more trailing arguments")
func variadicArityAcceptsZeroOrMore() throws {
    let parser = ArgumentParser(
        arguments: [Argument(name: "INPUTPATH"), Argument(name: "FILES", isVariadic: true)])

    let zero = try parser.parse(arguments: ["tool", "in.txt"])
    #expect(zero.arguments == ["in.txt"])

    let many = try parser.parse(arguments: ["tool", "in.txt", "a", "b", "c"])
    #expect(many.arguments == ["in.txt", "a", "b", "c"])
}

@Test("a variadic last argument still requires its non-variadic prefix")
func variadicArityRequiresPrefixThrows() throws {
    let parser = ArgumentParser(
        arguments: [Argument(name: "INPUTPATH"), Argument(name: "FILES", isVariadic: true)])

    let error = try #require(throws: ParseError.self) {
        try parser.parse(arguments: ["tool"])
    }

    guard case .wrongArgumentCount(let expectedDescription, let got) = error else {
        Issue.record("Expected .wrongArgumentCount, got \(error)")
        return
    }
    #expect(expectedDescription == "at least 1 argument (INPUTPATH, FILES...)")
    #expect(got == 0)
}

@Test(
    "single- and multi-character option names derive the correct hyphen count",
    arguments: [
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
    #expect(
        ParseError.missingRequiredOption("--tag").description
            == "option '--tag' is required but was not provided.")
    #expect(
        ParseError.wrongArgumentCount(
            expectedDescription: "2 arguments (INPUTPATH, OUTPUTPATH)", got: 1
        )
        .description == "expected 2 arguments (INPUTPATH, OUTPUTPATH), but got 1.")
}
