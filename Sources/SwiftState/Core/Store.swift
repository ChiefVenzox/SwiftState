import Foundation
import Combine

/// A definition of Middleware typealias.
/// Receives the dispatched action, a getter for the current state, a dispatch function for new actions,
/// and a next dispatch function to forward the action.
public typealias Middleware<S: State> = @MainActor (
    _ action: Action,
    _ getState: @escaping @MainActor () -> S,
    _ dispatch: @escaping @MainActor (Action) -> Void,
    _ next: @escaping @MainActor (Action) -> Void
) -> Void

/// The centralized Store that holds the application State.
/// State mutations can only happen by dispatching Actions.
/// The Store uses Reducers to calculate new States and invokes Middlewares for side effects.
@MainActor
open class Store<S: State>: ObservableObject {
    
    /// The current state of the application. Read-only from outside.
    @Published public internal(set) var state: S
    
    private let middlewares: [Middleware<S>]
    private let reducer: Reducer<S>
    
    /// Initializes a new Store with an initial state, a reducer, and optional middlewares.
    /// - Parameters:
    ///   - initialState: The starting state of the application.
    ///   - reducer: The reducer function to apply action changes.
    ///   - middlewares: An array of middlewares that run sequentially on dispatched actions.
    public init(
        initialState: S,
        reducer: @escaping Reducer<S>,
        middlewares: [Middleware<S>] = []
    ) {
        self.state = initialState
        self.reducer = reducer
        self.middlewares = middlewares
    }
    
    /// Dispatches an action to the store, triggering the middleware chain and reducer.
    /// Must be called from the main thread/actor.
    /// - Parameter action: The action to dispatch.
    public func dispatch(_ action: Action) {
        let chain = DispatchChain(store: self, middlewares: middlewares, reducer: reducer)
        chain.execute(action: action)
    }
}

/// Helper class to execute actions through the middleware chain in a linear manner.
/// Avoids recursive escaping closure generation, resolving compiler SIL crashes.
@MainActor
private final class DispatchChain<S: State> {
    private let middlewares: [Middleware<S>]
    private let reducer: Reducer<S>
    private weak var store: Store<S>?
    private var index = 0
    
    init(store: Store<S>, middlewares: [Middleware<S>], reducer: @escaping Reducer<S>) {
        self.store = store
        self.middlewares = middlewares
        self.reducer = reducer
    }
    
    func execute(action: Action) {
        index = 0
        next(action: action)
    }
    
    private func next(action: Action) {
        guard let store = store else { return }
        
        if index < middlewares.count {
            let middleware = middlewares[index]
            index += 1
            
            let getState: @MainActor () -> S = {
                store.state
            }
            
            let dispatch: @MainActor (Action) -> Void = { action in
                store.dispatch(action)
            }
            
            let nextDispatch: @MainActor (Action) -> Void = { [self] action in
                next(action: action)
            }
            
            middleware(action, getState, dispatch, nextDispatch)
        } else {
            // Apply reducer
            var currentState = store.state
            reducer(&currentState, action)
            if currentState != store.state {
                store.state = currentState
            }
        }
    }
}
