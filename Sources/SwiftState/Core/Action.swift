import Foundation

/// Represents an intent to modify the state of the application.
/// All actions dispatched to the store must conform to this protocol.
public protocol Action: Sendable {}
