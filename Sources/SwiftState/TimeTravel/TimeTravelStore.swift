import Foundation
import Combine

/// A specialized `Store` that records state transitions and allows developers
/// to traverse backward and forward in time.
@MainActor
public final class TimeTravelStore<S: State>: Store<S> {
    
    /// The recorded state history.
    @Published public private(set) var history: [S] = []
    
    /// The recorded actions that caused the state changes.
    /// Note: `history[0]` represents the initial state, which has no corresponding action.
    /// Therefore, `actionHistory[i]` is the action that transitioned the state from `history[i]` to `history[i+1]`.
    @Published public private(set) var actionHistory: [Action] = []
    
    /// The index of the active state in the history array.
    @Published public private(set) var currentHistoryIndex: Int = 0
    
    private let maxHistoryLimit: Int
    private var isTimeTraveling = false
    
    /// Initializes a new `TimeTravelStore`.
    /// - Parameters:
    ///   - initialState: The initial state of the store.
    ///   - reducer: The reducer function.
    ///   - middlewares: Any custom middlewares to run before the reducer.
    ///   - maxHistoryLimit: The maximum number of state transitions to keep in memory. Default is 100.
    public init(
        initialState: S,
        reducer: @escaping Reducer<S>,
        middlewares: [Middleware<S>] = [],
        maxHistoryLimit: Int = 100
    ) {
        self.maxHistoryLimit = maxHistoryLimit
        self.history = [initialState]
        self.actionHistory = []
        self.currentHistoryIndex = 0
        
        super.init(initialState: initialState, reducer: reducer, middlewares: middlewares)
    }
    
    /// Overrides dispatch to capture state transitions after actions are processed.
    public override func dispatch(_ action: Action) {
        super.dispatch(action)
        
        // Do not record transitions triggered by time travel scrubbing.
        if isTimeTraveling { return }
        
        recordNewState(self.state, action: action)
    }
    
    /// Records a new state change in the history.
    private func recordNewState(_ newState: S, action: Action) {
        // If we are currently in the middle of history (due to an undo/jump)
        // and we dispatch a new action, discard all history after the current index.
        if currentHistoryIndex < history.count - 1 {
            history.removeSubrange((currentHistoryIndex + 1)...)
            actionHistory.removeSubrange(currentHistoryIndex...)
        }
        
        history.append(newState)
        actionHistory.append(action)
        
        // Truncate oldest items if history limit is exceeded
        if history.count > maxHistoryLimit {
            history.removeFirst()
            actionHistory.removeFirst()
        }
        
        currentHistoryIndex = history.count - 1
    }
    
    /// Jumps to a specific index in the state history.
    /// - Parameter index: The target index in the history array.
    public func jump(to index: Int) {
        guard index >= 0 && index < history.count else { return }
        
        isTimeTraveling = true
        self.state = history[index]
        currentHistoryIndex = index
        isTimeTraveling = false
    }
    
    /// Steps backward one state transition in history.
    public func undo() {
        guard canUndo else { return }
        jump(to: currentHistoryIndex - 1)
    }
    
    /// Steps forward one state transition in history.
    public func redo() {
        guard canRedo else { return }
        jump(to: currentHistoryIndex + 1)
    }
    
    /// True if we can go backward in history.
    public var canUndo: Bool {
        currentHistoryIndex > 0
    }
    
    /// True if we can go forward in history.
    public var canRedo: Bool {
        currentHistoryIndex < history.count - 1
    }
}
