import Foundation
import SwiftState

/// Creates middleware that intercepts language model actions, manages request lifecycles, and executes prompts.
public func createLanguageModelMiddleware<S: State>(
    client: LanguageModelClientProtocol,
    now: @escaping @Sendable () -> Date = { Date() }
) -> Middleware<S> {
    return { action, getState, dispatch, next in
        next(action)
        
        // Handle standard prompt actions
        if let modelAction = action as? AnyLanguageModelAction {
            let startedAt = now()
            let initialState = LanguageModelRequestState(
                id: modelAction.requestID,
                prompt: modelAction.prompt,
                instructions: modelAction.instructions,
                status: .generating,
                startedAt: startedAt
            )
            dispatch(LanguageModelAction.generationStarted(initialState))
            
            Task { @MainActor in
                let result = await modelAction.perform(using: client)
                let duration = now().timeIntervalSince(startedAt)
                
                if let response = result.response {
                    dispatch(LanguageModelAction.generationSucceeded(
                        id: modelAction.requestID,
                        response: response.text,
                        duration: duration,
                        usage: response.usage
                    ))
                    
                    if let followUp = result.followUpAction {
                        dispatch(followUp)
                    }
                } else {
                    let errorMessage = result.errorMessage ?? "Language model generation failed."
                    dispatch(LanguageModelAction.generationFailed(
                        id: modelAction.requestID,
                        error: errorMessage,
                        duration: duration
                    ))
                    
                    if let followUp = result.followUpAction {
                        dispatch(followUp)
                    }
                }
            }
            return
        }
        
        // Handle streaming prompt actions
        if let streamAction = action as? LanguageModelStreamAction {
            let startedAt = now()
            let initialState = LanguageModelRequestState(
                id: streamAction.requestID,
                prompt: streamAction.prompt,
                instructions: streamAction.instructions,
                status: .generating,
                startedAt: startedAt
            )
            dispatch(LanguageModelAction.generationStarted(initialState))
            
            Task { @MainActor in
                var accumulated = ""
                let stream = client.stream(
                    to: streamAction.prompt,
                    instructions: streamAction.instructions,
                    options: streamAction.options
                )
                
                do {
                    for try await chunk in stream {
                        accumulated.append(chunk)
                        dispatch(LanguageModelAction.chunkReceived(id: streamAction.requestID, chunk: chunk))
                        if let onChunk = streamAction.onChunk, let chunkAction = onChunk(chunk) {
                            dispatch(chunkAction)
                        }
                    }
                    
                    let duration = now().timeIntervalSince(startedAt)
                    dispatch(LanguageModelAction.generationSucceeded(
                        id: streamAction.requestID,
                        response: accumulated,
                        duration: duration,
                        usage: nil
                    ))
                    
                    if let onSuccess = streamAction.onSuccess, let successAction = onSuccess(accumulated) {
                        dispatch(successAction)
                    }
                } catch {
                    let duration = now().timeIntervalSince(startedAt)
                    let errorMessage = error.localizedDescription
                    dispatch(LanguageModelAction.generationFailed(
                        id: streamAction.requestID,
                        error: errorMessage,
                        duration: duration
                    ))
                    
                    if let onFailure = streamAction.onFailure, let failureAction = onFailure(errorMessage) {
                        dispatch(failureAction)
                    }
                }
            }
            return
        }
    }
}
