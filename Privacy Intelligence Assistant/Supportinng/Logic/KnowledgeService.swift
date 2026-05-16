//
//  KnowledgeService.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 10/5/2026.
//

import Foundation
import PDFKit

class KnowledgeService {
    static let shared = KnowledgeService()
    
    // This holds our "shredded" PDF sentences
    private var chunks: [String] = []

    /// Phase 1: Ingestion - Turning a file into searchable text
    func loadPDF(at url: URL) {
        guard let document = PDFDocument(url: url) else {
            print("Could not read PDF at \(url)")
            return
        }

        var fullText = ""
        for i in 0..<document.pageCount {
            if let pageText = document.page(at: i)?.string {
                fullText += pageText + " "
            }
        }

        // Phase 2: Chunking
        // For your portfolio, splitting by sentences is a great starting point.
        // It ensures the AI doesn't get a half-finished thought.
        self.chunks = fullText.components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 } // Ignore tiny fragments like "Page 1"
        
        print("📚 Indexed \(chunks.count) knowledge chunks.")
    }

    /// Phase 3: Retrieval - Finding the right answer to a question
    func getContext(for query: String) -> String {
        // 1. Clean the full raw query for exact matching later
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("checking cleanQuery: \(cleanQuery)")
        
        // 2. Extract meaningful keywords immediately (Stop-word filtering up front)
        // we will only rank based on words longer than 3 characters
        let keywords = cleanQuery.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 }
        
        // If no valid keywords left, avoid scanning
        guard !keywords.isEmpty else { return "" }
        
        // 3. Map chunks to a tuple containing the chunk and its calculated relevance score
        let scoredChunks = chunks.compactMap { chunk -> (text: String, score: Int)? in
            let chunkLower = chunk.lowercased()
            var score = 0
            
            // Metric A: Term Frequency (TF)
            // Count EVERY time a keyword appears, not just if it exists once.
            print("checking keywords: \(keywords)")
            for keyword in keywords {
                print("\nchecking keyword: \(keyword)")
                let components = chunkLower.components(separatedBy: keyword)
                let occurrences = components.count - 1
                print("checking components: \(components)")
                // Give points for every occurrence
                score += occurrences * 2
            }
            
            // Metric B: Exact Phrase Match Bonus
            // If the user types "iOS Developer" and those words sit exactly next to each other,
            // this chunk is highly relevant. Give it a massive priority boost.
            if chunkLower.contains(cleanQuery) {
                score += 15
            }
            
            // Reject chunks that scored 0 to keep the prompt clean
            return score > 0 ? (text: chunk, score: score) : nil
        }
        
        print("checking scoredChunks: \(scoredChunks)")
        
        // 4. Sort descending by the highest score
        let sortedMatches = scoredChunks.sorted { $0.score > $1.score }.map { $0.text }
        
        // 5. Return top 3 highest scoring chunks
        return sortedMatches.prefix(3).joined(separator: ". ")
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
        
        // use wildcard, to sort chunks by how many words they match
        let sortedMatches = matches.sorted { a, b in
            let countA = queryWords.filter { a.lowercased().contains($0) }.count
            let countB = queryWords.filter { b.lowercased().contains($0) }.count
            return countA > countB
        }
        
        // Return the top 3 most relevant sentences to keep the prompt short
        return sortedMatches.prefix(3).joined(separator: ". ")
//        return matches.joined(separator: "\n")
    }
}
