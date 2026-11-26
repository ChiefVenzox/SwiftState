import Foundation
import SwiftState

/// Lifecycle status of a language model generation request.
public enum LanguageModelRequestStatus: String, Codable, Sendable, Equatable {
    case idle
    case generating
    case succeeded
    case failed
}

/// Represents the reactive state of a language model prompt or streaming operation.
public struct LanguageModelRequestState: State, Identifiable, Equatable {
    public let id: String
    public let prompt: String
    public let instructions: String?
    public let status: LanguageModelRequestStatus
    public let response: String?
    public let streamedChunks: [String]
    public let errorMessage: String?
    public let startedAt: Date
    public let finishedAt: Date?
    public let duration: TimeInterval?
    public let usage: LanguageModelTokenUsage?
    
    public init(
        id: String,
        prompt: String,
        instructions: String? = nil,
        status: LanguageModelRequestStatus = .generating,
        response: String? = nil,
        streamedChunks: [String] = [],
        errorMessage: String? = nil,
        startedAt: Date,
        finishedAt: Date? = nil,
        duration: TimeInterval? = nil,
        usage: LanguageModelTokenUsage? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.instructions = instructions
        self.status = status
        self.response = response
        self.streamedChunks = streamedChunks
        self.errorMessage = errorMessage
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.duration = duration
        self.usage = usage
    }
}

/// Standard lifecycle actions dispatched during language model processing.
public enum LanguageModelAction: Action, Equatable {
    case generationStarted(LanguageModelRequestState)
    case chunkReceived(id: String, chunk: String)
    case generationSucceeded(id: String, response: String, duration: TimeInterval, usage: LanguageModelTokenUsage?)
    case generationFailed(id: String, error: String, duration: TimeInterval)
}

/// A standard reducer helper to update a dictionary of language model request states.
public func languageModelReducer(
    state: inout [String: LanguageModelRequestState],
    action: Action
) {
    guard let modelAction = action as? LanguageModelAction else { return }
    
    switch modelAction {
    case .generationStarted(let initial):
        state[initial.id] = initial
        
    case .chunkReceived(let id, let chunk):
        guard let existing = state[id] else { return }
        var updatedChunks = existing.streamedChunks
        updatedChunks.append(chunk)
        let accumulated = updatedChunks.joined()
        state[id] = LanguageModelRequestState(
            id: existing.id,
            prompt: existing.prompt,
            instructions: existing.instructions,
            status: .generating,
            response: accumulated,
            streamedChunks: updatedChunks,
            errorMessage: nil,
            startedAt: existing.startedAt,
            finishedAt: nil,
            duration: nil,
            usage: existing.usage
        )
        
    case .generationSucceeded(let id, let response, let duration, let usage):
        guard let existing = state[id] else { return }
        state[id] = LanguageModelRequestState(
            id: existing.id,
            prompt: existing.prompt,
            instructions: existing.instructions,
            status: .succeeded,
            response: response,
            streamedChunks: existing.streamedChunks,
            errorMessage: nil,
            startedAt: existing.startedAt,
            finishedAt: existing.startedAt.addingTimeInterval(duration),
            duration: duration,
            usage: usage ?? existing.usage
        )
        
    case .generationFailed(let id, let error, let duration):
        guard let existing = state[id] else { return }
        state[id] = LanguageModelRequestState(
            id: existing.id,
            prompt: existing.prompt,
            instructions: existing.instructions,
            status: .failed,
            response: existing.response,
            streamedChunks: existing.streamedChunks,
            errorMessage: error,
            startedAt: existing.startedAt,
            finishedAt: existing.startedAt.addingTimeInterval(duration),
            duration: duration,
            usage: existing.usage
        )
    }
}
