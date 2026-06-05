import Foundation

public enum HTTPMethod: String, Codable, Sendable {
    case get = "GET"
    case post = "POST"
}

public struct HTTPResponse<Value: Decodable>: Sendable where Value: Sendable {
    public let value: Value
    public let statusCode: Int
    public let data: Data
    
    public init(value: Value, statusCode: Int, data: Data) {
        self.value = value
        self.statusCode = statusCode
        self.data = data
    }
}

public enum HTTPClientError: Error, Equatable, Sendable {
    case invalidURL(String)
    case invalidResponse
    case httpStatus(Int)
    case encodingFailed(String)
    case decodingFailed(String)
    case noMockResponse
}

extension HTTPClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "Invalid URL for path: \(path)"
        case .invalidResponse:
            return "Invalid HTTP response."
        case .httpStatus(let statusCode):
            return "HTTP request failed with status code \(statusCode)."
        case .encodingFailed(let message):
            return "Request body encoding failed: \(message)"
        case .decodingFailed(let message):
            return "Response decoding failed: \(message)"
        case .noMockResponse:
            return "MockHTTPClient has no queued response."
        }
    }
}

