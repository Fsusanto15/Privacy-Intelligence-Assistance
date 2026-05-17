//
//  ViewController.swift
//  Privacy Intelligence Assistant
//
//  Created by Felix B Susanto on 8/5/2026.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        runAITest()
    }
    
    func runAITest() {
        Task {
            print("⏳ Starting AI Test...")
            
            // 1. Initialize the Brain
            AIManager.shared.initializeEngine()
            
            // 2. Load the PDF into the Knowledge Service
            // use Felix B Susanto - Resume or Internship Weekly Reports - Felix B Susanto (48067563)
            if let resumeURL = Bundle.main.url(forResource: "Felix B Susanto - Resume", withExtension: "pdf") {
                await KnowledgeService.shared.loadPDF(at: resumeURL)
                print("✅ PDF Loaded into Knowledge Base")
            } else {
                print("❌ Could not find Resume.pdf in Bundle")
                return
            }
            
            // 3. Ask a specific question
            let myQuestion = "What this candidate do on WebSchool.au?"
            
            // 4. Get relevant context from the PDF
            let context = KnowledgeService.shared.getContext(for: myQuestion)
//            let context = KnowledgeService.shared.getChunks()
            print("📝 Found Context: \(context)")
            
            // 5. Generate AI Response
            do {
                if let answer = try await AIManager.shared.engine?.generateResponse(
                    prompt: myQuestion,
                    context: context
                ) {
                    print("\n🤖 AI RESPONSE:\n\(answer)\n")
                }
            } catch {
                print("❌ AI Inference Error: \(error)")
            }
        }
    }

}

