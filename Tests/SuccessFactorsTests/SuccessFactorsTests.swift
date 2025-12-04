import XCTest
@testable import SuccessFactors


import XCTest
@testable import SuccessFactors

final class SuccessFactorsTests: XCTestCase {
    
    var sut: SuccessFactors!
    
    override func setUp() {
        super.setUp()
        sut = SuccessFactors.shared
        sut.configure(with: SuccessFactorsConfiguration(
            enableFileLogging: false,
            minimumFactorsForRate: 1,
            persistFactors: false
        ))
        sut.resetSync()
    }
    
    override func tearDown() {
        sut.resetSync()
        super.tearDown()
    }
    
    // MARK: - Basic Rate Tests
    
    func testInitialRateIsOne() {
        XCTAssertEqual(sut.currentRate, 1.0, accuracy: 0.001)
    }
    
    func testAddSuccessKeepsRateAtOne() {
        sut.addSuccess("Test Success")
        XCTAssertEqual(sut.currentRate, 1.0, accuracy: 0.001)
    }
    
    func testAddFailureReducesRate() {
        sut.addSuccess("Test Success", weight: 1.0)
        sut.addFailure("Test Failure", weight: 1.0)
        
        // 1 success, 1 failure = 50%
        XCTAssertEqual(sut.currentRate, 0.5, accuracy: 0.001)
    }
    
    func testWeightedFactors() {
        sut.addSuccess("Create Todo List", weight: 2.0)
        sut.addSuccess("Complete Todo", weight: 1.0)
        sut.addFailure("Network Error", weight: 0.5)
        
        // Success: 2 + 1 = 3, Failure: 0.5
        // Rate = 3 / 3.5 = 0.857
        XCTAssertEqual(sut.currentRate, 3.0 / 3.5, accuracy: 0.001)
    }
    
    // MARK: - Stats Tests
    
    func testStatsAreAccurate() {
        sut.addSuccess("Success 1", weight: 2.0)
        sut.addSuccess("Success 2", weight: 1.0)
        sut.addFailure("Failure 1", weight: 0.5)
        
        let stats = sut.currentStats
        
        XCTAssertEqual(stats.successCount, 2)
        XCTAssertEqual(stats.failureCount, 1)
        XCTAssertEqual(stats.totalCount, 3)
        XCTAssertEqual(stats.totalSuccessWeight, 3.0, accuracy: 0.001)
        XCTAssertEqual(stats.totalFailureWeight, 0.5, accuracy: 0.001)
    }
    
    // MARK: - Threshold Tests
    
    func testIsRateAboveThreshold() {
        // Add enough factors to meet minimum
        for _ in 0..<19 {
            sut.addSuccess("Success")
        }
        sut.addFailure("Failure")
        
        // 19 success, 1 failure = 95%
        XCTAssertTrue(sut.isRateAbove(0.95))
        XCTAssertFalse(sut.isRateAbove(0.96))
    }
    
    func testShouldRequestReview() {
        for _ in 0..<95 {
            sut.addSuccess("Success")
        }
        for _ in 0..<5 {
            sut.addFailure("Failure")
        }
        
        XCTAssertTrue(sut.shouldRequestReview(threshold: 0.95))
    }
    
    // MARK: - Factor Enum Tests
    
    func testFactorEnum() {
        sut.add(factor: .success(name: "Created List", weight: 2.0, parameters: ["listId": "123"]))
        sut.add(factor: .failure(name: "Network Error", weight: 0.5, error: NSError(domain: "Test", code: -1, userInfo: nil)))
        
        let stats = sut.currentStats
        XCTAssertEqual(stats.successCount, 1)
        XCTAssertEqual(stats.failureCount, 1)
        XCTAssertEqual(stats.totalSuccessWeight, 2.0, accuracy: 0.001)
        XCTAssertEqual(stats.totalFailureWeight, 0.5, accuracy: 0.001)
    }
    
    // MARK: - History Tests
    
    func testFactorHistory() {
        sut.addSuccess("Success 1")
        sut.addFailure("Failure 1")
        sut.addSuccess("Success 2")
        
        let history = sut.getFactorHistory()
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history[0].name, "Success 1")
        XCTAssertEqual(history[1].name, "Failure 1")
        XCTAssertEqual(history[2].name, "Success 2")
    }
    
    func testLimitedHistory() {
        for i in 0..<10 {
            sut.addSuccess("Success \(i)")
        }
        
        let history = sut.getFactorHistory(count: 5)
        XCTAssertEqual(history.count, 5)
        XCTAssertEqual(history[0].name, "Success 5")
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        sut.addSuccess("Success")
        sut.addFailure("Failure")
        
        sut.resetSync()
        
        XCTAssertEqual(sut.currentRate, 1.0, accuracy: 0.001)
        XCTAssertEqual(sut.currentStats.totalCount, 0)
    }
    
    // MARK: - Convenience Methods Tests
    
    func testStaticConvenienceMethods() {
        SuccessFactors.success("Quick Success", weight: 2.0)
        SuccessFactors.failure("Quick Failure", weight: 0.5)
        
        XCTAssertEqual(SuccessFactors.stats.successCount, 1)
        XCTAssertEqual(SuccessFactors.stats.failureCount, 1)
    }
}

// MARK: - Custom Factor Tests

struct TodoFactor: FactorProtocol {
    let type: FactorType
    let weight: Double
    let name: String
    let parameters: [String: Any]?
    let error: Error?
    
    static func createdList(id: String) -> TodoFactor {
        return TodoFactor(
            type: .success,
            weight: 2.0,
            name: "Created Todo List",
            parameters: ["listId": id],
            error: nil
        )
    }
    
    static func completedTodo(id: String) -> TodoFactor {
        return TodoFactor(
            type: .success,
            weight: 1.0,
            name: "Completed Todo",
            parameters: ["todoId": id],
            error: nil
        )
    }
    
    static func networkError(_ error: Error) -> TodoFactor {
        return TodoFactor(
            type: .failure,
            weight: 0.5,
            name: "Network Error",
            parameters: nil,
            error: error
        )
    }
}

final class CustomFactorTests: XCTestCase {
    
    var sut: SuccessFactors!
    
    override func setUp() {
        super.setUp()
        sut = SuccessFactors.shared
        sut.configure(with: SuccessFactorsConfiguration(
            enableFileLogging: false,
            minimumFactorsForRate: 1,
            persistFactors: false
        ))
        sut.resetSync()
    }
    
    override func tearDown() {
        sut.resetSync()
        super.tearDown()
    }
    
    func testCustomFactor() {
        sut.add(customFactor: TodoFactor.createdList(id: "list-123"))
        sut.add(customFactor: TodoFactor.completedTodo(id: "todo-456"))
        sut.add(customFactor: TodoFactor.networkError(NSError(domain: "Network", code: -1, userInfo: nil)))
        
        let stats = sut.currentStats
        XCTAssertEqual(stats.successCount, 2)
        XCTAssertEqual(stats.failureCount, 1)
        XCTAssertEqual(stats.totalSuccessWeight, 3.0, accuracy: 0.001)
        XCTAssertEqual(stats.totalFailureWeight, 0.5, accuracy: 0.001)
        
        // Rate = 3.0 / 3.5 = 0.857
        XCTAssertEqual(sut.currentRate, 3.0 / 3.5, accuracy: 0.001)
    }
}

// MARK: - Delegate Tests

final class DelegateTests: XCTestCase {
    
    var sut: SuccessFactors!
    var delegateMock: MockDelegate!
    
    override func setUp() {
        super.setUp()
        sut = SuccessFactors.shared
        sut.configure(with: SuccessFactorsConfiguration(
            enableFileLogging: false,
            rateUpdateThreshold: 0.0,
            minimumFactorsForRate: 1,
            persistFactors: false,
            targetRate: 0.95,
            notifyTargetOnlyOnce: true
        ))
        sut.resetSync()
        delegateMock = MockDelegate()
        sut.delegate = delegateMock
    }
    
    override func tearDown() {
        sut.delegate = nil
        sut.resetSync()
        super.tearDown()
    }
    
    func testDelegateReceivesRateUpdate() {
        let expectation = XCTestExpectation(description: "Delegate called")
        delegateMock.onRateUpdate = { rate, stats in
            XCTAssertEqual(rate, 0.5, accuracy: 0.001)
            XCTAssertEqual(stats.totalCount, 2)
            expectation.fulfill()
        }
        
        sut.addSuccess("Success")
        sut.addFailure("Failure")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDelegateReceivesFactorLog() {
        let expectation = XCTestExpectation(description: "Factor logged")
        delegateMock.onFactorLog = { entry in
            XCTAssertEqual(entry.name, "Test Factor")
            XCTAssertEqual(entry.type, .success)
            expectation.fulfill()
        }
        
        sut.addSuccess("Test Factor")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDelegateReceivesTargetRateReached() {
        let expectation = XCTestExpectation(description: "Target rate reached")
        delegateMock.onTargetReached = { rate, targetRate, stats in
            XCTAssertGreaterThanOrEqual(rate, 0.95)
            XCTAssertEqual(targetRate, 0.95, accuracy: 0.001)
            expectation.fulfill()
        }
        
        // Add 19 successes and 1 failure = 95% rate
        for _ in 0..<19 {
            sut.addSuccess("Success")
        }
        sut.addFailure("Failure")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testTargetRateNotifiedOnlyOnce() {
        var callCount = 0
        delegateMock.onTargetReached = { _, _, _ in
            callCount += 1
        }
        
        // Add enough to reach target
        for _ in 0..<20 {
            sut.addSuccess("Success")
        }
        
        // Wait a bit for async callbacks
        let expectation = XCTestExpectation(description: "Wait for callbacks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(callCount, 1, "Target reached should only be called once")
    }
    
    func testTargetRateNotifiedMultipleTimes() {
        // Reconfigure to notify multiple times
        sut.configure(with: SuccessFactorsConfiguration(
            enableFileLogging: false,
            rateUpdateThreshold: 0.0,
            minimumFactorsForRate: 1, persistFactors: false,
            targetRate: 0.95,
            notifyTargetOnlyOnce: false
        ))
        sut.delegate = delegateMock
        
        var callCount = 0
        delegateMock.onTargetReached = { _, _, _ in
            callCount += 1
        }
        
        // Add enough to reach and stay above target
        for _ in 0..<20 {
            sut.addSuccess("Success")
        }
        
        let expectation = XCTestExpectation(description: "Wait for callbacks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThan(callCount, 1, "Target reached should be called multiple times")
    }
    
    func testResetTargetReachedFlag() {
        var callCount = 0
        delegateMock.onTargetReached = { _, _, _ in
            callCount += 1
        }
        
        // Reach target first time
        for _ in 0..<20 {
            sut.addSuccess("Success")
        }
        
        let expectation1 = XCTestExpectation(description: "First batch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        XCTAssertEqual(callCount, 1)
        
        // Reset the flag
        sut.resetTargetReachedFlag()
        
        // Add more successes
        for _ in 0..<5 {
            sut.addSuccess("Success")
        }
        
        let expectation2 = XCTestExpectation(description: "Second batch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        XCTAssertEqual(callCount, 2, "Should notify again after flag reset")
    }
}

class MockDelegate: SuccessFactorsDelegate {
    var onRateUpdate: ((Double, SuccessFactors.Stats) -> Void)?
    var onFactorLog: ((FactorEntry) -> Void)?
    var onTargetReached: ((Double, Double, SuccessFactors.Stats) -> Void)?
    
    func successFactors(_ successFactors: SuccessFactors, didUpdateRate rate: Double, stats: SuccessFactors.Stats) {
        onRateUpdate?(rate, stats)
    }
    
    func successFactors(_ successFactors: SuccessFactors, didLogFactor entry: FactorEntry) {
        onFactorLog?(entry)
    }
    
    func successFactors(_ successFactors: SuccessFactors, reachedTheTargetRate rate: Double, targetRate: Double, stats: SuccessFactors.Stats) {
        onTargetReached?(rate, targetRate, stats)
    }
}
