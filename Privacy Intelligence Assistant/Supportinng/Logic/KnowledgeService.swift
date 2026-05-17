//
//  KnowledgeService.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 10/5/2026.
//

import Foundation
import PDFKit
import SwiftData

class KnowledgeService {
    static let shared = KnowledgeService()
    
    // This holds our "shredded" PDF sentences
    private var chunks: [String] = []
    private var modelContext: ModelContext?
    
    func configure(with context: ModelContext) {
        self.modelContext = context
        loadChunksFromStorage()
    }
    
    private func loadChunksFromStorage() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<PersistedChunk>(sortBy: [SortDescriptor(\.timestamp)])
        do {
            let savedChunks = try context.fetch(descriptor)
            self.chunks = savedChunks.map { $0.text }
            print("Saved Restored \(chunks.count) chunks from persistent storage.")
        } catch {
            print("Failed to fetch stored chunks: \(error)")
        }
    }
    
    /// Phase 1: Ingestion - Turning a file into searchable text
    func loadPDF(at url: URL) async {
        let segments = await Task.detached(priority: .userInitiated) { () -> [String] in
            guard let document = PDFDocument(url: url) else { return [] }
            var fullText = ""
            for i in 0..<document.pageCount {
                if let pageText = document.page(at: i)?.string {
                    fullText += pageText + " "
                }
            }
            
            return fullText.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 20 }
        }.value
        
        await MainActor.run {
            guard let context = self.modelContext else { return }
            
            self.chunks = segments
            
            // Clear old chunks from disk before adding new document data
            try? context.delete(model: PersistedChunk.self)
            
            for segment in segments {
                let chunk = PersistedChunk(text: segment)
                context.insert(chunk)
            }
            
            try? context.save()
        }
    }
    
    /// Phase 3: Retrieval - Finding the right answer to a question
    func getContext(for query: String) -> String {
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = cleanQuery.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 }
        
        guard !keywords.isEmpty else { return "" }
        let scoredChunks = chunks.compactMap { chunk -> (text: String, score: Int)? in
            let chunkLower = chunk.lowercased()
            var score = 0

            for keyword in keywords {
                let components = chunkLower.components(separatedBy: keyword)
                let occurrences = components.count - 1
                
                score += occurrences * 2
            }
            
            if chunkLower.contains(cleanQuery) {
                score += 15
            }
            
            return score > 0 ? (text: chunk, score: score) : nil
        }
        let sortedMatches = scoredChunks.sorted { $0.score > $1.score }.map { $0.text }
        return sortedMatches.prefix(3).joined(separator: ". ")
    }
    
    func clearAllChunks() {
        chunks.removeAll()
        guard let context = modelContext else { return }
        try? context.delete(model: PersistedChunk.self)
        try? context.save()
    }
    
    
    /// Temp
    func getContext2(for query: String) -> String {
        // clean the query from ?, *, ., ,, ~, etc
        let queryWords = query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        
        // TODO: In the future, we can upgrade this to "Vector Search."
        let matches = chunks.filter { chunk in
            let chunkLower = chunk.lowercased()
            
            return queryWords.contains { word in
                word.count > 3 && chunkLower.contains(word)
            }
        }
        
        let sortedMatches = matches.sorted { a, b in
            let countA = queryWords.filter { a.lowercased().contains($0) }.count
            let countB = queryWords.filter { b.lowercased().contains($0) }.count
            return countA > countB
        }
        
        return sortedMatches.prefix(3).joined(separator: ". ")
        //        return matches.joined(separator: "\n")
    }
}
