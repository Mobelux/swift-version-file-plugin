//
//  VersionFile.swift
//
//
//  Created by Mathew Gacy on 11/23/22.
//

import Foundation
import PackagePlugin

/// Constants used by the VersionFile plugin.
enum Constants {
    /// The name of the version file.
    static let versionFile = "Version.swift"
    /// A regular expression pattern for a semantic version number.
    static let versionPattern = #"([0-9]+\.*)+"#
}

/// A semantic version release type.
enum Release: String, CaseIterable {
    /// Increment the patch version.
    case patch
    /// Increment the minor version.
    case minor
    /// Increment the major version.
    case major
    /// Increment the pre-release version.
    case release
    /// Increment the pre-release version.
    case prerelease = "prerel"
}

/// A VersionFile plugin command.
enum Command {
    /// Bump a VersionFile with the given release type.
    case bump(Release)
    /// Create a VersionFile with the given version string.
    case create(String)
}

/// The entry point of the VersionFile plugin.
@main
struct VersionFile: CommandPlugin {
    /// This entry point is called when operating on a Swift package.
    func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        if arguments.contains("--verbose") {
            let targetsDescription = context.package.targets.map(\.debugDescription).joined(separator: "\n  - ")
            let packageDescription = "`\(context.package.displayName)`.\nTargets:\n  - \(targetsDescription)"
            print("\nCommand plugin execution with arguments `\(arguments.description)` for Swift package \(packageDescription)\n")
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
    /// Extracts a ``Command`` from the given argument extractor and returns it.
    ///
    /// - Parameter argExtractor: The argument extractor.
    /// - Returns: The extracted command.
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

    /// Returns the targets to process in the given package.
    ///
    /// - Parameters:
    ///   - package: The package to process.
    ///   - selectedTargets: The names of the targets to process.
    /// - Returns: The targets to process.
    func targetsToProcess(in package: Package, selectedTargets: [String]) -> [SourceModuleTarget] {
        var targetsToProcess: [Target] = package.targets
        if selectedTargets.isEmpty == false {
            targetsToProcess = package.targets.filter { selectedTargets.contains($0.name) }
        }

        return targetsToProcess.compactMap { target in
            guard let target = target as? SourceModuleTarget else {
                return nil
            }

            switch target.kind {
            case .generic, .executable:
                return target
            case .test:
                return nil
            }
        }
    }

    /// Returns the current version number from the version file at the given path.
    ///
    /// - Parameter path: The path to the version file.
    /// - Returns:  The current version number.
    func currentVersion(path: Path) throws -> String {
        let fileContents = try String(contentsOfFile: path.string)

        let regEx = try NSRegularExpression(pattern: Constants.versionPattern)
        guard let versionString = fileContents.matches(for: regEx).first else {
            throw "Unable to parse current version number from \(fileContents)"
        }

        return versionString
    }

    /// Returns the contents of a version file for the given version number.
    ///
    /// - Parameter version: The version number.
    /// - Returns: The version file contents
    func makeVersion(_ version: String) -> String {
        """
        // This file was generated by the `VersionFile` package plugin.

        /// Namespace for the current version of the target in which this file is contained.
        enum Version {
            /// The current version number.
            static let number = "\(version)"
        }
        """
    }

    /// Writes a version file with the given version number to the given path.
    ///
    /// - Parameters:
    ///   - version: The version number.
    ///   - path: The path to the version file.
    func writeVersionFile(_ version: String, in path: Path) throws {
        let fileContents = makeVersion(version)
        try fileContents.write(toFile: path.string, atomically: true, encoding: .utf8)
    }

    /// Runs the given tool with the given arguments and returns the output.
    ///
    /// - Parameters:
    ///   - tool: The tool to run.
    ///   - arguments: The arguments to pass to the tool.
    /// - Returns: The output of the tool.
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
