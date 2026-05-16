//
//  AIEngine.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 8/5/2026.
//

import Foundation

protocol AIEngine {
    func generateResponse(prompt: String, context: String) async throws -> String
}

enum AIHardwareTier {
    case appleNative  // iPhone 15 Pro, 16+ (8GB RAM)
    var isSupported: Bool {
        // In 2026, we check specifically for physical memory
        return ProcessInfo.processInfo.physicalMemory >= 8 * 1024 * 1024 * 1024
    }
}
//
//
//enum ModelEngine {
//    case appleIntelligence // iPhone 15 Pro+
//    case qwenLite          // iPhone 13/14
//}
//
//class AIManager {
//    static let shared = AIManager()
//    
//    var activeEngine: ModelEngine {
//        // iPhone 13 has approx 4,000,000,000 bytes
//        return ProcessInfo.processInfo.physicalMemory > 7_000_000_000
//            ? .appleIntelligence : .qwenLite
//    }
//    
//    func generateResponse(prompt: String, context: String) async -> String {
//        switch activeEngine {
//        case .appleIntelligence:
//            return try await NativeLLM.generate(prompt, context: context)
//        case .qwenLite:
//            return LlamaCppBridge.shared.infer(prompt, context: context)
//        }
//    }
//}
