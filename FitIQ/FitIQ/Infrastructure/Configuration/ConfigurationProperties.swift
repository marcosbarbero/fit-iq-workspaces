//
//  ConfigurationProperties.swift
//
//  Created by Marcos Barbero on 10/10/2025.
//

import Foundation

final class ConfigurationProperties {
    
    static func value(for key: String) -> String? {
        guard
            let path = Bundle.main.path(forResource: "config", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path)
                as? [String: AnyObject],
            let value = dict[key] as? String
        else {
            print("Error: Could not find key '\(key)' in config.plist")
            return nil
        }
        return value
    }
}
