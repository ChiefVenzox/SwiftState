import Foundation
import SwiftState

/// An action that initiates streaming token generation from a language model.
public struct LanguageModelStreamAction: Action {
    public let requestID: String
    public let prompt: String
    public let instructions: String?
    public let options: LanguageModelGenerationOptions?
    
    public let onChunk: (@MainActor @Sendable (String) -> Action?)?
    public let onSuccess: (@MainActor @Sendable (String) -> Action?)?
    public let onFailure: (@MainActor @Sendable (String) -> Action?)?
    
    public init(
        id: String = UUID().uuidString,
        prompt: String,
        instructions: String? = nil,
        options: LanguageModelGenerationOptions? = nil,
        onChunk: (@MainActor @Sendable (String) -> Action?)? = nil,
        onSuccess: (@MainActor @Sendable (String) -> Action?)? = nil,
        onFailure: (@MainActor @Sendable (String) -> Action?)? = nil
    ) {
        self.requestID = id
        self.prompt = prompt
        self.instructions = instructions
        self.options = options
        self.onChunk = onChunk
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
}
