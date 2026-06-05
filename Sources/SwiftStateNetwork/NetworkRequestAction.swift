import Foundation
import SwiftState

public protocol AnyNetworkRequestAction: Action {
    var requestID: String { get }
    var method: HTTPMethod { get }
    var path: String { get }
    var retryPolicy: RetryPolicy { get }
    var timeout: TimeInterval? { get }
    
    @MainActor
    func perform(using client: HTTPClientProtocol) async -> NetworkRequestResult
}

public struct NetworkRequestResult {
    public let statusCode: Int?
    public let errorMessage: String?
    public let followUpAction: Action?
    
    public static func success(statusCode: Int, followUpAction: Action?) -> NetworkRequestResult {
        NetworkRequestResult(statusCode: statusCode, errorMessage: nil, followUpAction: followUpAction)
    }
    
    public static func failure(errorMessage: String, followUpAction: Action?) -> NetworkRequestResult {
        NetworkRequestResult(statusCode: nil, errorMessage: errorMessage, followUpAction: followUpAction)
    }
    
    public var isSuccess: Bool {
        statusCode != nil
    }
}

public struct NetworkRequestAction<Response: Decodable & Sendable>: AnyNetworkRequestAction {
    public let requestID: String
    public let method: HTTPMethod
    public let path: String
    public let retryPolicy: RetryPolicy
    public let timeout: TimeInterval?
    
    private let body: Data?
    private let onSuccess: @MainActor @Sendable (Response) -> Action?
    private let onFailure: @MainActor @Sendable (String) -> Action?
    
    public init(
        id: String = UUID().uuidString,
        method: HTTPMethod,
        path: String,
        body: Data? = nil,
        retryPolicy: RetryPolicy = .none,
        timeout: TimeInterval? = nil,
        onSuccess: @escaping @MainActor @Sendable (Response) -> Action?,
        onFailure: @escaping @MainActor @Sendable (String) -> Action? = { _ in nil }
    ) {
        self.requestID = id
        self.method = method
        self.path = path
        self.body = body
        self.retryPolicy = retryPolicy
        self.timeout = timeout
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    public static func get(
        id: String = UUID().uuidString,
        _ path: String,
        retryPolicy: RetryPolicy = .none,
        timeout: TimeInterval? = nil,
        onSuccess: @escaping @MainActor @Sendable (Response) -> Action?,
        onFailure: @escaping @MainActor @Sendable (String) -> Action? = { _ in nil }
    ) -> NetworkRequestAction<Response> {
        NetworkRequestAction(
            id: id,
            method: .get,
            path: path,
            retryPolicy: retryPolicy,
            timeout: timeout,
            onSuccess: onSuccess,
            onFailure: onFailure
        )
    }
    
    public static func post<Body: Encodable>(
        id: String = UUID().uuidString,
        _ path: String,
        body: Body,
        retryPolicy: RetryPolicy = .none,
        timeout: TimeInterval? = nil,
        onSuccess: @escaping @MainActor @Sendable (Response) -> Action?,
        onFailure: @escaping @MainActor @Sendable (String) -> Action? = { _ in nil }
    ) throws -> NetworkRequestAction<Response> {
        let encodedBody: Data
        do {
            encodedBody = try JSONEncoder().encode(body)
        } catch {
            throw HTTPClientError.encodingFailed(error.localizedDescription)
        }
        
        return NetworkRequestAction(
            id: id,
            method: .post,
            path: path,
            body: encodedBody,
            retryPolicy: retryPolicy,
            timeout: timeout,
            onSuccess: onSuccess,
            onFailure: onFailure
        )
    }
    
    @MainActor
    public func perform(using client: HTTPClientProtocol) async -> NetworkRequestResult {
        do {
            let response: HTTPResponse<Response> = try await client.request(
                path,
                method: method,
                body: body,
                timeout: timeout
            )
            return .success(
                statusCode: response.statusCode,
                followUpAction: onSuccess(response.value)
            )
        } catch {
            return .failure(
                errorMessage: error.localizedDescription,
                followUpAction: onFailure(error.localizedDescription)
            )
        }
    }
}

