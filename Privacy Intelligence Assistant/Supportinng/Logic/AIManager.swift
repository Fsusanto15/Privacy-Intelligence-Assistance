//
//  AIManager.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 8/5/2026.
//

import Foundation
import FoundationModels
import LLM
//import LlamaSwift


class AIManager {
    static let shared = AIManager()
    private(set) var engine: AIEngine?
    
    func initializeEngine() {
        if AIHardwareTier.appleNative.isSupported {
            // supports native engine
            print("using native engine")
            self.engine = NativeAppleEngine()
        } else {
            // doesn't support native engine, use Qwen instead
            print("using Qwen engine")
            self.engine = QwenLiteEngine()
        }
    }
        
    
}

// MARK: - Native Engine Implementation
class NativeAppleEngine: AIEngine {
    private let session = LanguageModelSession()

    func generateResponse(prompt: String, context: String) async throws -> String {
        let fullPrompt = "Context: \(context)\n\nQuestion: \(prompt)"
        let response = try await session.respond(to: fullPrompt)
        return response.content
    }
}

// MARK: - Lite Engine (Placeholder for LLM) - from (https://github.com/obra/LLM.swift)
class QwenLiteEngine: AIEngine {
    private var bot: LLM?

        init() {
            setupModel()
        }
    
    private func setupModel() {
        // 1. Get the URL for your bundled GGUF model
        guard let modelURL = Bundle.main.url(forResource: "qwen2.5-0.5b-instruct-q4_k_m", withExtension: "gguf") else {
            print("Model file not found in bundle")
            return
        }
        
        // 1. Create a custom template with your System Prompt
        let customTemplate = Template.chatML()
        
        // 2. Initialize the LLM
        // For Qwen, we use the .chatML template for best results
        self.bot = LLM(from: modelURL, template: customTemplate)
        
        print("✅ Qwen Lite Engine (Local) Ready")
    }
    
    func generateResponse(prompt: String, context: String) async throws -> String {
        guard let bot = bot else { return "Engine not initialized" }
        
        // This updates the 'Stop Sequences' in the engine automatically
        let ragSystemPrompt = "You are a private assistant. Use this context: \(context)"
        bot.template = .qwen(ragSystemPrompt)
        
        // preprocess handles the hidden BOS tokens required by Qwen
        let formattedInput = bot.preprocess(prompt, [], .none)
        
        // getCompletion is a clean, async way to get the text
        return await bot.getCompletion(from: formattedInput)
    }
}
