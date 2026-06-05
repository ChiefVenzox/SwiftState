import Foundation
import SwiftState

public func createNetworkMiddleware<S: State>(
    client: HTTPClientProtocol,
    now: @escaping @Sendable () -> Date = { Date() }
) -> Middleware<S> {
    return { action, getState, dispatch, next in
        next(action)
        
        guard let networkAction = action as? AnyNetworkRequestAction else { return }
        
        let startedAt = now()
        let initialState = NetworkRequestState(
            id: networkAction.requestID,
            method: networkAction.method,
            path: networkAction.path,
            status: .running,
            startedAt: startedAt
        )
        dispatch(NetworkAction.requestStarted(initialState))
        
        Task { @MainActor in
            var lastResult: NetworkRequestResult?
            
            for _ in 0..<networkAction.retryPolicy.maxAttempts {
                let result = await networkAction.perform(using: client)
                lastResult = result
                
                if result.isSuccess {
                    let duration = now().timeIntervalSince(startedAt)
                    dispatch(NetworkAction.requestSucceeded(
                        id: networkAction.requestID,
                        statusCode: result.statusCode ?? 200,
                        duration: duration
                    ))
                    
                    if let followUpAction = result.followUpAction {
                        dispatch(followUpAction)
                    }
                    return
                }
            }
            
            let duration = now().timeIntervalSince(startedAt)
            let errorMessage = lastResult?.errorMessage ?? "Network request failed."
            dispatch(NetworkAction.requestFailed(
                id: networkAction.requestID,
                error: errorMessage,
                duration: duration
            ))
            
            if let followUpAction = lastResult?.followUpAction {
                dispatch(followUpAction)
            }
        }
    }
}
