import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class URLSessionHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let defaultHeaders: [String: String]
    
    public init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        defaultHeaders: [String: String] = ["Accept": "application/json"]
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.defaultHeaders = defaultHeaders
    }
    
    public func request<T: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        body: Data?,
        timeout: TimeInterval?
    ) async throws -> HTTPResponse<T> {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw HTTPClientError.invalidURL(path)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        if let timeout {
            request.timeoutInterval = timeout
        }
        
        defaultHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPClientError.httpStatus(httpResponse.statusCode)
        }
        
        do {
            let value = try decoder.decode(T.self, from: data)
            return HTTPResponse(value: value, statusCode: httpResponse.statusCode, data: data)
        } catch {
            throw HTTPClientError.decodingFailed(error.localizedDescription)
        }
    }
}

