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
