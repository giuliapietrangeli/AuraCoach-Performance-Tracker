import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechManager: ObservableObject {
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var currentWPM: Double = 0
    @Published var isRecording = false
    @Published var transcript: String = ""
    
    @Published var maxWPM: Double = 0.0
    @Published var averageWPM: Double = 0.0
    
    private var timer: Timer?
    private var wordCountHistory: [(time: Date, count: Int)] = []
    private var totalWordsSoFar: Int = 0
    private var sessionStartTime: Date?

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    func startRecording() {
        stopRecording()
        resetData()
        sessionStartTime = Date()
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            let inputNode = audioEngine.inputNode
            
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                    self.totalWordsSoFar = self.transcript.split(separator: " ").count
                }
                if error != nil { self.stopRecording() }
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in self.refreshWPM() }
            }
        } catch {
            print("Audio Error: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        
        if let start = sessionStartTime {
            let durationInSeconds = Date().timeIntervalSince(start)
            let finalWordCount = self.transcript.split(separator: " ").count
            
            if durationInSeconds > 1.0 && finalWordCount > 0 {
                self.averageWPM = Double(finalWordCount) / (durationInSeconds / 60.0)
            } else {
                self.averageWPM = 0
            }
        }

        timer?.invalidate()
        timer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRecording = false
    }
    
    private func refreshWPM() {
        guard isRecording else { return }
        let now = Date()
        
        wordCountHistory.append((time: now, count: totalWordsSoFar))
        wordCountHistory = wordCountHistory.filter { now.timeIntervalSince($0.time) <= 7.0 }
        
        if let firstSample = wordCountHistory.first, wordCountHistory.count > 1 {
            let duration = now.timeIntervalSince(firstSample.time)
            let wordsSpokenInWindow = totalWordsSoFar - firstSample.count
            
            if duration > 0 {
                let instantWPM = Double(wordsSpokenInWindow) / (duration / 60.0)
                
                self.currentWPM = (self.currentWPM * 0.7) + (instantWPM * 0.3)
                
                if self.currentWPM < 5 { self.currentWPM = 0 }
            }
        }
        
        if self.currentWPM > self.maxWPM {
            self.maxWPM = self.currentWPM
        }
    }
    
    func resetData() {
        self.currentWPM = 0
        self.maxWPM = 0
        self.averageWPM = 0
        self.totalWordsSoFar = 0
        self.transcript = ""
        self.wordCountHistory = []
        self.sessionStartTime = nil
    }
}
