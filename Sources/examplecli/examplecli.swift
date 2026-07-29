// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SimpleArgumentParser

@main
struct examplecli {
    static func main() {
        let parseArgs: ArgumentParser = ArgumentParser(
            description:
                "A simple Swift command line tool for parsing arguments lorem lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
            options: [
                Option(name: "f", isFlag: true, help: "A flag option"),
                Option(
                    name: "foo",
                    help:
                        "An option that is required, no default"
                ),
                Option(
                    name: "bar",
                    defaultValue: "Fish and Chips",
                    help: "An optional option with a default value"),
                Option(
                    name: "foobar",
                    possibleValues: ["small", "medium", "large"],
                    help: "A required option with a set of possible values, no default"),
                Option(
                    name: "foofoo", defaultValue: "blue",
                    possibleValues: ["green", "red", "blue"],
                    help: "An optional option with a set of possible values"),
            ],
            // pass [] (the default) to reject any positional arguments, a single variadic
            // Argument to accept any number of unnamed ones, or a list of Argument objects
            // to require a specific number and name them for usage output
            arguments: [
                Argument(name: "INPUTPATH"), Argument(name: "OUTPUTPATH"),
                Argument(name: "FILES", isVariadic: true),
            ],
        )
        let result: ParseResult
        do {
            result = try parseArgs.parse(arguments: CommandLine.arguments)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            exit(1)
        }

        print(
            "the flag is: \(result["f"])"
        )
        // get a boolean with `result.isSet("f")`
        print("Required option: \(result["foo"])")
        print("Optional option: \(result["bar"])")

        print("Required option with possible values: \(result["foobar"])")
        print("Optional option with possible values: \(result["foofoo"])")
        print("Named argument 1 INPUTPATH (required): \(result.arguments[0])")
        print("Named argument 2 OUTPUTPATH (required): \(result.arguments[1])")
        if result.arguments.count > 2 {
            print("Variadic argument 3 FILES (optional): \(result.arguments[2...])")
        }
    }
}
