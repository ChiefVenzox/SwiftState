import Foundation

public struct MockHTTPRequest: Equatable, Sendable {
    public let path: String
    public let method: HTTPMethod
    public let body: Data?
    public let timeout: TimeInterval?
    
    public init(path: String, method: HTTPMethod, body: Data?, timeout: TimeInterval?) {
        self.path = path
        self.method = method
        self.body = body
        self.timeout = timeout
    }
}

private enum MockHTTPClientResult {
    case success(statusCode: Int, data: Data)
    case failure(Error)
}

public actor MockHTTPClient: HTTPClientProtocol {
    private var queuedResults: [MockHTTPClientResult] = []
    private var recordedRequests: [MockHTTPRequest] = []
    private let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }
    
    public var requests: [MockHTTPRequest] {
        recordedRequests
    }
    
    public func enqueue<T: Encodable>(_ value: T, statusCode: Int = 200) throws {
        let data = try JSONEncoder().encode(value)
        enqueueData(data, statusCode: statusCode)
    }
    
    public func enqueueData(_ data: Data, statusCode: Int = 200) {
        queuedResults.append(.success(statusCode: statusCode, data: data))
    }
    
    public func enqueueFailure(_ error: Error) {
        queuedResults.append(.failure(error))
    }
    
    public func request<T: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        body: Data?,
        timeout: TimeInterval?
    ) async throws -> HTTPResponse<T> {
        let result: MockHTTPClientResult
        
        recordedRequests.append(MockHTTPRequest(path: path, method: method, body: body, timeout: timeout))
        if queuedResults.isEmpty {
            throw HTTPClientError.noMockResponse
        } else {
            result = queuedResults.removeFirst()
        }
        
        switch result {
        case .success(let statusCode, let data):
            guard (200..<300).contains(statusCode) else {
                throw HTTPClientError.httpStatus(statusCode)
            }
            
            do {
                let value = try decoder.decode(T.self, from: data)
                return HTTPResponse(value: value, statusCode: statusCode, data: data)
            } catch {
                throw HTTPClientError.decodingFailed(error.localizedDescription)
            }
        case .failure(let error):
            throw error
        }
    }
}
