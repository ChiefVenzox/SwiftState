import SwiftUI

@MainActor
public extension Store {
    /// Creates a SwiftUI binding that reads from state and dispatches an action on write.
    func binding<Value>(
        get: @escaping (S) -> Value,
        action: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { get(self.state) },
            set: { self.dispatch(action($0)) }
        )
    }
    
    /// Creates a SwiftUI binding from a state key path and dispatches an action on write.
    func binding<Value>(
        _ keyPath: KeyPath<S, Value>,
        action: @escaping (Value) -> Action
    ) -> Binding<Value> {
        binding(get: { $0[keyPath: keyPath] }, action: action)
    }
}
