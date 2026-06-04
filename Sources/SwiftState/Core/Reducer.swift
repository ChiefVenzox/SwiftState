import Foundation

/// A pure function that takes the current state (as `inout`) and an action,
/// and updates the state directly.
///
/// Example:
/// ```swift
/// struct CounterState: State {
///     var count: Int = 0
/// }
///
/// enum CounterAction: Action {
///     case increment
///     case decrement
/// }
///
/// let counterReducer: Reducer<CounterState> = { state, action in
///     guard let action = action as? CounterAction else { return }
///     switch action {
///     case .increment:
///         state.count += 1
///     case .decrement:
///         state.count -= 1
///     }
/// }
/// ```
public typealias Reducer<S: State> = (inout S, Action) -> Void

/// A reducer that can mutate state and return asynchronous work.
public typealias EffectReducer<S: State> = (inout S, Action) -> Effect

/// Combines multiple reducers into a single reducer that runs each reducer in order.
public func combineReducers<S: State>(_ reducers: Reducer<S>...) -> Reducer<S> {
    combineReducers(reducers)
}

/// Combines an array of reducers into a single reducer that runs each reducer in order.
public func combineReducers<S: State>(_ reducers: [Reducer<S>]) -> Reducer<S> {
    return { state, action in
        reducers.forEach { reducer in
            reducer(&state, action)
        }
    }
}

/// Combines multiple effect reducers into a single effect reducer.
public func combineEffectReducers<S: State>(_ reducers: EffectReducer<S>...) -> EffectReducer<S> {
    combineEffectReducers(reducers)
}

/// Combines an array of effect reducers into a single effect reducer.
public func combineEffectReducers<S: State>(_ reducers: [EffectReducer<S>]) -> EffectReducer<S> {
    return { state, action in
        Effect.merge(
            reducers.map { reducer in
                reducer(&state, action)
            }
        )
    }
}

/// Lifts a reducer that works on local state so it can update a larger parent state.
public func pullback<GlobalState: State, LocalState: State>(
    _ reducer: @escaping Reducer<LocalState>,
    state keyPath: WritableKeyPath<GlobalState, LocalState>
) -> Reducer<GlobalState> {
    return { globalState, action in
        reducer(&globalState[keyPath: keyPath], action)
    }
}

/// Lifts an effect reducer that works on local state so it can update a larger parent state.
public func pullback<GlobalState: State, LocalState: State>(
    _ reducer: @escaping EffectReducer<LocalState>,
    state keyPath: WritableKeyPath<GlobalState, LocalState>
) -> EffectReducer<GlobalState> {
    return { globalState, action in
        reducer(&globalState[keyPath: keyPath], action)
    }
}
