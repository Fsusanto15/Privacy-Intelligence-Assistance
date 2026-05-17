//
//  AIManager.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 8/5/2026.
//

import Foundation
import FoundationModels
import LLM


enum LocalModelStrategy: String, CaseIterable {
    case qwenLite = "Qwen 0.5B (Fast)"
    case bonsai1Bit = "Bonsai 4B (Smart)"
}

class AIManager {
    static let shared = AIManager()
    private(set) var engine: AIEngine?
    private(set) var activeLocalStrategy: LocalModelStrategy = .qwenLite
    private(set) var isCurrentlyGenerating = false
    
    func initializeEngine() {
        if AIHardwareTier.appleNative.isSupported {
            print("using native engine")
            self.engine = NativeAppleEngine()
        } else {
            switch activeLocalStrategy {
            case .qwenLite:
                print("Using Qwen engine")
                self.engine = QwenLiteEngine()
            case .bonsai1Bit:
                print("Using 1-Bit Bonsai engine")
                self.engine = BonsaiEngine()
            }
        }
    }
    
    func switchModel(to strategy: LocalModelStrategy) -> Bool {
        guard !isCurrentlyGenerating else {
            return false
        }
        
        activeLocalStrategy = strategy
        initializeEngine()
        return true
    }
    
    func generateResponse(prompt: String, context: String) async throws -> String {
        isCurrentlyGenerating = true
        defer { isCurrentlyGenerating = false }
        
        guard let engine = engine else {
            throw NSError(domain: "AIManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active engine loaded"])
        }
        
        return try await engine.generateResponse(prompt: prompt, context: context)
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
        guard let modelURL = Bundle.main.url(forResource: "qwen2.5-0.5b-instruct-q4_k_m", withExtension: "gguf") else {
            print("Model file not found in bundle")
            return
        }

        let customTemplate = Template.chatML()
        self.bot = LLM(from: modelURL, template: customTemplate)
        print("✅ Qwen Lite Engine (Local) Ready")
    }
    
    func generateResponse(prompt: String, context: String) async throws -> String {
        guard let bot = bot else { return "Engine not initialized" }
        
        let systemPrompt = context.isEmpty
        ? "You are a helpful, clever, and private AI assistant. Help the user with any summaries, analysis, drafting, recommendation, or general knowledge questions."
        : "You are a private assistant. Use this context background to answer the question: \(context)"
        bot.template = .qwen(systemPrompt)

        let formattedInput = bot.preprocess(prompt, [], .none)
        return await bot.getCompletion(from: formattedInput)
    }
}

// MARK: - Bonsai Engine Implementation (PrismML 1-Bit Optimization Layer)
class BonsaiEngine: AIEngine {
    private var bot: LLM?

    init() {
        setupModel()
    }
    
    private func setupModel() {
        guard let modelURL = Bundle.main.url(forResource: "Bonsai-4B-Q1_0", withExtension: "gguf") else {
            print("Bonsai Model file not found in bundle.")
            return
        }
        
        let customTemplate = Template.chatML()
        self.bot = LLM(from: modelURL, template: customTemplate)
        if self.bot != nil {
                print("🌱 ✅ 1-Bit Bonsai 4B Engine initialized successfully!")
            } else {
                print("❌ Error: LLM.swift failed to allocate memory space for Bonsai.")
            }
//        print("✅ 1-Bit Bonsai 4B Engine Ready")
    }
    
    func generateResponse(prompt: String, context: String) async throws -> String {
        guard let bot = bot else { return "Bonsai Engine not initialized" }
        
        let systemPrompt = context.isEmpty
        ? "You are a highly capable on-device AI assistant. Provide deep, accurate, and insightful summaries, drafting, recommendations, analysis, and general assistance."
        : "You are a secure private assistant. Answer the user prompt accurately based exclusively on this text data:\n\(context)"
        bot.template = .chatML(systemPrompt)
        
        let formattedInput = bot.preprocess(prompt, [], .none)
        return await bot.getCompletion(from: formattedInput)
    }
}
