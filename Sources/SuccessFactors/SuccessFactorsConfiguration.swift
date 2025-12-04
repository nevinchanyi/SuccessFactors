//
//  SuccessFactorsConfiguration.swift
//  SuccessFactors
//
//  Created by Kostiantyn Nevinchanyi on 12/4/25.
//

import Foundation

/// Configuration options for SuccessFactors SDK
public struct SuccessFactorsConfiguration {
    
    // MARK: - Properties
    
    /// Maximum number of log entries to retain (default: 2000)
    public var maxLogEntries: Int
    
    /// Whether to enable file logging (default: true)
    public var enableFileLogging: Bool
    
    /// Whether to enable console logging for debugging (default: false)
    public var enableConsoleLogging: Bool
    
    /// The threshold for triggering rate updates (0.0 to 1.0, default: 0.0 - always notify)
    public var rateUpdateThreshold: Double
    
    /// Minimum number of factors before calculating meaningful rate (default: 5)
    public var minimumFactorsForRate: Int
    
    /// Custom directory for log storage (default: nil, uses app's documents directory)
    public var customLogDirectory: URL?
    
    /// Whether to persist factors across app sessions (default: true)
    public var persistFactors: Bool
    
    /// The filename for the log file (default: "success_factors.log")
    public var logFileName: String
    
    /// The filename for the factors data file (default: "success_factors_data.json")
    public var dataFileName: String
    
    /// The target success rate to trigger delegate notification (0.0 to 1.0, default: 0.95)
    public var targetRate: Double
    
    /// Whether to notify only once when target is reached, or every time rate crosses threshold (default: true)
    public var notifyTargetOnlyOnce: Bool
    
    // MARK: - Initialization
    
    /// Creates a new configuration with default values
    public init(
        maxLogEntries: Int = 2000,
        enableFileLogging: Bool = true,
        enableConsoleLogging: Bool = false,
        rateUpdateThreshold: Double = 0.0,
        minimumFactorsForRate: Int = 5,
        customLogDirectory: URL? = nil,
        persistFactors: Bool = true,
        logFileName: String = "success_factors.log",
        dataFileName: String = "success_factors_data.json",
        targetRate: Double = 0.95,
        notifyTargetOnlyOnce: Bool = true
    ) {
        self.maxLogEntries = max(100, maxLogEntries)
        self.enableFileLogging = enableFileLogging
        self.enableConsoleLogging = enableConsoleLogging
        self.rateUpdateThreshold = min(1.0, max(0.0, rateUpdateThreshold))
        self.minimumFactorsForRate = max(1, minimumFactorsForRate)
        self.customLogDirectory = customLogDirectory
        self.persistFactors = persistFactors
        self.logFileName = logFileName
        self.dataFileName = dataFileName
        self.targetRate = min(1.0, max(0.0, targetRate))
        self.notifyTargetOnlyOnce = notifyTargetOnlyOnce
    }
    
    // MARK: - Presets
    
    /// Default configuration
    public static let `default` = SuccessFactorsConfiguration()
    
    /// Debug configuration with console logging enabled
    public static let debug = SuccessFactorsConfiguration(
        enableConsoleLogging: true,
        minimumFactorsForRate: 1,
        notifyTargetOnlyOnce: false
    )
    
    /// Production configuration with higher thresholds
    public static let production = SuccessFactorsConfiguration(
        enableConsoleLogging: false,
        rateUpdateThreshold: 0.01,
        minimumFactorsForRate: 10,
        targetRate: 0.95,
        notifyTargetOnlyOnce: true
    )
}
