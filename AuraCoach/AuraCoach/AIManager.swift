import Foundation
import Combine

@MainActor
class AIManager: ObservableObject {
    static let shared = AIManager()
    
    @Published var isGenerating: Bool = false
    @Published var generatedReport: String = ""
    
    // 🔑 REPLACE WITH YOUR GROQ API KEY
    private let apiKey = ""
    
    func generatePrompt(maxBPM: Double, maxG: Double, avgWPM: Double, maxWPM: Double, calories: Double, duration: TimeInterval, timeline: [SessionSnapshot]) -> String {
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let durationText = minutes > 0 ? "\(minutes) minutes and \(seconds) seconds" : "\(seconds) seconds"
        
        var voiceDataString = ""
        var voiceRulesString = "Do not make any reference to voice, speech, or speed (WPM), as the user did not record audio."
        
        if avgWPM > 0 {
            voiceDataString = """
            - AVERAGE speech speed: \(Int(avgWPM)) WPM
            - MAXIMUM speed (Peak): \(Int(maxWPM)) WPM
            """
            voiceRulesString = "Evaluate the WPM speed peaks by cross-referencing them with the anxiety timeline to understand if the speaker lost control of the pace."
        }
        
        var timelineString = ""
        if timeline.isEmpty {
            timelineString = "No temporal sampling available."
        } else {
            for snap in timeline {
                let m = Int(snap.timeElapsed) / 60
                let s = Int(snap.timeElapsed) % 60
                let timeFormat = String(format: "%02d:%02d", m, s)
                timelineString += "- Minute [\(timeFormat)] -> Anxiety: \(Int(snap.anxietyScore))% | Heart: \(Int(snap.bpm)) BPM | Agitation: \(String(format: "%.1f", snap.movement)) G\n"
            }
        }
        
        return """
        You are a behavioral analyst and strategic coach for public speaking. 
        Analyze the following biometric data of a user who just stepped off the stage.
        
        GLOBAL SUMMARY:
        - Duration: \(durationText)
        - Peak BPM: \(Int(maxBPM))
        - Peak Agitation (G): \(String(format: "%.1f", maxG))
        - Calories burned (Effort): \(Int(calories)) kcal
        \(voiceDataString)
        
        SESSION TIMELINE (Sampled every 10s):
        \(timelineString)
        
        ANALYSIS GUIDELINES:
        1. Tone: Be serious, clinical, and direct. NO emojis, no clichés. 
        2. Temporal Analysis (CRITICAL): Read the "TIMELINE". Understand the emotional trend. Did anxiety start very high (anticipatory anxiety) and then drop? Or did it spike mid-speech? Point this out to the user specifically (e.g., "At minute 01:20 there is a noticeable spike in tension").
        3. Audio Rule: \(voiceRulesString)
        4. Strategy: Give a practical piece of advice based on *when* the stress peak occurred.
        5. Format: Write a single fluid and conversational paragraph, maximum 5 sentences. Reply strictly in English.
        """
    }
    
    struct GroqMessage: Codable { let role: String; let content: String }
    struct GroqRequest: Codable { let model: String; let messages: [GroqMessage]; let temperature: Double }
    
    func fetchAIReport(maxBPM: Double, maxG: Double, avgWPM: Double, maxWPM: Double, calories: Double, duration: TimeInterval, timeline: [SessionSnapshot]) async {
        self.isGenerating = true
        self.generatedReport = "AuraCoach is processing the clinical analysis..."
        
        let promptText = generatePrompt(maxBPM: maxBPM, maxG: maxG, avgWPM: avgWPM, maxWPM: maxWPM, calories: calories, duration: duration, timeline: timeline)
        
        print("🤖 SENT TO GROQ:\n\(promptText)")
        
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            self.generatedReport = "URL Error."
            self.isGenerating = false
            return
        }
        
        let requestBody = GroqRequest(model: "llama-3.3-70b-versatile", messages: [GroqMessage(role: "user", content: promptText)], temperature: 0.6)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let cleanApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue("Bearer \(cleanApiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if httpResponse.statusCode != 200 {
                self.generatedReport = "Groq rejected the request (Error \(httpResponse.statusCode))."
                self.isGenerating = false
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let text = message["content"] as? String {
                self.generatedReport = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                self.generatedReport = "Unreadable AI response."
            }
        } catch {
            self.generatedReport = "Internet connection error."
        }
        
        self.isGenerating = false
    }
}
