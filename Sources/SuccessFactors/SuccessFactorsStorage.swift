//
//  SuccessFactorsStorage.swift
//  SuccessFactors
//
//  Created by Kostiantyn Nevinchanyi on 12/4/25.
//

import Foundation

/// Handles persistence of factor statistics
final class SuccessFactorsStorage {
    
    // MARK: - Storage Data Model
    
    struct StoredData: Codable {
        var totalSuccessWeight: Double
        var totalFailureWeight: Double
        var successCount: Int
        var failureCount: Int
        var lastUpdated: Date
        var entries: [FactorEntry]
        
        static var empty: StoredData {
            return StoredData(
                totalSuccessWeight: 0,
                totalFailureWeight: 0,
                successCount: 0,
                failureCount: 0,
                lastUpdated: Date(),
                entries: []
            )
        }
    }
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let configuration: SuccessFactorsConfiguration
    private let dataFileURL: URL
    private let queue = DispatchQueue(label: "com.successfactors.storage", qos: .utility)
    
    private var cachedData: StoredData?
    
    // MARK: - Initialization
    
    init(configuration: SuccessFactorsConfiguration) {
        self.configuration = configuration
        
        let directory: URL
        if let customDir = configuration.customLogDirectory {
            directory = customDir
        } else {
            directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("SuccessFactors", isDirectory: true)
        }
        
        // Create directory if needed
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        
        self.dataFileURL = directory.appendingPathComponent(configuration.dataFileName)
    }
    
    // MARK: - Public Methods
    
    /// Loads stored data from disk
    func load() -> StoredData {
        if let cached = cachedData {
            return cached
        }
        
        guard configuration.persistFactors,
              let data = try? Data(contentsOf: dataFileURL),
              let storedData = try? JSONDecoder().decode(StoredData.self, from: data) else {
            let empty = StoredData.empty
            cachedData = empty
            return empty
        }
        
        cachedData = storedData
        return storedData
    }
    
    /// Saves data to disk
    func save(_ data: StoredData) {
        cachedData = data
        
        guard configuration.persistFactors else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var trimmedData = data
            // Keep only recent entries to limit storage size
            if trimmedData.entries.count > self.configuration.maxLogEntries {
                trimmedData.entries = Array(trimmedData.entries.suffix(self.configuration.maxLogEntries))
            }
            
            if let encoded = try? JSONEncoder().encode(trimmedData) {
                try? encoded.write(to: self.dataFileURL, options: .atomic)
            }
        }
    }
    
    /// Saves data to disk synchronously
    func saveSync(_ data: StoredData) {
        cachedData = data
        
        guard configuration.persistFactors else { return }
        
        var trimmedData = data
        if trimmedData.entries.count > configuration.maxLogEntries {
            trimmedData.entries = Array(trimmedData.entries.suffix(configuration.maxLogEntries))
        }
        
        if let encoded = try? JSONEncoder().encode(trimmedData) {
            try? encoded.write(to: dataFileURL, options: .atomic)
        }
    }
    
    /// Clears all stored data
    func clear() {
        cachedData = StoredData.empty
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.dataFileURL)
        }
    }
    
    /// Clears all stored data synchronously
    func clearSync() {
        cachedData = StoredData.empty
        try? fileManager.removeItem(at: dataFileURL)
    }
    
    /// Invalidates the cache, forcing a reload from disk on next access
    func invalidateCache() {
        cachedData = nil
    }
    
    /// Returns the URL of the data file
    var dataURL: URL {
        return dataFileURL
    }
}
