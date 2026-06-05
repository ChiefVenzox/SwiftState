import XCTest
import SwiftState
@testable import SwiftStateNetwork

private struct TestDTO: Codable, Equatable, Sendable {
    var id: Int
    var name: String
}

private struct TestBody: Codable, Equatable, Sendable {
    var name: String
}

private struct NetworkTestState: State {
    var requests: [String: NetworkRequestState] = [:]
    var loadedDTO: TestDTO?
    var errorMessage: String?
}

private enum NetworkTestAction: Action {
    case loadDTO(retryPolicy: RetryPolicy = .none)
    case dtoLoaded(TestDTO)
    case dtoFailed(String)
}

@MainActor
final class SwiftStateNetworkTests: XCTestCase {
    func testSuccessfulGET() async throws {
        let client = MockHTTPClient()
        try await client.enqueue(TestDTO(id: 1, name: "SwiftState"))
        
        let value: TestDTO = try await client.get("/profile")
        
        XCTAssertEqual(value, TestDTO(id: 1, name: "SwiftState"))
        let requests = await client.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].method, .get)
        XCTAssertEqual(requests[0].path, "/profile")
    }
    
    func testFailedRequest() async throws {
        let client = MockHTTPClient()
        await client.enqueueFailure(HTTPClientError.httpStatus(500))
        
        do {
            let _: TestDTO = try await client.get("/broken")
            XCTFail("Expected request to fail.")
        } catch let error as HTTPClientError {
            XCTAssertEqual(error, .httpStatus(500))
        }
        
        let requests = await client.requests
        XCTAssertEqual(requests.count, 1)
    }
    
    func testRetryBehavior() async throws {
        let client = MockHTTPClient()
        await client.enqueueFailure(HTTPClientError.httpStatus(503))
        try await client.enqueue(TestDTO(id: 2, name: "Retried"))
        
        let store = Store(
            initialState: NetworkTestState(),
            reducer: networkTestReducer,
            middlewares: [createNetworkMiddleware(client: client)]
        )
        
        store.dispatch(NetworkRequestAction<TestDTO>.get(
            id: "retry-request",
            "/retry",
            retryPolicy: .times(1),
            timeout: 5,
            onSuccess: { NetworkTestAction.dtoLoaded($0) },
            onFailure: { NetworkTestAction.dtoFailed($0) }
        ))
        
        try await waitUntil {
            store.state.loadedDTO != nil
        }
        
        let requests = await client.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(store.state.loadedDTO, TestDTO(id: 2, name: "Retried"))
        XCTAssertEqual(store.state.requests["retry-request"]?.status, .succeeded)
        XCTAssertEqual(store.state.requests["retry-request"]?.duration != nil, true)
    }
    
    func testMockResponseDecoding() async throws {
        let client = MockHTTPClient()
        try await client.enqueue(TestDTO(id: 3, name: "Decoded"))
        
        let value: TestDTO = try await client.post("/decode", body: TestBody(name: "Request"))
        
        XCTAssertEqual(value, TestDTO(id: 3, name: "Decoded"))
        let requests = await client.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].method, .post)
        XCTAssertNotNil(requests[0].body)
    }
    
    private var networkTestReducer: Reducer<NetworkTestState> {
        { state, action in
            switch action {
            case let action as NetworkAction:
                switch action {
                case .requestStarted(let request):
                    state.requests[request.id] = request
                case .requestSucceeded(let id, _, let duration):
                    guard let current = state.requests[id] else { return }
                    state.requests[id] = NetworkRequestState(
                        id: current.id,
                        method: current.method,
                        path: current.path,
                        status: .succeeded,
                        startedAt: current.startedAt,
                        finishedAt: current.startedAt.addingTimeInterval(duration),
                        duration: duration
                    )
                case .requestFailed(let id, let error, let duration):
                    guard let current = state.requests[id] else { return }
                    state.requests[id] = NetworkRequestState(
                        id: current.id,
                        method: current.method,
                        path: current.path,
                        status: .failed,
                        startedAt: current.startedAt,
                        finishedAt: current.startedAt.addingTimeInterval(duration),
                        duration: duration,
                        errorMessage: error
                    )
                }
            case let action as NetworkTestAction:
                switch action {
                case .loadDTO:
                    break
                case .dtoLoaded(let dto):
                    state.loadedDTO = dto
                    state.errorMessage = nil
                case .dtoFailed(let message):
                    state.errorMessage = message
                }
            default:
                break
            }
        }
    }
    
    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for condition.")
    }
}
