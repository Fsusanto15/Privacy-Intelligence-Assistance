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
