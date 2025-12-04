//
//  SuccessFactors.swift
//  SuccessFactors
//
//  Created by Kostiantyn Nevinchanyi on 12/4/25.
//

import Foundation

// MARK: - Delegate Protocol

/// Delegate protocol for receiving rate updates
public protocol SuccessFactorsDelegate: AnyObject {
    
    /// Called when the success rate is updated
    /// - Parameters:
    ///   - successFactors: The SuccessFactors instance
    ///   - rate: The current success rate (0.0 to 1.0)
    ///   - stats: Current statistics
    func successFactors(_ successFactors: SuccessFactors, didUpdateRate rate: Double, stats: SuccessFactors.Stats)
    
    /// Called when a factor is logged
    /// - Parameters:
    ///   - successFactors: The SuccessFactors instance
    ///   - entry: The logged factor entry
    func successFactors(_ successFactors: SuccessFactors, didLogFactor entry: FactorEntry)
    
    /// Called when the success rate reaches or exceeds the target rate
    /// - Parameters:
    ///   - successFactors: The SuccessFactors instance
    ///   - rate: The current success rate (0.0 to 1.0)
    ///   - targetRate: The configured target rate
    ///   - stats: Current statistics
    func successFactors(_ successFactors: SuccessFactors, reachedTheTargetRate rate: Double, targetRate: Double, stats: SuccessFactors.Stats)
}

// MARK: - Default Implementation

public extension SuccessFactorsDelegate {
    func successFactors(_ successFactors: SuccessFactors, didLogFactor entry: FactorEntry) {}
    func successFactors(_ successFactors: SuccessFactors, reachedTheTargetRate rate: Double, targetRate: Double, stats: SuccessFactors.Stats) {}
}

// MARK: - SuccessFactors

/// Main SDK class for tracking success and failure factors
public final class SuccessFactors {
    
    // MARK: - Stats
    
    /// Statistics about the tracked factors
    public struct Stats {
        public let totalSuccessWeight: Double
        public let totalFailureWeight: Double
        public let successCount: Int
        public let failureCount: Int
        public let totalCount: Int
        public let rate: Double
        public let lastUpdated: Date
        
        /// Whether there are enough factors to calculate a meaningful rate
        public let hasEnoughData: Bool
        
        public init(
            totalSuccessWeight: Double,
            totalFailureWeight: Double,
            successCount: Int,
            failureCount: Int,
            rate: Double,
            lastUpdated: Date,
            hasEnoughData: Bool
        ) {
            self.totalSuccessWeight = totalSuccessWeight
            self.totalFailureWeight = totalFailureWeight
            self.successCount = successCount
            self.failureCount = failureCount
            self.totalCount = successCount + failureCount
            self.rate = rate
            self.lastUpdated = lastUpdated
            self.hasEnoughData = hasEnoughData
        }
    }
    
    // MARK: - Singleton
    
    /// Shared instance of SuccessFactors
    public static let shared = SuccessFactors()
    
    // MARK: - Properties
    
    /// The delegate for receiving rate updates
    public weak var delegate: SuccessFactorsDelegate?
    
    /// Callback closure for rate updates (alternative to delegate)
    public var onRateUpdate: ((Double, Stats) -> Void)?
    
    /// Callback closure for when target rate is reached (alternative to delegate)
    public var onTargetRateReached: ((Double, Double, Stats) -> Void)?
    
    /// The current configuration
    public private(set) var configuration: SuccessFactorsConfiguration
    
    /// Whether the target rate has been reached (resets on configuration change or reset)
    public private(set) var hasReachedTarget: Bool = false
    
    /// The current success rate (0.0 to 1.0)
    public var currentRate: Double {
        lock.lock()
        defer { lock.unlock() }
        return _currentRate
    }
    
    /// The current statistics
    public var currentStats: Stats {
        lock.lock()
        defer { lock.unlock() }
        return buildStats()
    }
    
    // MARK: - Private Properties
    
    private var logger: SuccessFactorsLogger
    private var storage: SuccessFactorsStorage
    private var storedData: SuccessFactorsStorage.StoredData
    
    private var _currentRate: Double = 1.0
    private var previousRate: Double = 1.0
    
    private let lock = NSLock()
    private let notificationQueue = DispatchQueue(label: "com.successfactors.notifications", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        self.configuration = .default
        self.logger = SuccessFactorsLogger(configuration: configuration)
        self.storage = SuccessFactorsStorage(configuration: configuration)
        self.storedData = storage.load()
        self._currentRate = calculateRate()
        self.previousRate = _currentRate
    }
    
    // MARK: - Configuration
    
    /// Configures the SDK with the given configuration
    /// - Parameter configuration: The configuration to use
    public func configure(with configuration: SuccessFactorsConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        
        self.configuration = configuration
        self.logger = SuccessFactorsLogger(configuration: configuration)
        self.storage = SuccessFactorsStorage(configuration: configuration)
        self.storedData = storage.load()
        self._currentRate = calculateRate()
        self.previousRate = _currentRate
        self.hasReachedTarget = false
    }
    
    // MARK: - Logging Factors
    
    /// Adds a success factor
    /// - Parameters:
    ///   - name: Name of the success action
    ///   - weight: Weight of the factor (default: 1.0)
    ///   - parameters: Optional custom parameters
    ///   - file: Source file (auto-populated)
    ///   - function: Function name (auto-populated)
    ///   - line: Line number (auto-populated)
    public func addSuccess(
        _ name: String,
        weight: Double = 1.0,
        parameters: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        add(
            factor: .success(name: name, weight: weight, parameters: parameters),
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Adds a failure factor
    /// - Parameters:
    ///   - name: Name of the failure action
    ///   - weight: Weight of the factor (default: 1.0)
    ///   - error: Optional error associated with the failure
    ///   - parameters: Optional custom parameters
    ///   - file: Source file (auto-populated)
    ///   - function: Function name (auto-populated)
    ///   - line: Line number (auto-populated)
    public func addFailure(
        _ name: String,
        weight: Double = 1.0,
        error: Error? = nil,
        parameters: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        add(
            factor: .failure(name: name, weight: weight, error: error, parameters: parameters),
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Adds a factor using the Factor enum
    /// - Parameters:
    ///   - factor: The factor to add
    ///   - file: Source file (auto-populated)
    ///   - function: Function name (auto-populated)
    ///   - line: Line number (auto-populated)
    public func add(
        factor: Factor,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        
        lock.lock()
        
        // Update totals
        switch factor.type {
        case .success:
            storedData.totalSuccessWeight += factor.weight
            storedData.successCount += 1
        case .failure:
            storedData.totalFailureWeight += factor.weight
            storedData.failureCount += 1
        }
        storedData.lastUpdated = Date()
        
        // Calculate new rate
        _currentRate = calculateRate()
        
        // Create entry
        let entry = FactorEntry(
            type: factor.type,
            name: factor.name,
            weight: factor.weight,
            fileName: fileName,
            methodName: function,
            line: line,
            parameters: factor.parameters,
            error: factor.error,
            rateAtTime: _currentRate
        )
        
        storedData.entries.append(entry)
        
        // Save
        storage.save(storedData)
        logger.log(entry)
        
        let stats = buildStats()
        let rate = _currentRate
        let shouldNotify = abs(rate - previousRate) >= configuration.rateUpdateThreshold
        previousRate = rate
        
        // Check if target rate is reached
        let targetRate = configuration.targetRate
        let totalCount = storedData.successCount + storedData.failureCount
        let hasEnoughData = totalCount >= configuration.minimumFactorsForRate
        let targetReached = hasEnoughData && rate >= targetRate
        
        var shouldNotifyTarget = false
        if targetReached {
            if configuration.notifyTargetOnlyOnce {
                if !hasReachedTarget {
                    hasReachedTarget = true
                    shouldNotifyTarget = true
                }
            } else {
                shouldNotifyTarget = true
            }
        }
        
        lock.unlock()
        
        // Notify on separate queue to avoid blocking
        notificationQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.delegate?.successFactors(self, didLogFactor: entry)
            
            if shouldNotify {
                self.delegate?.successFactors(self, didUpdateRate: rate, stats: stats)
                self.onRateUpdate?(rate, stats)
            }
            
            if shouldNotifyTarget {
                self.delegate?.successFactors(self, reachedTheTargetRate: rate, targetRate: targetRate, stats: stats)
                self.onTargetRateReached?(rate, targetRate, stats)
            }
        }
    }
    
    /// Adds a custom factor conforming to FactorProtocol
    /// - Parameters:
    ///   - customFactor: The custom factor to add
    ///   - file: Source file (auto-populated)
    ///   - function: Function name (auto-populated)
    ///   - line: Line number (auto-populated)
    public func add<T: FactorProtocol>(
        customFactor: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        switch customFactor.type {
        case .success:
            add(
                factor: .success(name: customFactor.name, weight: customFactor.weight, parameters: customFactor.parameters),
                file: file,
                function: function,
                line: line
            )
        case .failure:
            add(
                factor: .failure(name: customFactor.name, weight: customFactor.weight, error: customFactor.error, parameters: customFactor.parameters),
                file: file,
                function: function,
                line: line
            )
        }
    }
    
    // MARK: - Rate Checking
    
    /// Checks if the current rate meets or exceeds the given threshold
    /// - Parameter threshold: The threshold to check (0.0 to 1.0)
    /// - Returns: True if rate >= threshold and there's enough data
    public func isRateAbove(_ threshold: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let totalCount = storedData.successCount + storedData.failureCount
        guard totalCount >= configuration.minimumFactorsForRate else {
            return false
        }
        
        return _currentRate >= threshold
    }
    
    /// Checks if the app should request a review based on the success rate
    /// - Parameter threshold: The minimum success rate required (default: 0.95)
    /// - Returns: True if conditions are met for requesting a review
    public func shouldRequestReview(threshold: Double = 0.95) -> Bool {
        return isRateAbove(threshold)
    }
    
    // MARK: - History
    
    /// Returns the factor entries from storage
    /// - Parameter count: Maximum number of entries to return (nil for all)
    /// - Returns: Array of factor entries
    public func getFactorHistory(count: Int? = nil) -> [FactorEntry] {
        lock.lock()
        defer { lock.unlock() }
        
        if let count = count {
            return Array(storedData.entries.suffix(count))
        }
        return storedData.entries
    }
    
    /// Returns the log entries as formatted strings
    /// - Parameter count: Maximum number of entries to return (nil for max configured)
    /// - Returns: Array of log line strings
    public func getLogHistory(count: Int? = nil) -> [String] {
        return logger.getLogEntries(count: count)
    }
    
    /// Returns the raw log content
    /// - Returns: The raw log file content as a string
    public func getRawLogContent() -> String? {
        return logger.getRawLogContent()
    }
    
    /// Returns the URL of the log file
    public var logFileURL: URL {
        return logger.logURL
    }
    
    /// Returns the URL of the data file
    public var dataFileURL: URL {
        return storage.dataURL
    }
    
    // MARK: - Reset
    
    /// Resets all tracked factors and clears logs
    public func reset() {
        lock.lock()
        storedData = .empty
        _currentRate = 1.0
        previousRate = 1.0
        hasReachedTarget = false
        storage.clear()
        logger.clearLogs()
        lock.unlock()
    }
    
    /// Resets all tracked factors and clears logs synchronously
    public func resetSync() {
        lock.lock()
        storedData = .empty
        _currentRate = 1.0
        previousRate = 1.0
        hasReachedTarget = false
        storage.clearSync()
        logger.clearLogsSync()
        lock.unlock()
    }
    
    /// Resets the target reached flag, allowing the delegate to be notified again
    public func resetTargetReachedFlag() {
        lock.lock()
        hasReachedTarget = false
        lock.unlock()
    }
    
    /// Updates the target rate
    /// - Parameter rate: The new target rate (0.0 to 1.0)
    /// - Parameter resetFlag: Whether to reset the hasReachedTarget flag (default: true)
    public func setTargetRate(_ rate: Double, resetFlag: Bool = true) {
        lock.lock()
        configuration.targetRate = min(1.0, max(0.0, rate))
        if resetFlag {
            hasReachedTarget = false
        }
        lock.unlock()
    }
    
    /// The current target rate
    public var targetRate: Double {
        lock.lock()
        defer { lock.unlock() }
        return configuration.targetRate
    }
    
    // MARK: - Private Methods
    
    private func calculateRate() -> Double {
        let totalWeight = storedData.totalSuccessWeight + storedData.totalFailureWeight
        guard totalWeight > 0 else { return 1.0 }
        return storedData.totalSuccessWeight / totalWeight
    }
    
    private func buildStats() -> Stats {
        let totalCount = storedData.successCount + storedData.failureCount
        return Stats(
            totalSuccessWeight: storedData.totalSuccessWeight,
            totalFailureWeight: storedData.totalFailureWeight,
            successCount: storedData.successCount,
            failureCount: storedData.failureCount,
            rate: _currentRate,
            lastUpdated: storedData.lastUpdated,
            hasEnoughData: totalCount >= configuration.minimumFactorsForRate
        )
    }
}

// MARK: - Convenience Extensions

public extension SuccessFactors {
    
    /// Quick success logging
    static func success(
        _ name: String,
        weight: Double = 1.0,
        parameters: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        shared.addSuccess(name, weight: weight, parameters: parameters, file: file, function: function, line: line)
    }
    
    /// Quick failure logging
    static func failure(
        _ name: String,
        weight: Double = 1.0,
        error: Error? = nil,
        parameters: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        shared.addFailure(name, weight: weight, error: error, parameters: parameters, file: file, function: function, line: line)
    }
    
    /// Quick rate check
    static var rate: Double {
        shared.currentRate
    }
    
    /// Quick stats access
    static var stats: Stats {
        shared.currentStats
    }
}
