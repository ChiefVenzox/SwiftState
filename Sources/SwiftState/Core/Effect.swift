import Foundation

/// A unit of asynchronous work that can dispatch actions back into a store.
public struct Effect: Sendable {
    public typealias Dispatch = @MainActor @Sendable (Action) -> Void
    
    private let operation: (@Sendable (@escaping Dispatch) async -> Void)?
    
    /// Creates an effect from an async operation.
    public init(_ operation: @escaping @Sendable (@escaping Dispatch) async -> Void) {
        self.operation = operation
    }
    
    private init(operation: (@Sendable (@escaping Dispatch) async -> Void)?) {
        self.operation = operation
    }
    
    /// An effect that does no work.
    public static var none: Effect {
        Effect(operation: nil)
    }
    
    /// Creates an effect from an async operation.
    public static func run(_ operation: @escaping @Sendable (@escaping Dispatch) async -> Void) -> Effect {
        Effect(operation)
    }
    
    /// Runs multiple effects in order.
    public static func merge(_ effects: Effect...) -> Effect {
        merge(effects)
    }
    
    /// Runs multiple effects in order.
    public static func merge(_ effects: [Effect]) -> Effect {
        let activeEffects = effects.compactMap { $0.operation != nil ? $0 : nil }
        if activeEffects.isEmpty {
            return .none
        }
        if activeEffects.count == 1 {
            return activeEffects[0]
        }
        return Effect { dispatch in
            for effect in activeEffects {
                guard let operation = effect.operation else { continue }
                await operation(dispatch)
            }
        }
    }
    
    @MainActor
    func start(dispatch: @escaping Dispatch) {
        guard let operation = operation else { return }
        
        Task {
            await operation(dispatch)
        }
    }
}
