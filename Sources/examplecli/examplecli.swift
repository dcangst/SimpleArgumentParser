// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SimpleArgumentParser

@main
struct examplecli {
    static func main() {
        let parseArgs: ArgumentParser = ArgumentParser(
            description: "A simple Swift command line tool for parsing arguments.",
            options: [
                Option(name: "h", isFlag: true, helpText: "Show help information"),
                Option(name: "help", isFlag: true, helpText: "Show help information"),
                Option(name: "v", isFlag: true, helpText: "Show version information"),
                Option(name: "version", isFlag: true, helpText: "Show version information"),
                Option(name: "o", value: "default.txt", helpText: "Specify output file"),
            ]
        )
        let result: ParseResult
        do {
            result = try parseArgs.parse(arguments: CommandLine.arguments)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            exit(1)
        }

        if result.isSet("h") || result.isSet("help") {
            result.printHelp()
            return
        }

        result.printResult()

        print(result["o"] ?? "No output file specified.")
        print(result["v"] ?? "No version information specified.")

    }
}
