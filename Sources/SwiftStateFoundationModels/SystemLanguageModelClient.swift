import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// A production client connecting SwiftState directly to Apple's native FoundationModels framework
/// (Apple Intelligence on-device & Private Cloud Compute models).
public final class SystemLanguageModelClient: LanguageModelClientProtocol, @unchecked Sendable {
    
    public init() {}
    
    /// Checks if the Apple Foundation Model is available on the current device.
    public var isAvailable: Bool {
        get async {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, tvOS 27.0, watchOS 27.0, *) {
                switch SystemLanguageModel.default.availability {
                case .available:
                    return true
                case .unavailable:
                    return false
                @unknown default:
                    return false
                }
            } else {
                return false
            }
            #else
            return false
            #endif
        }
    }
    
    /// Sends a prompt to the model and waits for the complete response.
    public func respond(
        to prompt: String,
        instructions: String? = nil,
        options: LanguageModelGenerationOptions? = nil
    ) async throws -> LanguageModelResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, tvOS 27.0, watchOS 27.0, *) {
            guard await isAvailable else {
                throw LanguageModelError.unavailable("Apple Intelligence SystemLanguageModel is not available on this device.")
            }
            
            let session: LanguageModelSession
            if let instructions = instructions, !instructions.isEmpty {
                session = LanguageModelSession(instructions: instructions)
            } else {
                session = LanguageModelSession()
            }
            
            let modelOptions: FoundationModels.GenerationOptions?
            if let options = options, let temperature = options.temperature {
                modelOptions = FoundationModels.GenerationOptions(temperature: temperature)
            } else {
                modelOptions = nil
            }
            
            do {
                let response: LanguageModelSession.Response<String>
                if let modelOptions = modelOptions {
                    response = try await session.respond(to: prompt, options: modelOptions)
                } else {
                    response = try await session.respond(to: prompt)
                }
                
                let tokenUsage = LanguageModelTokenUsage(
                    inputTokens: session.usage.promptTokenCount,
                    outputTokens: session.usage.responseTokenCount,
                    totalTokens: session.usage.totalTokenCount
                )
                
                return LanguageModelResponse(
                    text: response.content,
                    usage: tokenUsage
                )
            } catch let error as LanguageModelError {
                throw error
            } catch {
                throw LanguageModelError.generationFailed(error.localizedDescription)
            }
        } else {
            throw LanguageModelError.unsupportedPlatform("FoundationModels requires iOS 26.0+, macOS 26.0+, or newer.")
        }
        #else
        throw LanguageModelError.unsupportedPlatform("FoundationModels is only available on supported Apple platforms.")
        #endif
    }
    
    /// Streams generated tokens incrementally as an asynchronous sequence.
    public func stream(
        to prompt: String,
        instructions: String? = nil,
        options: LanguageModelGenerationOptions? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, tvOS 27.0, watchOS 27.0, *) {
                Task {
                    guard await self.isAvailable else {
                        continuation.finish(throwing: LanguageModelError.unavailable("Apple Intelligence SystemLanguageModel is not available on this device."))
                        return
                    }
                    
                    let session: LanguageModelSession
                    if let instructions = instructions, !instructions.isEmpty {
                        session = LanguageModelSession(instructions: instructions)
                    } else {
                        session = LanguageModelSession()
                    }
                    
                    let modelOptions: FoundationModels.GenerationOptions?
                    if let options = options, let temperature = options.temperature {
                        modelOptions = FoundationModels.GenerationOptions(temperature: temperature)
                    } else {
                        modelOptions = nil
                    }
                    
                    do {
                        let stream: LanguageModelSession.ResponseStream<String>
                        if let modelOptions = modelOptions {
                            stream = try session.streamResponse(to: prompt, options: modelOptions)
                        } else {
                            stream = try session.streamResponse(to: prompt)
                        }
                        
                        var lastSnapshot = ""
                        for try await snapshot in stream {
                            if snapshot.hasPrefix(lastSnapshot) {
                                let newChunk = String(snapshot.dropFirst(lastSnapshot.count))
                                if !newChunk.isEmpty {
                                    continuation.yield(newChunk)
                                }
                            } else {
                                continuation.yield(snapshot)
                            }
                            lastSnapshot = snapshot
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: LanguageModelError.generationFailed(error.localizedDescription))
                    }
                }
            } else {
                continuation.finish(throwing: LanguageModelError.unsupportedPlatform("FoundationModels requires iOS 26.0+, macOS 26.0+, or newer."))
            }
            #else
            continuation.finish(throwing: LanguageModelError.unsupportedPlatform("FoundationModels is only available on supported Apple platforms."))
            #endif
        }
    }
}
