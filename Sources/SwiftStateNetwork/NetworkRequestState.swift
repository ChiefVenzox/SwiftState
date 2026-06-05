import Foundation
import SwiftState

public enum NetworkRequestStatus: String, Codable, Sendable {
    case running
    case succeeded
    case failed
}

public struct NetworkRequestState: State, Identifiable {
    public let id: String
    public let method: HTTPMethod
    public let path: String
    public let status: NetworkRequestStatus
    public let startedAt: Date
    public let finishedAt: Date?
    public let duration: TimeInterval?
    public let errorMessage: String?
    
    public init(
        id: String,
        method: HTTPMethod,
        path: String,
        status: NetworkRequestStatus,
        startedAt: Date,
        finishedAt: Date? = nil,
        duration: TimeInterval? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.method = method
        self.path = path
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.duration = duration
        self.errorMessage = errorMessage
    }
}

public enum NetworkAction: Action {
    case requestStarted(NetworkRequestState)
    case requestSucceeded(id: String, statusCode: Int, duration: TimeInterval)
    case requestFailed(id: String, error: String, duration: TimeInterval)
}

public enum RetryPolicy: Equatable, Sendable {
    case none
    case times(Int)
    
    var maxAttempts: Int {
        switch self {
        case .none:
            return 1
        case .times(let count):
            return max(1, count + 1)
        }
    }
}

