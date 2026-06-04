import Foundation

/// A middleware that logs all dispatched actions and the resulting state transitions.
/// It outputs beautifully formatted diagnostic information to the console.
public func createLoggerMiddleware<S: State>() -> Middleware<S> {
    return { @MainActor action, getState, dispatch, next in
        #if DEBUG
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let actionName = String(describing: action)
        let prevState = getState()
        
        print("┌── 🚀 [SwiftState] Action: \(actionName) @ \(timestamp)")
        print("├── 📁 Prev State: \(prevState)")
        #endif
        
        // Call the next middleware or the core reducer
        next(action)
        
        #if DEBUG
        let nextState = getState()
        print("├── 🎯 Next State: \(nextState)")
        print("└── ──────────────────────────────────────────────────")
        #endif
    }
}
