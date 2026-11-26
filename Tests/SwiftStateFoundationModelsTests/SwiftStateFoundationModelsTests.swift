import XCTest
import SwiftState
@testable import SwiftStateFoundationModels

private struct AITestState: State {
    var requests: [String: LanguageModelRequestState] = [:]
    var generatedText: String?
    var streamedText: String = ""
    var errorMessage: String?
}

private enum AITestAction: Action {
    case promptReceived(String)
    case chunkArrived(String)
    case generationFailed(String)
}

@MainActor
final class SwiftStateFoundationModelsTests: XCTestCase {
    
    func testMockClientAvailabilityAndResponse() async throws {
        let client = MockLanguageModelClient(isAvailable: true)
        let isAvail = await client.isAvailable
        XCTAssertTrue(isAvail)
        
        await client.enqueueResponse(
            "Apple Intelligence summary",
            usage: LanguageModelTokenUsage(inputTokens: 5, outputTokens: 10, totalTokens: 15)
        )
        
        let response = try await client.respond(to: "Summarize WWDC 2026", instructions: nil, options: nil)
        XCTAssertEqual(response.text, "Apple Intelligence summary")
        XCTAssertEqual(response.usage?.totalTokens, 15)
        
        let recorded = await client.recordedPrompts
        XCTAssertEqual(recorded, ["Summarize WWDC 2026"])
    }
    
    func testMockClientErrorHandling() async throws {
        let client = MockLanguageModelClient()
        await client.enqueueError(LanguageModelError.contextSizeExceeded("Prompt exceeded 4096 tokens."))
        
        do {
            _ = try await client.respond(to: "Too long prompt", instructions: nil, options: nil)
            XCTFail("Expected error to be thrown.")
        } catch let error as LanguageModelError {
            XCTAssertEqual(error, .contextSizeExceeded("Prompt exceeded 4096 tokens."))
        }
    }
    
    func testMockClientStreaming() async throws {
        let client = MockLanguageModelClient()
        await client.enqueueStreamChunks(["Foundation", " ", "Models", " ", "Rock!"])
        
        var received: [String] = []
        for try await chunk in client.stream(to: "Stream this") {
            received.append(chunk)
        }
        
        XCTAssertEqual(received, ["Foundation", " ", "Models", " ", "Rock!"])
        XCTAssertEqual(received.joined(), "Foundation Models Rock!")
    }
    
    func testPromptActionWithMiddleware() async throws {
        let client = MockLanguageModelClient()
        await client.enqueueResponse(
            "SwiftState + Apple Foundation Models",
            usage: LanguageModelTokenUsage(inputTokens: 12, outputTokens: 8, totalTokens: 20)
        )
        
        let store = Store<AITestState>(
            initialState: AITestState(),
            reducer: makeTestReducer(),
            middlewares: [createLanguageModelMiddleware(client: client)]
        )
        
        let action = LanguageModelPromptAction(
            id: "req-1",
            prompt: "Describe the integration",
            instructions: "Be brief",
            onSuccess: { response in
                AITestAction.promptReceived(response.text)
            },
            onFailure: { error in
                AITestAction.generationFailed(error)
            }
        )
        
        store.dispatch(action)
        
        try await waitUntil {
            store.state.requests["req-1"]?.status == .succeeded &&
            store.state.generatedText == "SwiftState + Apple Foundation Models"
        }
        
        let req = try XCTUnwrap(store.state.requests["req-1"])
        XCTAssertEqual(req.prompt, "Describe the integration")
        XCTAssertEqual(req.instructions, "Be brief")
        XCTAssertEqual(req.status, .succeeded)
        XCTAssertEqual(req.response, "SwiftState + Apple Foundation Models")
        XCTAssertEqual(req.usage?.totalTokens, 20)
        XCTAssertNotNil(req.duration)
    }
    
    func testStreamingActionWithMiddleware() async throws {
        let client = MockLanguageModelClient()
        await client.enqueueStreamChunks(["On-device ", "Apple ", "Intelligence"])
        
        let store = Store<AITestState>(
            initialState: AITestState(),
            reducer: makeTestReducer(),
            middlewares: [createLanguageModelMiddleware(client: client)]
        )
        
        let action = LanguageModelStreamAction(
            id: "stream-1",
            prompt: "Stream output",
            onChunk: { chunk in
                AITestAction.chunkArrived(chunk)
            },
            onSuccess: { fullText in
                AITestAction.promptReceived(fullText)
            },
            onFailure: { error in
                AITestAction.generationFailed(error)
            }
        )
        
        store.dispatch(action)
        
        try await waitUntil {
            store.state.requests["stream-1"]?.status == .succeeded &&
            store.state.streamedText == "On-device Apple Intelligence"
        }
        
        let req = try XCTUnwrap(store.state.requests["stream-1"])
        XCTAssertEqual(req.status, .succeeded)
        XCTAssertEqual(req.streamedChunks, ["On-device ", "Apple ", "Intelligence"])
        XCTAssertEqual(req.response, "On-device Apple Intelligence")
        XCTAssertEqual(store.state.generatedText, "On-device Apple Intelligence")
    }
    
    func testPromptActionFailureHandling() async throws {
        let client = MockLanguageModelClient()
        await client.enqueueError(LanguageModelError.generationFailed("Model busy."))
        
        let store = Store<AITestState>(
            initialState: AITestState(),
            reducer: makeTestReducer(),
            middlewares: [createLanguageModelMiddleware(client: client)]
        )
        
        let action = LanguageModelPromptAction(
            id: "fail-1",
            prompt: "Fail this prompt",
            onSuccess: { response in
                AITestAction.promptReceived(response.text)
            },
            onFailure: { error in
                AITestAction.generationFailed(error)
            }
        )
        
        store.dispatch(action)
        
        try await waitUntil {
            store.state.requests["fail-1"]?.status == .failed &&
            store.state.errorMessage != nil
        }
        
        let req = try XCTUnwrap(store.state.requests["fail-1"])
        XCTAssertEqual(req.status, .failed)
        XCTAssertNotNil(req.errorMessage)
        XCTAssertTrue(store.state.errorMessage?.contains("Model busy.") == true)
    }
    
    func testSystemLanguageModelClientInitialization() async throws {
        let client = SystemLanguageModelClient()
        #if canImport(FoundationModels)
        _ = await client.isAvailable
        #else
        let available = await client.isAvailable
        XCTAssertFalse(available)
        
        do {
            _ = try await client.respond(to: "Test")
            XCTFail("Expected unsupportedPlatform error on non-Apple platform.")
        } catch let error as LanguageModelError {
            if case .unsupportedPlatform = error {
                // Expected on Linux / non-Apple platform
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
        #endif
    }
    
    private func makeTestReducer() -> Reducer<AITestState> {
        return { state, action in
            languageModelReducer(state: &state.requests, action: action)
            
            if let aiAction = action as? AITestAction {
                switch aiAction {
                case .promptReceived(let text):
                    state.generatedText = text
                case .chunkArrived(let chunk):
                    state.streamedText.append(chunk)
                case .generationFailed(let error):
                    state.errorMessage = error
                }
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
