//
//  ChatMessage.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 16/5/2026.
//

import UIKit

enum MessageSender {
    case user
    case ai(sourceContext: String?) // Holds the retrieved text for transparency
}

struct ChatMessage {
    let text: String
    let sender: MessageSender
    let timestamp: Date = Date()
}
