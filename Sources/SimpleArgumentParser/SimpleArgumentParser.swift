// parseargs.swift

import Foundation

/// Simple command line argument parser for Swift
///
/// This parser allows you to define a set of options and flags for your command line tool, and then parse the provided arguments to extract the values of those options and flags, as well as any positional arguments. It also provides functionality to print help information and the results of the parsing operation.
public struct ArgumentParser {

    /// Optional description of the command line tool
    var description: String?
    /// Dictionary of options where the key is the option name and the value is an `Option` struct
    var options: [String: Option]?

    /// Initialize with optional description and options
    /// - Parameters:
    ///   - description: A brief description of the command line tool.
    ///   - options: The options this parser should recognize.
    public init(description: String? = nil, options: [Option] = []) {
        self.description = description
        self.options = Dictionary(uniqueKeysWithValues: options.map { ($0.cliName, $0) })
    }

    /// Parses the given command line arguments.
    /// - Parameter arguments: The command line arguments to parse.
    /// - Returns: The result of the parsing operation.
    /// - Throws: `ParseError.unknownOption` if an argument starting with `-` isn't a
    ///   recognized option, `ParseError.duplicateOption` if an option is passed more
    ///   than once, or `ParseError.missingValue` if a non-flag option isn't followed
    ///   by a value. Parsing stops at the first such problem.
    public func parse(arguments: [String]) throws -> ParseResult {
        // `arguments` is expected to be the full CommandLine.arguments, including
        // the executable path as the first element.
        var options: [String: Option] = options ?? [:]
        var positionalArguments: [String] = []
        var commandName: String = ""

        var remainingArguments: [String] = arguments
        if !remainingArguments.isEmpty {
            let commandPath: String = remainingArguments.removeFirst()
            commandName = commandPath.split(separator: "/").last.map(String.init) ?? commandPath
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
                    guard let optionValue = remainingArguments.first, !optionValue.starts(with: "-")
                    else {
                        throw ParseError.missingValue(arg)
                    }
                    remainingArguments.removeFirst()
                    option.value = optionValue
                }

                options[arg] = option
            } else {
                positionalArguments.append(arg)
            }
        }

        return ParseResult(
            commandName: commandName,
            arguments: positionalArguments,
            options: Dictionary(uniqueKeysWithValues: options.values.map { ($0.name, $0) }),
            description: description
        )
    }
}

/// Errors that can occur while parsing command line arguments.
public enum ParseError: Error, CustomStringConvertible {
    case unknownOption(String)
    case duplicateOption(String)
    case missingValue(String)

    public var description: String {
        switch self {
        case .unknownOption(let name):
            return "unknown option '\(name)'."
        case .duplicateOption(let name):
            return "option '\(name)' is already set."
        case .missingValue(let name):
            return "option '\(name)' expects a value but none was given."
        }
    }
}

/// Immutable outcome of parsing a set of command line arguments against a `ParseArgs` configuration.
public struct ParseResult {
    public let commandName: String
    public let arguments: [String]
    let options: [String: Option]
    let description: String?

    public subscript(name: String) -> String? {
        options[name]?.value
    }

    public func isSet(_ name: String) -> Bool {
        options[name]?.isSet ?? false
    }

    /// Prints the help information for the command line tool, including the overview, usage, and available options.
    public func printHelp() {
        print("OVERVIEW: \(description ?? "")", "\n")
        print("USAGE: \(commandName) [options] [flags] ARGUMENTS", "\n")
        print("OPTIONS:")
        for option: Option in options.values.sorted(by: { $0.name < $1.name }) {
            print("  \(option.cliName)\t\(option.helpText ?? "")")
        }
    }

    public func printResult() {
        for option: Option in options.values {
            if let value: String = option.value {
                print("\(option.cliName): \(value)")
            } else {
                print("\(option.cliName): \(option.isSet)")
            }
        }

        print("Positional arguments: \(arguments)")
    }
}

/// Represents a command line option or flag.
public struct Option {
    var name: String
    var isFlag: Bool = false
    var value: String?
    var helpText: String?
    var isSet: Bool = false

    /// The option's command-line form: one hyphen for single-character names (`-h`),
    /// two for longer ones (`--help`).
    var cliName: String {
        name.count == 1 ? "-\(name)" : "--\(name)"
    }

    /// - Parameter name: The option's bare name, without leading hyphens (e.g. `"h"`, `"help"`).
    ///   Look it up on a `ParseResult` with this same bare name (e.g. `isSet("h")`); use
    ///   `cliName` to get its command-line form.
    public init(name: String, isFlag: Bool = false, value: String? = nil, helpText: String? = nil) {
        precondition(!name.isEmpty, "Option name must not be empty.")
        precondition(
            !name.starts(with: "-"),
            "Option name '\(name)' should be given without leading '-': the parser adds '-' for single-character names and '--' for longer names."
        )
        precondition(
            !(isFlag && value != nil), "Option '\(name)' is a flag; it cannot have a default value."
        )

        self.name = name
        self.isFlag = isFlag
        self.helpText = helpText
        self.value = value
    }
}
