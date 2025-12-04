//
//  Factor.swift
//  SuccessFactors
//
//  Created by Kostiantyn Nevinchanyi on 12/4/25.
//

import Foundation

// MARK: - Factor Type

/// Represents the type of factor: success or failure
public enum FactorType: String, Codable {
    case success
    case failure
}

// MARK: - Factor Protocol

/// Protocol for defining custom factors with associated metadata
public protocol FactorProtocol {
    /// The type of factor (success or failure)
    var type: FactorType { get }
    
    /// The weight of this factor (default: 1.0)
    var weight: Double { get }
    
    /// A descriptive name for the factor
    var name: String { get }
    
    /// Custom parameters associated with this factor
    var parameters: [String: Any]? { get }
    
    /// Optional error associated with failure factors
    var error: Error? { get }
}

// MARK: - Default Implementation

public extension FactorProtocol {
    var weight: Double { 1.0 }
    var parameters: [String: Any]? { nil }
    var error: Error? { nil }
}

// MARK: - Built-in Factor

/// A built-in factor type for quick logging
public enum Factor {
    case success(name: String, weight: Double = 1.0, parameters: [String: Any]? = nil)
    case failure(name: String, weight: Double = 1.0, error: Error? = nil, parameters: [String: Any]? = nil)
    
    public var type: FactorType {
        switch self {
        case .success: return .success
        case .failure: return .failure
        }
    }
    
    public var weight: Double {
        switch self {
        case .success(_, let weight, _): return weight
        case .failure(_, let weight, _, _): return weight
        }
    }
    
    public var name: String {
        switch self {
        case .success(let name, _, _): return name
        case .failure(let name, _, _, _): return name
        }
    }
    
    public var parameters: [String: Any]? {
        switch self {
        case .success(_, _, let params): return params
        case .failure(_, _, _, let params): return params
        }
    }
    
    public var error: Error? {
        switch self {
        case .success: return nil
        case .failure(_, _, let error, _): return error
        }
    }
}

// MARK: - Factor Entry (Stored)

/// A recorded factor entry with timestamp and source information
public struct FactorEntry: Codable {
    public let id: UUID
    public let date: Date
    public let type: FactorType
    public let name: String
    public let weight: Double
    public let fileName: String
    public let methodName: String
    public let line: Int
    public let parametersJSON: String?
    public let errorDescription: String?
    public let rateAtTime: Double
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: FactorType,
        name: String,
        weight: Double,
        fileName: String,
        methodName: String,
        line: Int,
        parameters: [String: Any]?,
        error: Error?,
        rateAtTime: Double
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.name = name
        self.weight = weight
        self.fileName = fileName
        self.methodName = methodName
        self.line = line
        self.parametersJSON = Self.encodeParameters(parameters)
        self.errorDescription = error?.localizedDescription
        self.rateAtTime = rateAtTime
    }
    
    private static func encodeParameters(_ parameters: [String: Any]?) -> String? {
        guard let parameters = parameters else { return nil }
        
        // Convert to JSON-safe dictionary
        let safeDict = parameters.mapValues { value -> Any in
            if let stringValue = value as? String { return stringValue }
            if let intValue = value as? Int { return intValue }
            if let doubleValue = value as? Double { return doubleValue }
            if let boolValue = value as? Bool { return boolValue }
            return String(describing: value)
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: safeDict, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    /// Formats the entry as a log line
    public func logLine() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = dateFormatter.string(from: date)
        
        let typeSymbol = type == .success ? "+" : "-"
        let ratePercentage = String(format: "%.1f%%", rateAtTime * 100)
        
        var actionString = "{action: \(name)"
        if let params = parametersJSON {
            actionString += ", params: \(params)"
        }
        if let errorDesc = errorDescription {
            actionString += ", error: \(errorDesc)"
        }
        actionString += "}"
        
        return "[\(dateString)]:[\(fileName)]:\(methodName):\(type.rawValue): \(typeSymbol)\(weight), rate: \(ratePercentage), \(actionString)"
    }
}
