import Foundation

/// Errors that can occur during language model interactions.
public enum LanguageModelError: LocalizedError, Equatable, Sendable {
    case unavailable(String)
    case contextSizeExceeded(String)
    case generationFailed(String)
    case cancelled
    case unsupportedPlatform(String)
    
    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return "Language model is unavailable: \(reason)"
        case .contextSizeExceeded(let message):
            return "Context size exceeded: \(message)"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .cancelled:
            return "Generation was cancelled."
        case .unsupportedPlatform(let reason):
            return "Unsupported platform: \(reason)"
        }
    }
}

/// Generation configuration options passed to language model requests.
public struct LanguageModelGenerationOptions: Sendable, Equatable, Codable {
    public var temperature: Double?
    public var maxTokens: Int?
    public var stopSequences: [String]
    
    public init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        stopSequences: [String] = []
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
    }
}

/// Token usage statistics for a generation request.
public struct LanguageModelTokenUsage: Sendable, Equatable, Codable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    
    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}

/// A structured response returned by a language model client.
public struct LanguageModelResponse: Sendable, Equatable {
    public let text: String
    public let usage: LanguageModelTokenUsage?
    
    public init(text: String, usage: LanguageModelTokenUsage? = nil) {
        self.text = text
        self.usage = usage
    }
}
