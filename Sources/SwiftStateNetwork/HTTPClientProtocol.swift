import Foundation

public protocol HTTPClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        body: Data?,
        timeout: TimeInterval?
    ) async throws -> HTTPResponse<T>
}

public extension HTTPClientProtocol {
    func get<T: Decodable & Sendable>(_ path: String) async throws -> T {
        try await request(path, method: .get, body: nil, timeout: nil).value
    }
    
    func post<T: Decodable & Sendable, Body: Encodable>(
        _ path: String,
        body: Body
    ) async throws -> T {
        let encodedBody: Data
        do {
            encodedBody = try JSONEncoder().encode(body)
        } catch {
            throw HTTPClientError.encodingFailed(error.localizedDescription)
        }
        
        return try await request(path, method: .post, body: encodedBody, timeout: nil).value
    }
}

