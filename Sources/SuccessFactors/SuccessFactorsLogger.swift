//
//  SuccessFactorsLogger.swift
//  SuccessFactors
//
//  Created by Kostiantyn Nevinchanyi on 12/4/25.
//

import Foundation

/// Handles file-based logging for SuccessFactors
final class SuccessFactorsLogger {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let configuration: SuccessFactorsConfiguration
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.successfactors.logger", qos: .utility)
    
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
        
        self.logFileURL = directory.appendingPathComponent(configuration.logFileName)
    }
    
    // MARK: - Public Methods
    
    /// Logs a factor entry to the file
    func log(_ entry: FactorEntry) {
        guard configuration.enableFileLogging else { return }
        
        queue.async { [weak self] in
            self?.writeEntry(entry)
        }
    }
    
    /// Logs a factor entry synchronously (for testing or immediate writes)
    func logSync(_ entry: FactorEntry) {
        guard configuration.enableFileLogging else { return }
        writeEntry(entry)
    }
    
    /// Retrieves the last N log entries (up to maxLogEntries)
    func getLogEntries(count: Int? = nil) -> [String] {
        let maxCount = count ?? configuration.maxLogEntries
        
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            return []
        }
        
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        let resultCount = min(maxCount, lines.count)
        return Array(lines.suffix(resultCount))
    }
    
    /// Retrieves the raw log content as a string
    func getRawLogContent() -> String? {
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }
    
    /// Clears all log entries
    func clearLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.logFileURL)
        }
    }
    
    /// Clears all log entries synchronously
    func clearLogsSync() {
        try? fileManager.removeItem(at: logFileURL)
    }
    
    /// Returns the URL of the log file
    var logURL: URL {
        return logFileURL
    }
    
    // MARK: - Private Methods
    
    private func writeEntry(_ entry: FactorEntry) {
        let logLine = entry.logLine() + "\n"
        
        if configuration.enableConsoleLogging {
            print("[SuccessFactors] \(logLine)")
        }
        
        // Create file if it doesn't exist
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        // Append to file
        guard let fileHandle = try? FileHandle(forWritingTo: logFileURL) else {
            return
        }
        
        defer {
            if #available(iOS 13.0, *) {
                try? fileHandle.close()
            } else {
                fileHandle.closeFile()
            }
        }
        
        if #available(iOS 13.4, *) {
            try? fileHandle.seekToEnd()
        } else {
            fileHandle.seekToEndOfFile()
        }
        
        if let data = logLine.data(using: .utf8) {
            if #available(iOS 13.4, *) {
                try? fileHandle.write(contentsOf: data)
            } else {
                fileHandle.write(data)
            }
        }
        
        // Trim file if needed
        trimLogFileIfNeeded()
    }
    
    private func trimLogFileIfNeeded() {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            return
        }
        
        var lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        if lines.count > configuration.maxLogEntries {
            // Keep only the last maxLogEntries
            lines = Array(lines.suffix(configuration.maxLogEntries))
            let newContent = lines.joined(separator: "\n") + "\n"
            try? newContent.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
}
