//
//  StorageModels.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 16/5/2026.
//

import Foundation
import SwiftData

@Model
final class PersistedChunk {
    var text: String
    var timestamp: Date
    
    init(text: String) {
        self.text = text
        self.timestamp = Date()
    }
}

@Model
final class PersistedMessage {
    var text: String
    var senderType: String
    var sourceContext: String?
    var timestamp: Date
    
    init(text: String, senderType: String, sourceContext: String? = nil) {
        self.text = text
        self.senderType = senderType
        self.sourceContext = sourceContext
        self.timestamp = Date()
    }
}
