//
//  PackagePlugin+Utils.swift
//  
//
//  Created by Mathew Gacy on 12/3/23.
//

import Foundation
import PackagePlugin

extension PackagePlugin.Target {
    var debugDescription: String {
        if let sourceModuleTarget = self as? SourceModuleTarget {
            return """
                SourceModuleTarget(id: "\(id)", name: "\(name)", moduleName: "\(sourceModuleTarget.moduleName)", kind: ModuleKind.\(sourceModuleTarget.kind))
                """
        } else {
            return """
                Target(id: "\(id)", name: "\(name)", directory: \(directory))
                """
        }
    }
}
