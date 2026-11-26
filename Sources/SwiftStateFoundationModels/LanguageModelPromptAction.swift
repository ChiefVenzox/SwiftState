import Foundation
import SwiftState

/// Result of executing a language model action.
public struct LanguageModelActionResult: Sendable {
    public let response: LanguageModelResponse?
    public let errorMessage: String?
    public let followUpAction: Action?
    
    public static func success(response: LanguageModelResponse, followUpAction: Action?) -> LanguageModelActionResult {
        LanguageModelActionResult(response: response, errorMessage: nil, followUpAction: followUpAction)
    }
    
    public static func failure(errorMessage: String, followUpAction: Action?) -> LanguageModelActionResult {
        LanguageModelActionResult(response: nil, errorMessage: errorMessage, followUpAction: followUpAction)
    }
    
    public var isSuccess: Bool {
        response != nil
    }
}

/// A protocol describing actions that trigger a language model prompt.
public protocol AnyLanguageModelAction: Action {
    var requestID: String { get }
    var prompt: String { get }
    var instructions: String? { get }
    var options: LanguageModelGenerationOptions? { get }
    
    @MainActor
    func perform(using client: LanguageModelClientProtocol) async -> LanguageModelActionResult
}

/// An action that dispatches a prompt to a language model and handles the response.
public struct LanguageModelPromptAction: AnyLanguageModelAction {
    public let requestID: String
    public let prompt: String
    public let instructions: String?
    public let options: LanguageModelGenerationOptions?
    
    private let onSuccess: @MainActor @Sendable (LanguageModelResponse) -> Action?
    private let onFailure: @MainActor @Sendable (String) -> Action?
    
    public init(
        id: String = UUID().uuidString,
        prompt: String,
        instructions: String? = nil,
        options: LanguageModelGenerationOptions? = nil,
        onSuccess: @escaping @MainActor @Sendable (LanguageModelResponse) -> Action?,
        onFailure: @escaping @MainActor @Sendable (String) -> Action? = { _ in nil }
    ) {
        self.requestID = id
        self.prompt = prompt
        self.instructions = instructions
        self.options = options
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    public init(
        id: String = UUID().uuidString,
        prompt: String,
        instructions: String? = nil,
        options: LanguageModelGenerationOptions? = nil,
        onText: @escaping @MainActor @Sendable (String) -> Action?,
        onFailure: @escaping @MainActor @Sendable (String) -> Action? = { _ in nil }
    ) {
        self.requestID = id
        self.prompt = prompt
        self.instructions = instructions
        self.options = options
        self.onSuccess = { response in onText(response.text) }
        self.onFailure = onFailure
    }
    
    @MainActor
    public func perform(using client: LanguageModelClientProtocol) async -> LanguageModelActionResult {
        do {
            let response = try await client.respond(to: prompt, instructions: instructions, options: options)
            return .success(response: response, followUpAction: onSuccess(response))
        } catch {
            return .failure(errorMessage: error.localizedDescription, followUpAction: onFailure(error.localizedDescription))
        }
    }
}
