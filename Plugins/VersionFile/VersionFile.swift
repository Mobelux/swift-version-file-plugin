//
//  VersionFile.swift
//
//
//  Created by Mathew Gacy on 11/23/22.
//

import Foundation
import PackagePlugin

enum Constants {
    static let versionFile = "Version.swift"
    static let versionPattern = #"([0-9]+\.*)+"#
}

enum Release: String, CaseIterable {
    case patch
    case minor
    case major
    case release
    case prerelease = "prerel"
}

enum Command {
    case bump(Release)
    case create(String)
}

@main
struct VersionFile: CommandPlugin {
    /// This entry point is called when operating on a Swift package.
    func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        if arguments.contains("--verbose") {
            print("Command plugin execution with arguments \(arguments.description) for Swift package \(context.package.displayName). All target information: \(context.package.targets.description)")
        }

        var argExtractor = ArgumentExtractor(arguments)
        let selectedTargets = argExtractor.extractOption(named: "target")

        let command = try extractCommand(from: &argExtractor)
        let targets = targetsToProcess(in: context.package, selectedTargets: selectedTargets)

        let semver = try context.tool(named: "semver")

        try targets.forEach { target in
            let versionPath = target.directory.appending(subpath: Constants.versionFile)

            switch command {
            case .bump(let release):
                let currentVersion = try currentVersion(path: versionPath)

                let bumpedVersion = try run(
                    tool: semver,
                    with: ["bump", release.rawValue, currentVersion])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                try writeVersionFile(bumpedVersion, in: versionPath)

                print(bumpedVersion)
            case .create(let version):
                try writeVersionFile(version, in: versionPath)
            }
        }
    }
}

private extension VersionFile {
    func extractCommand(from argExtractor: inout ArgumentExtractor) throws -> Command {
        if let releaseString = argExtractor.extractOption(named: "bump").first {
            guard let release = Release(rawValue: releaseString) else {
                let validOptions = Release.allCases.map { $0.rawValue }.joined(separator: " | ")
                throw "Invalid bump value `\(releaseString)` - valid options are: \(validOptions)"
            }

            return .bump(release)
        } else if let versionString = argExtractor.extractOption(named: "create").first {
            return .create(versionString)
        } else {
            throw "Unknown arguments"
        }
    }

    func targetsToProcess(in package: Package, selectedTargets: [String]) -> [SourceModuleTarget] {
        var targetsToProcess: [Target] = package.targets
        if selectedTargets.isEmpty == false {
            targetsToProcess = package.targets.filter { selectedTargets.contains($0.name) }.map { $0 }
        }

        return targetsToProcess.compactMap { target in
            guard let target = target as? SourceModuleTarget, case .generic = target.kind else {
                return nil
            }

            return target
        }
    }

    func currentVersion(path: Path) throws -> String {
        let fileContents = try String(contentsOfFile: path.string)

        let regEx = try NSRegularExpression(pattern: Constants.versionPattern)
        guard let versionString = fileContents.matches(for: regEx).first else {
            throw "Unable to parse current version number from \(fileContents)"
        }

        return versionString
    }

    func makeVersion(_ version: String) -> String {
        """
        // This file was generated by the `VersionFile` package plugin.

        enum Version {
            static let number = "\(version)"
        }
        """
    }

    func writeVersionFile(_ version: String, in path: Path) throws {
        let fileContents = makeVersion(version)
        try fileContents.write(toFile: path.string, atomically: true, encoding: .utf8)
    }

    func run(tool: PluginContext.Tool, with arguments: [String]) throws -> String {
        let outputPipe = Pipe()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.path.string)
        process.arguments = arguments
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        // Check whether the subprocess invocation was successful.
        if process.terminationReason == .exit && process.terminationStatus == 0 {
            return String(
                decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self)
        } else {
            let problem = "\(process.terminationReason):\(process.terminationStatus)"
            Diagnostics.error("\(tool) invocation failed: \(problem)")
            throw problem
        }
    }
}
