//
//  ConversationAssistant.swift
//  Runner
//
//  Conversation coach that analyzes transcript and provides suggestions
//

import Foundation

class ConversationAssistant {
    static let shared = ConversationAssistant()

    var onSuggestionsUpdated: (([ConversationSuggestion]) -> Void)?
    var onGlassesSuggestions: ((String) -> Void)? // 3 lines max for glasses

    private var analysisTimer: Timer?
    private var analysisInterval: TimeInterval = 3.0 // Configurable
    private var openAIService = OpenAIService()

    private var fullTranscript: String = "" // Complete running transcript
    private var transcriptStartTime: Date? // Track when transcript started
    private var isAnalyzing: Bool = false // Prevent concurrent analyses
    private var lastTranscriptUpdate: Date? // Track last transcript change
    private var currentAnalysisTask: Task<Void, Never>? // Track current task for cancellation
    private var lastAnalyzedTranscript: String = "" // Track transcript we last analyzed

    private init() {}

    // MARK: - Configuration

    func setAnalysisInterval(_ interval: TimeInterval) {
        analysisInterval = interval
        print("⚙️ Analysis interval set to \(interval) seconds")

        // Restart timer if running
        if analysisTimer != nil {
            startAnalysis()
        }
    }

    // MARK: - Transcript Management

    func updateTranscript(_ text: String) {
        // Update the full running transcript (throttled logging)
        fullTranscript = text
        lastTranscriptUpdate = Date()

        if transcriptStartTime == nil {
            transcriptStartTime = Date()
            print("📝 Transcript started")
        }
    }

    func manualAnalyze() {
        print("🔍 Manual analysis triggered")
        analyzeConversation()
    }

    func getRecentTranscript() -> String {
        return fullTranscript
    }

    func clearTranscript() {
        fullTranscript = ""
        transcriptStartTime = nil
        lastTranscriptUpdate = nil
        lastAnalyzedTranscript = "" // Reset so next analysis will run
        print("🗑️ Transcript cleared")
    }

    // MARK: - Analysis

    func startAnalysis() {
        stopAnalysis()

        print("🧠 Starting conversation analysis (every \(analysisInterval)s)")

        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            self?.analyzeConversation()
        }

        // Run first analysis immediately
        analyzeConversation()
    }

    func stopAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil

        // Cancel any pending analysis task
        currentAnalysisTask?.cancel()
        currentAnalysisTask = nil
        isAnalyzing = false

        print("🛑 Stopped conversation analysis")
    }

    private func analyzeConversation() {
        // Prevent concurrent analyses
        guard !isAnalyzing else {
            print("⏭️ Skipping analysis - previous analysis still running")
            return
        }

        // Skip if no recent transcript updates (idle for >30 seconds)
        if let lastUpdate = lastTranscriptUpdate {
            let idleTime = Date().timeIntervalSince(lastUpdate)
            if idleTime > 30 {
                print("⏭️ Skipping analysis - idle for \(Int(idleTime))s")
                return
            }
        }

        let transcript = getRecentTranscript()

        guard !transcript.isEmpty else {
            print("⏭️ Skipping analysis - no transcript")
            return
        }

        // Lower threshold for glasses mic (shorter voice sessions)
        guard transcript.count > 5 else {
            print("⏭️ Skipping analysis - transcript too short (\(transcript.count) chars)")
            return
        }

        // Skip if transcript hasn't changed since last analysis
        if transcript == lastAnalyzedTranscript {
            print("⏭️ Skipping analysis - transcript unchanged")
            return
        }

        print("🧠 Analyzing conversation... (\(transcript.count) chars, changed: \(transcript != lastAnalyzedTranscript))")
        lastAnalyzedTranscript = transcript
        isAnalyzing = true

        // Cancel any existing task
        currentAnalysisTask?.cancel()

        currentAnalysisTask = Task {
            defer {
                Task { @MainActor in
                    self.isAnalyzing = false
                    self.currentAnalysisTask = nil
                }
            }

            // Check for cancellation
            guard !Task.isCancelled else {
                print("⏭️ Analysis cancelled")
                return
            }

            do {
                let suggestions = try await getSuggestions(for: transcript)

                // Check again before updating UI
                guard !Task.isCancelled else {
                    print("⏭️ Analysis cancelled after completion")
                    return
                }

                await MainActor.run {
                    self.onSuggestionsUpdated?(suggestions)

                    // Format for glasses (3 lines max, up to 30 chars each)
                    let glassesText = self.formatForGlasses(suggestions)
                    self.onGlassesSuggestions?(glassesText)
                }
            } catch {
                print("❌ Analysis failed: \(error)")
            }
        }
    }

    private func getSuggestions(for transcript: String) async throws -> [ConversationSuggestion] {
        print("📤 Sending to GPT-5 with web search enabled...")

        // Focus on the most recent part of the transcript (last 500 chars for better context)
        let recentTranscript = String(transcript.suffix(500))

        // Extract the VERY LAST sentence/utterance (most critical)
        let lastUtterance = extractLastUtterance(from: recentTranscript)

        let prompt = """
You are an AI assistant for smart glasses. Provide concise, relevant keywords and information based on what the user is saying.

RECENT CONTEXT:
"\(recentTranscript)"

MOST RECENT UTTERANCE:
"\(lastUtterance)"

YOUR TASK:
Output a stream of relevant keywords and brief facts. Be extremely concise.

IF IT'S A QUESTION:
- Answer with key facts and data points
- Use web search for current info (sports, news, facts, people, events)
- Never say "I don't know" - always provide relevant info

IF IT'S A STATEMENT:
- Provide relevant insights or talking points
- Suggest useful follow-up topics

EXAMPLES:

Input: "Who's the best player on MIT men's tennis team"
Output:
MIT Athletics roster
Top singles varies by season
Check current rankings

Input: "How was your day"
Output:
Good opener
Ask specifics
Share your day too

Input: "quarterly review meeting tomorrow"
Output:
Review Q3 numbers
Prepare talking points
Anticipate questions

Input: "weather in Tokyo"
Output:
Tokyo: 18°C partly cloudy
Humidity 65%, Wind 10km/h
Spring/fall best seasons

CRITICAL RULES:
1. Be extremely concise - keywords and brief phrases
2. Never include sources, citations, URLs, or references
3. Never say "I don't know" or "please clarify"
4. Use web search for factual questions
5. Output 3-5 short pieces of information
6. No numbering, bullets, or special formatting
7. Separate pieces with line breaks

OUTPUT (concise keywords and info):
"""

        print("📝 Sending concise prompt (last utterance: '\(lastUtterance.prefix(50))...', context: \(recentTranscript.count) chars)...")

        let response = try await openAIService.sendChatRequest(question: prompt, enableWebSearch: true)

        print("✅ Got response with web search: \(response)")

        // Parse response into suggestions
        var lines = response.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Remove any numbering, bullets, or source indicators
        lines = lines.map { line in
            line.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^Source:.*", with: "", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: "^\\[.*?\\]\\s*", with: "", options: .regularExpression)
        }
        .filter { !$0.isEmpty }

        print("📋 Parsed \(lines.count) suggestions: \(lines)")

        // Take up to 5 pieces of info
        let suggestions = lines.prefix(5).map { line in
            ConversationSuggestion(text: String(line), timestamp: Date())
        }

        print("✅ Returning \(suggestions.count) suggestions")

        return suggestions
    }

    private func extractLastUtterance(from transcript: String) -> String {
        // Extract the most recent meaningful utterance from the transcript
        // This works even without punctuation by using word boundaries and length heuristics
        
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        // Try to find the last sentence by looking for punctuation
        let sentenceDelimiters = CharacterSet(charactersIn: ".?!\n")
        let components = trimmed.components(separatedBy: sentenceDelimiters)
        
        // Get the last non-empty component (most recent utterance)
        if let lastComponent = components.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let lastUtterance = lastComponent.trimmingCharacters(in: .whitespaces)
            
            // If it's reasonably long (>10 chars), use it
            if lastUtterance.count >= 10 {
                // Limit to last 200 chars to keep focused but allow full context
                return String(lastUtterance.suffix(200))
            }
        }
        
        // Fallback: No clear punctuation or last segment too short
        // Take the last 150 characters - this captures the most recent speech
        // even when there's no punctuation
        return String(trimmed.suffix(150))
    }

    private func formatForGlasses(_ suggestions: [ConversationSuggestion]) -> String {
        // Join suggestions with single newline between each
        // This creates a compact stream of info
        let formatted = suggestions.map { $0.text }
        let result = formatted.joined(separator: "\n")
        
        // Truncate if total exceeds 200 chars (reasonable limit for glasses display)
        let truncated = result.count > 200 ? String(result.prefix(200)) : result
        
        print("👓 Formatted for glasses (\(formatted.count) pieces, \(truncated.count) total chars):")
        formatted.forEach { print("   '\($0)'") }
        return truncated
    }
}
