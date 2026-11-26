import Foundation

/// A mock language model client designed for unit testing SwiftState stores, middleware, and effects across all platforms.
public actor MockLanguageModelClient: LanguageModelClientProtocol {
    private var available: Bool
    private var queuedResponses: [LanguageModelResponse] = []
    private var queuedErrors: [Error] = []
    private var queuedStreams: [[String]] = []
    
    public private(set) var recordedPrompts: [String] = []
    public private(set) var recordedInstructions: [String?] = []
    public private(set) var recordedOptions: [LanguageModelGenerationOptions?] = []
    
    public init(isAvailable: Bool = true) {
        self.available = isAvailable
    }
    
    public var isAvailable: Bool {
        get async { available }
    }
    
    public func setAvailable(_ available: Bool) {
        self.available = available
    }
    
    public func enqueueResponse(_ response: LanguageModelResponse) {
        queuedResponses.append(response)
    }
    
    public func enqueueResponse(_ text: String, usage: LanguageModelTokenUsage? = nil) {
        queuedResponses.append(LanguageModelResponse(text: text, usage: usage))
    }
    
    public func enqueueError(_ error: Error) {
        queuedErrors.append(error)
    }
    
    public func enqueueStreamChunks(_ chunks: [String]) {
        queuedStreams.append(chunks)
    }
    
    public func reset() {
        queuedResponses.removeAll()
        queuedErrors.removeAll()
        queuedStreams.removeAll()
        recordedPrompts.removeAll()
        recordedInstructions.removeAll()
        recordedOptions.removeAll()
    }
    
    public func respond(
        to prompt: String,
        instructions: String? = nil,
        options: LanguageModelGenerationOptions? = nil
    ) async throws -> LanguageModelResponse {
        recordedPrompts.append(prompt)
        recordedInstructions.append(instructions)
        recordedOptions.append(options)
        
        guard available else {
            throw LanguageModelError.unavailable("MockLanguageModelClient is set to unavailable.")
        }
        
        if !queuedErrors.isEmpty {
            throw queuedErrors.removeFirst()
        }
        
        if !queuedResponses.isEmpty {
            return queuedResponses.removeFirst()
        }
        
        // Default simulated response if none specifically queued
        return LanguageModelResponse(
            text: "Mock response to: \(prompt)",
            usage: LanguageModelTokenUsage(inputTokens: 10, outputTokens: 20, totalTokens: 30)
        )
    }
    
    private func nextStreamChunks(
        prompt: String,
        instructions: String?,
        options: LanguageModelGenerationOptions?
    ) throws -> [String] {
        recordedPrompts.append(prompt)
        recordedInstructions.append(instructions)
        recordedOptions.append(options)
        
        guard available else {
            throw LanguageModelError.unavailable("MockLanguageModelClient is set to unavailable.")
        }
        
        if !queuedErrors.isEmpty {
            throw queuedErrors.removeFirst()
        }
        
        if !queuedStreams.isEmpty {
            return queuedStreams.removeFirst()
        }
        
        return ["Mock ", "streaming ", "response ", "for: ", prompt]
    }
    
    public nonisolated func stream(
        to prompt: String,
        instructions: String? = nil,
        options: LanguageModelGenerationOptions? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let chunks = try await self.nextStreamChunks(
                        prompt: prompt,
                        instructions: instructions,
                        options: options
                    )
                    for chunk in chunks {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
