//
//  ArgumentExtractor+Utils.swift
//
//
//  Created by Mathew Gacy on 12/3/23.
//

import struct PackagePlugin.ArgumentExtractor

extension ArgumentExtractor {
    /// Extracts a ``Command`` from the remaining arguments and returns it.
    mutating func extractCommand() throws -> Command {
        if let releaseString = extractOption(named: "bump").first {
            guard let release = Release(rawValue: releaseString) else {
                let validOptions = Release.allCases.map { $0.rawValue }.joined(separator: " | ")
                throw "Invalid bump value `\(releaseString)` - valid options are: \(validOptions)"
            }

            return .bump(release)
        } else if let versionString = extractOption(named: "create").first {
            return .create(versionString)
        } else {
            throw "Unknown arguments"
        }
    }
}
