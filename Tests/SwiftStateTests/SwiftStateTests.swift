import XCTest
@testable import SwiftState

// MARK: - Mock State & Actions

struct TestState: State {
    var counter: Int = 0
    var text: String = ""
}

enum TestAction: Action {
    case increment
    case decrement
    case updateText(String)
}

// MARK: - Reducer

let testReducer: Reducer<TestState> = { state, action in
    guard let action = action as? TestAction else { return }
    switch action {
    case .increment:
        state.counter += 1
    case .decrement:
        state.counter -= 1
    case .updateText(let newText):
        state.text = newText
    }
}

// MARK: - SwiftStateTests

@MainActor
final class SwiftStateTests: XCTestCase {
    
    func testStoreInitialState() {
        let store = Store(initialState: TestState(counter: 5, text: "Initial"), reducer: testReducer)
        XCTAssertEqual(store.state.counter, 5)
        XCTAssertEqual(store.state.text, "Initial")
    }
    
    func testStoreActionDispatch() {
        let store = Store(initialState: TestState(), reducer: testReducer)
        
        store.dispatch(TestAction.increment)
        XCTAssertEqual(store.state.counter, 1)
        
        store.dispatch(TestAction.updateText("Updated"))
        XCTAssertEqual(store.state.text, "Updated")
        
        store.dispatch(TestAction.decrement)
        XCTAssertEqual(store.state.counter, 0)
    }
    
    func testMiddlewareChaining() {
        var actionLogged = false
        
        let customMiddleware: Middleware<TestState> = { action, getState, dispatch, next in
            actionLogged = true
            next(action)
        }
        
        let store = Store(
            initialState: TestState(),
            reducer: testReducer,
            middlewares: [customMiddleware]
        )
        
        store.dispatch(TestAction.increment)
        
        XCTAssertTrue(actionLogged)
        XCTAssertEqual(store.state.counter, 1)
    }
    
    func testTimeTravelStoreRecording() {
        let store = TimeTravelStore(initialState: TestState(), reducer: testReducer)
        
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.actionHistory.count, 0)
        XCTAssertEqual(store.currentHistoryIndex, 0)
        
        store.dispatch(TestAction.increment) // History index 1
        XCTAssertEqual(store.history.count, 2)
        XCTAssertEqual(store.actionHistory.count, 1)
        XCTAssertEqual(store.currentHistoryIndex, 1)
        XCTAssertEqual(store.state.counter, 1)
    }
    
    func testTimeTravelUndoRedo() {
        let store = TimeTravelStore(initialState: TestState(counter: 0), reducer: testReducer)
        
        store.dispatch(TestAction.increment) // state = 1, index = 1
        store.dispatch(TestAction.increment) // state = 2, index = 2
        
        XCTAssertEqual(store.state.counter, 2)
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
        
        store.undo() // state = 1, index = 1
        XCTAssertEqual(store.state.counter, 1)
        XCTAssertTrue(store.canUndo)
        XCTAssertTrue(store.canRedo)
        
        store.undo() // state = 0, index = 0
        XCTAssertEqual(store.state.counter, 0)
        XCTAssertFalse(store.canUndo)
        XCTAssertTrue(store.canRedo)
        
        store.redo() // state = 1, index = 1
        XCTAssertEqual(store.state.counter, 1)
        
        store.redo() // state = 2, index = 2
        XCTAssertEqual(store.state.counter, 2)
    }
    
    func testTimeTravelJump() {
        let store = TimeTravelStore(initialState: TestState(counter: 0), reducer: testReducer)
        
        store.dispatch(TestAction.increment) // state = 1, index = 1
        store.dispatch(TestAction.increment) // state = 2, index = 2
        store.dispatch(TestAction.decrement) // state = 1, index = 3
        
        XCTAssertEqual(store.state.counter, 1)
        
        store.jump(to: 0) // initial state, count = 0
        XCTAssertEqual(store.state.counter, 0)
        XCTAssertEqual(store.currentHistoryIndex, 0)
        
        store.jump(to: 2) // index 2, count = 2
        XCTAssertEqual(store.state.counter, 2)
        XCTAssertEqual(store.currentHistoryIndex, 2)
    }
    
    func testTimeTravelHistoryLimit() {
        let store = TimeTravelStore(initialState: TestState(), reducer: testReducer, maxHistoryLimit: 3)
        
        // index 0: initial
        store.dispatch(TestAction.increment) // index 1
        store.dispatch(TestAction.increment) // index 2
        store.dispatch(TestAction.increment) // index 3 (total size becomes 4, which exceeds maxLimit + 1 for initial state check, let's see how truncation works)
        
        // Max limit is 3. The history array holds [initialState, state1, state2, state3].
        // If limit is 3, total states kept should be capped.
        // In our implementation: history.count > maxHistoryLimit (3) -> removes first
        // So after 3 dispatches, history count will be capped at 3.
        XCTAssertLessThanOrEqual(store.history.count, 3)
    }
    
    func testTimeTravelHistoryBranching() {
        let store = TimeTravelStore(initialState: TestState(counter: 0), reducer: testReducer)
        
        store.dispatch(TestAction.increment) // state = 1, index = 1
        store.dispatch(TestAction.increment) // state = 2, index = 2
        
        store.undo() // state = 1, index = 1
        
        // Dispatching a new action should wipe out the future state (index 2) and append the new state at index 2
        store.dispatch(TestAction.updateText("Branched")) // state = 1 (counter), text = "Branched", index = 2
        
        XCTAssertEqual(store.history.count, 3)
        XCTAssertEqual(store.currentHistoryIndex, 2)
        XCTAssertEqual(store.state.counter, 1)
        XCTAssertEqual(store.state.text, "Branched")
        XCTAssertFalse(store.canRedo) // Can't redo because we started a new branch/timeline
    }
}
