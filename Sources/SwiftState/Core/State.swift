import Foundation

/// Represents the read-only global state of the application.
/// It must conform to `Codable` (for serialization and time-travel history comparison)
/// and `Equatable` (to detect changes and trigger rendering optimizations).
public protocol State: Codable, Equatable, Sendable {}
