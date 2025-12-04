# SuccessFactors SDK

A lightweight iOS SDK for measuring positive and negative user experiences in your app. Track success and failure signals, calculate experience rates, and trigger actions like App Store review requests based on user satisfaction.
Some users might have a positive experience with your app, others stuck on a screen without internet connection and swearing. Therefore, there is no need to ask them for a review, for example.

## Requirements

- iOS 12.0+
- macOS 10.14+
- tvOS 12.0+
- watchOS 5.0+
- Swift 5.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nevinchanyi/SuccessFactors.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Packages → Enter the repository URL.

### Manual Installation

Copy the `Sources/SuccessFactors` folder into your project.

## Quick Start

```swift
import SuccessFactors

// Log a success
SuccessFactors.success("Completed Todo", weight: 1.0)

// Log a failure
SuccessFactors.failure("Network Error", weight: 0.5, error: error)

// Check if rate is good enough for review
if SuccessFactors.shared.shouldRequestReview(threshold: 0.95) {
    // Request App Store review
}
```

## Usage

### Basic Logging

```swift
import SuccessFactors

// Success factors
SuccessFactors.shared.addSuccess("Created Todo List", weight: 2.0)
SuccessFactors.shared.addSuccess("Completed Todo", weight: 1.0)

// Failure factors
SuccessFactors.shared.addFailure(
    "Failed to sync",
    weight: 0.5,
    error: networkError,
    parameters: ["endpoint": "/api/sync"]
)
```

### Using the Factor Enum

```swift
// Success
SuccessFactors.shared.add(
    factor: .success(name: "Created List", weight: 2.0, parameters: ["listId": "123"])
)

// Failure
SuccessFactors.shared.add(
    factor: .failure(name: "Network Error", weight: 0.5, error: error, parameters: nil)
)
```

### Custom Factor Types

Define your own factors with the `FactorProtocol`:

```swift
struct TodoFactor: FactorProtocol {
    let type: FactorType
    let weight: Double
    let name: String
    let parameters: [String: Any]?
    let error: Error?
    
    // Factory methods for common actions
    static func createdList(id: String) -> TodoFactor {
        TodoFactor(
            type: .success,
            weight: 2.0,
            name: "Created Todo List",
            parameters: ["listId": id],
            error: nil
        )
    }
    
    static func completedTodo(id: String) -> TodoFactor {
        TodoFactor(
            type: .success,
            weight: 1.0,
            name: "Completed Todo",
            parameters: ["todoId": id],
            error: nil
        )
    }
    
    static func networkError(_ error: Error) -> TodoFactor {
        TodoFactor(
            type: .failure,
            weight: 0.5,
            name: "Network Error",
            parameters: nil,
            error: error
        )
    }
}

// Usage
SuccessFactors.shared.add(customFactor: TodoFactor.createdList(id: "list-123"))
SuccessFactors.shared.add(customFactor: TodoFactor.completedTodo(id: "todo-456"))
SuccessFactors.shared.add(customFactor: TodoFactor.networkError(error))
```

### Delegate Pattern

```swift
class AppCoordinator: SuccessFactorsDelegate {
    
    init() {
        SuccessFactors.shared.delegate = self
    }
    
    func successFactors(
        _ successFactors: SuccessFactors,
        didUpdateRate rate: Double,
        stats: SuccessFactors.Stats
    ) {
        print("Current rate: \(rate * 100)%")
    }
    
    func successFactors(
        _ successFactors: SuccessFactors,
        didLogFactor entry: FactorEntry
    ) {
        print("Logged: \(entry.logLine())")
    }
    
    // Called when rate reaches the configured target (e.g., 95%)
    func successFactors(
        _ successFactors: SuccessFactors,
        reachedTheTargetRate rate: Double,
        targetRate: Double,
        stats: SuccessFactors.Stats
    ) {
        print("Target rate \(targetRate * 100)% reached! Current: \(rate * 100)%")
        requestAppStoreReview()
    }
}
```

### Callback Pattern

```swift
// Rate update callback
SuccessFactors.shared.onRateUpdate = { rate, stats in
    print("Rate updated to \(rate * 100)%")
}

// Target rate reached callback (alternative to delegate)
SuccessFactors.shared.onTargetRateReached = { rate, targetRate, stats in
    print("Target \(targetRate * 100)% reached!")
    
    // Request App Store review
    if #available(iOS 14.0, *) {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
```

### Configuration

```swift
let config = SuccessFactorsConfiguration(
    maxLogEntries: 2000,           // Maximum log entries to keep
    enableFileLogging: true,        // Write logs to file
    enableConsoleLogging: false,    // Print to console (debug)
    rateUpdateThreshold: 0.01,      // Minimum rate change to trigger delegate
    minimumFactorsForRate: 10,      // Minimum factors before rate is meaningful
    persistFactors: true,           // Persist across app sessions
    targetRate: 0.95,               // Target rate to trigger reachedTheTargetRate (95%)
    notifyTargetOnlyOnce: true      // Only notify once when target is reached
)

SuccessFactors.shared.configure(with: config)

// Or use presets
SuccessFactors.shared.configure(with: .debug)
SuccessFactors.shared.configure(with: .production)

// Update target rate dynamically
SuccessFactors.shared.setTargetRate(0.90)  // Change to 90%
```

### Accessing Statistics

```swift
let stats = SuccessFactors.shared.currentStats

print("Success rate: \(stats.rate * 100)%")
print("Total factors: \(stats.totalCount)")
print("Success count: \(stats.successCount)")
print("Failure count: \(stats.failureCount)")
print("Total success weight: \(stats.totalSuccessWeight)")
print("Total failure weight: \(stats.totalFailureWeight)")
print("Has enough data: \(stats.hasEnoughData)")
```

### Rate Checking

```swift
// Check current rate
let rate = SuccessFactors.shared.currentRate

// Check if rate is above threshold
if SuccessFactors.shared.isRateAbove(0.95) {
    // Good experience rate
}

// Convenience method for App Store reviews
if SuccessFactors.shared.shouldRequestReview(threshold: 0.95) {
    SKStoreReviewController.requestReview()
}
```

### Log History

```swift
// Get factor entries
let entries = SuccessFactors.shared.getFactorHistory(count: 100)

for entry in entries {
    print(entry.logLine())
}

// Get formatted log lines
let logLines = SuccessFactors.shared.getLogHistory(count: 50)

// Get raw log content
if let rawLog = SuccessFactors.shared.getRawLogContent() {
    print(rawLog)
}

// Access log file URL
let logURL = SuccessFactors.shared.logFileURL
```

### Log Format

Each log entry follows this format:

```
[ISO8601 Date]:[Filename.swift]:methodName:success/failure: +/-weight, rate: XX.X%, {action: name, params: {...}, error: ...}
```

Example:
```
[2024-01-15T10:30:45.123Z]:[TodoViewController.swift]:createTodoList():success: +2.0, rate: 96.5%, {action: Created Todo List, params: {"listId":"123"}}
[2024-01-15T10:31:02.456Z]:[NetworkManager.swift]:syncData():failure: -0.5, rate: 95.2%, {action: Network Error, error: The Internet connection appears to be offline.}
```

### Reset Data

```swift
// Async reset
SuccessFactors.shared.reset()

// Sync reset (blocks until complete)
SuccessFactors.shared.resetSync()
```

## Complete Example: Todo App

```swift
import UIKit
import StoreKit
import SuccessFactors

class TodoViewController: UIViewController, SuccessFactorsDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure SDK with 95% target rate
        var config = SuccessFactorsConfiguration.production
        config.targetRate = 0.95
        config.notifyTargetOnlyOnce = true
        
        SuccessFactors.shared.configure(with: config)
        SuccessFactors.shared.delegate = self
    }
    
    // MARK: - Todo Actions
    
    func createTodoList(name: String) {
        apiClient.createList(name: name) { [weak self] result in
            switch result {
            case .success(let list):
                SuccessFactors.success(
                    "Created Todo List",
                    weight: 2.0,
                    parameters: ["listId": list.id, "name": name]
                )
                self?.showList(list)
                
            case .failure(let error):
                SuccessFactors.failure(
                    "Create List Failed",
                    weight: 0.5,
                    error: error,
                    parameters: ["name": name]
                )
                self?.showError(error)
            }
        }
    }
    
    func completeTodo(_ todo: Todo) {
        apiClient.complete(todo: todo) { [weak self] result in
            switch result {
            case .success:
                SuccessFactors.success(
                    "Completed Todo",
                    weight: 1.0,
                    parameters: ["todoId": todo.id]
                )
                self?.refreshList()
                
            case .failure(let error):
                SuccessFactors.failure(
                    "Complete Todo Failed",
                    weight: 0.5,
                    error: error
                )
                self?.showError(error)
            }
        }
    }
    
    // MARK: - SuccessFactorsDelegate
    
    func successFactors(
        _ successFactors: SuccessFactors,
        didUpdateRate rate: Double,
        stats: SuccessFactors.Stats
    ) {
        // Optional: Log rate changes
        print("Experience rate: \(Int(rate * 100))%")
    }
    
    func successFactors(
        _ successFactors: SuccessFactors,
        reachedTheTargetRate rate: Double,
        targetRate: Double,
        stats: SuccessFactors.Stats
    ) {
        // Triggered automatically when rate >= 95%
        if #available(iOS 14.0, *) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        } else {
            SKStoreReviewController.requestReview()
        }
    }
}
```

## Thread Safety

SuccessFactors is thread-safe. You can log factors from any queue:

```swift
DispatchQueue.global().async {
    SuccessFactors.success("Background Task Completed")
}

DispatchQueue.main.async {
    SuccessFactors.failure("UI Error", error: error)
}
```

## File Storage

Logs are stored in the app's Documents directory under `SuccessFactors/`:
- `success_factors.log` - Human-readable log entries
- `success_factors_data.json` - Persisted statistics and entries

## License

MIT License
