// parseargs.swift

import Foundation

/// Simple command line argument parser for Swift
///
/// This parser allows you to define a set of options and flags for your command line tool, and then parse
/// the provided arguments to extract the values of those options and flags, as well as any positional arguments.
/// It also adds the --help/-h flag to print help information.
public struct ArgumentParser {

    /// Optional description of the command line tool
    let description: String?
    /// Dictionary of options where the key is the option name and the value is an `Option` struct
    let options: [String: Option]
    /// The options' `cliName`s in declaration order, used only to print help in that order
    /// (lookups during parsing don't care about order, so `options` stays a dictionary).
    let optionOrder: [String]
    /// The positional arguments this parser expects, in order. Empty (the default) means
    /// no positional arguments are expected. To accept any number of unnamed positional
    /// arguments, pass a single variadic `Argument`, e.g. `[Argument(name: "ARGUMENTS",
    /// isVariadic: true)]`.
    let arguments: [Argument]

    /// Initialize with optional description, options, and positional arguments
    /// - Parameters:
    ///   - description: A brief description of the command line tool.
    ///   - options: The options this parser should recognize.
    ///   - arguments: The positional arguments this parser expects, in order. Leave empty
    ///     (the default) to reject any positional arguments; pass a single variadic
    ///     `Argument` to accept any number of unnamed ones. Only the last `Argument` may
    ///     be variadic.
    public init(description: String? = nil, options: [Option] = [], arguments: [Argument] = []) {
        for (index, argument) in arguments.enumerated() {
            precondition(!argument.name.isEmpty, "Argument name must not be empty.")
            precondition(
                !argument.isVariadic || index == arguments.count - 1,
                "Argument '\(argument.name)' is variadic; only the last argument may be variadic."
            )
        }

        self.description = description
        self.options = Dictionary(uniqueKeysWithValues: options.map { ($0.cliName, $0) })
        self.optionOrder = options.map { $0.cliName }
        self.arguments = arguments
    }

    /// The `USAGE:` line's rendering of positional arguments — e.g. `INPUTPATH OUTPUTPATH`,
    /// or empty if none were declared (no positional arguments are expected).
    var argumentsUsageString: String {
        guard !arguments.isEmpty else { return "" }
        return arguments.map { $0.isVariadic ? "\($0.name)..." : $0.name }.joined(separator: " ")
    }

    /// A human-readable description of how many positional arguments are expected, for
    /// use in `ParseError.wrongArgumentCount` messages.
    var argumentCountDescription: String {
        guard !arguments.isEmpty else { return "no arguments" }
        let names: String = arguments.map(\.name).joined(separator: ", ")
        if arguments.last?.isVariadic == true {
            let minimum: Int = arguments.count - 1
            return "at least \(minimum) argument\(minimum == 1 ? "" : "s") (\(names)...)"
        }
        return "\(arguments.count) argument\(arguments.count == 1 ? "" : "s") (\(names))"
    }

    /// Prints the help information for the command line tool, including the overview, usage, and available options.
    /// - Parameter commandName: The name to show on the `USAGE:` line.
    private func printHelp(
        commandName: String, width: Int = 80, indent: Int = 2, columnSeperator: String = "  "
    ) {
        let indentString: String = String(repeating: " ", count: indent)

        let orderedOptions: [Option] = optionOrder.compactMap { options[$0] }

        var helpParts: [String] = []

        let overview: String = wrapped("OVERVIEW: \(description ?? "")", indent: 2)
        helpParts.append(overview)

        var usage: String = "USAGE: \(commandName)"
        let optionsParts: [String] = orderedOptions.map { "[\($0.cliString)]" }
        usage += " \(optionsParts.joined(separator: " "))"
        if !argumentsUsageString.isEmpty {
            usage += " \(argumentsUsageString)"
        }
        helpParts.append(usage)

        var optionsHelp: [String] = ["OPTIONS:"]

        let cliLength: Int = max(
            orderedOptions.map { $0.cliString.count }.max() ?? 0, "-h, --help".count)
        let descriptionIndent: Int = cliLength + columnSeperator.count + indent
        let descriptionWidth: Int = width - descriptionIndent

        for option: Option in orderedOptions {
            let optionHelpString: String =
                indentString
                + option.cliString.padding(toLength: cliLength, withPad: " ", startingAt: 0)
                + columnSeperator
                + wrapped(
                    option.cliOptionHelpString, to: width, indent: descriptionIndent,
                    firstlinewidth: descriptionWidth)

            optionsHelp.append(optionHelpString)
        }
        let helpHelpString: String =
            indentString
            + "-h, --help".padding(toLength: cliLength, withPad: " ", startingAt: 0)
            + columnSeperator
            + wrapped(
                "Print help information.", to: width, indent: descriptionIndent,
                firstlinewidth: descriptionWidth)
        optionsHelp.append(helpHelpString)
        helpParts.append(optionsHelp.joined(separator: "\n"))

        print(helpParts.joined(separator: "\n\n"))

    }

    private func wrapped(
        _ string: String, to width: Int = 80, indent: Int = 0, firstlinewidth: Int? = nil,
        separator: String = "\n"
    ) -> String {
        precondition(indent < width, "indent must be smaller than width")
        var lines: [String] = []
        var string: String = string

        var effectiveWidth: Int = firstlinewidth ?? width

        // first line to effectiveWidth, subsequent lines to width - indent
        var firstLine: Bool = true
        while string.count > effectiveWidth {
            let breakIndex: Substring.Index =
                string.prefix(effectiveWidth).lastIndex(of: " ")
                ?? string.prefix(effectiveWidth).endIndex
            let nextLineStartIndex: String.Index =
                string[breakIndex] == " "
                ? string.index(after: breakIndex)
                : breakIndex
            let nextLine: String =
                String(string[nextLineStartIndex...])
            string = String(string[..<breakIndex])
            lines.append(string)
            string = nextLine
            if firstLine {
                effectiveWidth = width - indent
                firstLine = false
            }
        }
        if !string.isEmpty {
            lines.append(string)
        }
        if indent > 0 {
            let indentString: String = String(repeating: " ", count: indent)
            lines = lines.enumerated().map {
                $0.offset == 0 ? $0.element : indentString + $0.element
            }
        }
        return lines.joined(separator: separator)
    }

    /// Parses the given command line arguments.
    /// - Parameter arguments: The command line arguments to parse.
    /// - Returns: The result of the parsing operation.
    /// - Throws: `ParseError.unknownOption` if an argument starting with `-` isn't a
    ///   recognized option, `ParseError.duplicateOption` if an option is passed more
    ///   than once, `ParseError.missingValue` if a non-flag option isn't followed by a
    ///   value, `ParseError.invalidValue` if a value isn't among an option's
    ///   `possibleValues`, `ParseError.missingRequiredOption` if a non-flag option has
    ///   no default value and was never passed, or `ParseError.wrongArgumentCount` if
    ///   the number of positional arguments doesn't match the configured `arguments`.
    ///   Parsing stops at the first such problem.
    public func parse(arguments: [String]) throws -> ParseResult {
        // `arguments` is expected to be the full CommandLine.arguments, including
        // the executable path as the first element.
        var options: [String: Option] = options
        var positionalArguments: [String] = []
        var commandName: String = ""

        var remainingArguments: [String] = arguments
        if !remainingArguments.isEmpty {
            let commandPath: String = remainingArguments.removeFirst()
            commandName = commandPath.split(separator: "/").last.map(String.init) ?? commandPath
        }

        // shortcut if -h or --help is passed, so we can print help and exit
        if remainingArguments.contains("-h") || remainingArguments.contains("--help") {
            printHelp(commandName: commandName)
            exit(0)
        }

        while !remainingArguments.isEmpty {
            let arg: String = remainingArguments.removeFirst()
            if arg.starts(with: "-") {
                guard var option: Option = options.removeValue(forKey: arg) else {
                    throw ParseError.unknownOption(arg)
                }
                guard !option.isSet else {
                    throw ParseError.duplicateOption(arg)
                }

                option.isSet = true

                if !option.isFlag {
                    guard let optionValue: String = remainingArguments.first,
                        !optionValue.starts(with: "-")
                    else {
                        throw ParseError.missingValue(arg)
                    }
                    if let possibleValues: [String] = option.possibleValues,
                        !possibleValues.contains(optionValue)
                    {
                        throw ParseError.invalidValue(arg, optionValue, possibleValues)
                    }
                    remainingArguments.removeFirst()
                    option.value = optionValue
                }

                options[arg] = option
            } else {
                positionalArguments.append(arg)
            }
        }

        let lastIsVariadic: Bool = self.arguments.last?.isVariadic ?? false
        let requiredCount: Int = lastIsVariadic ? self.arguments.count - 1 : self.arguments.count
        let countIsValid: Bool =
            lastIsVariadic
            ? positionalArguments.count >= requiredCount
            : positionalArguments.count == requiredCount
        guard countIsValid else {
            throw ParseError.wrongArgumentCount(
                expectedDescription: argumentCountDescription, got: positionalArguments.count)
        }

        for option in options.values.sorted(by: { $0.name < $1.name }) {
            try option.requireResolvable()
        }

        return ParseResult(
            commandName: commandName,
            arguments: positionalArguments,
            options: Dictionary(uniqueKeysWithValues: options.values.map { ($0.name, $0) })
        )
    }
}

/// Immutable outcome of parsing a set of command line arguments against a `ParseArgs` configuration.
public struct ParseResult {
    public let commandName: String
    public let arguments: [String]
    let options: [String: Option]

    public subscript(name: String) -> String {
        guard let option: Option = options[name] else {
            fatalError("Option '\(name)' is not defined in the parser configuration.")
        }
        if option.isFlag {
            // Better Usage: use isSet to get the boolean value of the flag
            return option.isSet ? "true" : "false"
        }
        return option.resolvedValue
    }

    public func isSet(_ name: String) -> Bool {
        options[name]?.isSet ?? false
    }
}

/// Errors that can occur while parsing command line arguments.
public enum ParseError: Error, CustomStringConvertible {
    case unknownOption(String)
    case duplicateOption(String)
    case missingValue(String)
    case invalidValue(String, String, [String])  // option name, invalid value, possible values
    case missingRequiredOption(String)
    case wrongArgumentCount(expectedDescription: String, got: Int)

    public var description: String {
        switch self {
        case .unknownOption(let name):
            return "unknown option '\(name)'."
        case .duplicateOption(let name):
            return "option '\(name)' is already set."
        case .missingValue(let name):
            return "option '\(name)' expects a value but none was given."
        case .invalidValue(let name, let value, let possibleValues):
            return
                "option '\(name)' has an invalid value '\(value)'. Valid values are: \(possibleValues.joined(separator: ", "))."
        case .missingRequiredOption(let name):
            return "option '\(name)' is required but was not provided."
        case .wrongArgumentCount(let expectedDescription, let got):
            return "expected \(expectedDescription), but got \(got)."
        }
    }
}

/// Represents a named positional argument.
public struct Argument {
    let name: String
    /// If `true`, this argument absorbs all remaining positional arguments (zero or
    /// more). Only the last `Argument` passed to `ArgumentParser.init` may be variadic.
    let isVariadic: Bool

    public init(name: String, isVariadic: Bool = false) {
        self.name = name
        self.isVariadic = isVariadic
    }
}

/// Represents a command line option or flag.
public struct Option {
    var name: String
    var isFlag: Bool = false
    var defaultValue: String?
    var possibleValues: [String]?
    var help: String?

    var value: String?
    var isSet: Bool = false

    /// The option's command-line form: one hyphen for single-character names (`-h`),
    /// two for longer ones (`--help`).
    var cliName: String {
        name.count == 1 ? "-\(name)" : "--\(name)"
    }

    var cliString: String {
        var cliString: String = cliName
        if !isFlag {
            cliString += " <\(name)>"
        }
        return cliString
    }

    var cliOptionHelpString: String {
        var helpString: [String] = []
        if let help: String = help {
            helpString.append(help)
        }

        var addInfo: String = ""
        if let possibleValues: [String] = possibleValues {
            addInfo.append(
                "(possible values: \(possibleValues.joined(separator: ", "))"
            )
            if let value: String = defaultValue {
                addInfo.append("; default: \(value))")
            } else {
                addInfo.append(")")
            }
        } else if let value: String = defaultValue {
            addInfo.append("(default: \(value))")
        }
        helpString.append(addInfo)
        return helpString.joined(separator: " ")
    }

    /// `value`, falling back to `defaultValue` if it was never set explicitly.
    /// `ArgumentParser.parse()` guarantees that every non-flag option in a returned
    /// `ParseResult` has one or the other — so this is only ever unsafe if that
    /// guarantee has been broken by a change to `parse()` itself.
    var resolvedValue: String {
        guard let resolved: String = value ?? defaultValue else {
            fatalError(
                "Invariant violated: ArgumentParser.parse() should guarantee every non-flag option has a value or a default by the time a ParseResult exists. This indicates a bug in parse(), not user input."
            )
        }
        return resolved
    }

    /// Checks that the option can be resolved — either from an explicit value or `defaultValue`.
    /// - Throws: `ParseError.missingRequiredOption` if it's a non-flag option with neither.
    func requireResolvable() throws {
        guard !isFlag, value == nil, defaultValue == nil else { return }
        throw ParseError.missingRequiredOption(cliName)
    }

    /// - Parameter name: The option's bare name, without leading hyphens (e.g. `"h"`, `"help"`).
    ///   Look it up on a `ParseResult` with this same bare name (e.g. `isSet("h")`); use
    ///   `cliName` to get its command-line form.
    public init(
        name: String, isFlag: Bool = false, defaultValue: String? = nil,
        possibleValues: [String]? = nil,
        help: String? = nil
    ) {
        precondition(!name.isEmpty, "Option name must not be empty.")
        precondition(
            !name.starts(with: "-"),
            "Option name '\(name)' should be given without leading '-': the parser adds '-' for single-character names and '--' for longer names."
        )
        precondition(
            !isFlag || defaultValue == nil,
            "Option '\(name)' is a flag; it cannot have a default value."
        )
        precondition(
            !isFlag || possibleValues == nil,
            "Option '\(name)' is a flag; it cannot have possible values."
        )
        if let possibleValues: [String], let defaultValue: String {
            precondition(
                possibleValues.contains(defaultValue),
                "Option '\(name)' has a default value '\(defaultValue)' that is not in its possible values \(possibleValues)."
            )
        }

        self.name = name
        self.isFlag = isFlag
        self.help = help
        self.defaultValue = defaultValue
        self.possibleValues = possibleValues
    }

}
