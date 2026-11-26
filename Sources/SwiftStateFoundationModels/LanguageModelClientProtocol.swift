import Foundation

/// A client interface for interacting with Apple Foundation Models or test doubles.
public protocol LanguageModelClientProtocol: Sendable {
    /// Indicates whether the language model client is ready and available on the current device.
    var isAvailable: Bool { get async }
    
    /// Generates a response for a prompt, optional system instructions, and generation options.
    func respond(
        to prompt: String,
        instructions: String?,
        options: LanguageModelGenerationOptions?
    ) async throws -> LanguageModelResponse
    
    /// Generates an asynchronous throwing stream of incremental text chunks.
    func stream(
        to prompt: String,
        instructions: String?,
        options: LanguageModelGenerationOptions?
    ) -> AsyncThrowingStream<String, Error>
}

public extension LanguageModelClientProtocol {
    /// Convenience method for single prompt generation without additional instructions.
    func respond(to prompt: String) async throws -> String {
        try await respond(to: prompt, instructions: nil, options: nil).text
    }
    
    /// Convenience method for streaming a single prompt response.
    func stream(to prompt: String) -> AsyncThrowingStream<String, Error> {
        stream(to: prompt, instructions: nil, options: nil)
    }
}
