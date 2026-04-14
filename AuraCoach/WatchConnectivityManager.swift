import Foundation
import WatchConnectivity
import Combine
import SwiftUI

#if os(iOS)
import HealthKit
#endif

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    
    static let shared = WatchConnectivityManager()
    
    @Published var receivedBPM: Double = 0.0
    private let smoothingFactor = 0.05
    @Published var smoothedMovement: Double = 0.0
    @Published var maxBPM: Double = 0.0
    @Published var maxMovementRaw: Double = 0.0
    
    @Published var anxietyScore: Double = 0.0
    
    var anxietyLevel: String {
        if anxietyScore < 35 { return "Calm" }
        else if anxietyScore < 70 { return "Tense" }
        else { return "Panic" }
    }
    
    var anxietyColor: Color {
        if anxietyScore < 30 { return .green }
        else if anxietyScore < 70 { return .yellow }
        else { return .red }
    }
    
    @Published var finalCalories: Double = 0.0
    @Published var finalSteps: Double = 0.0
    @Published var showReport: Bool = false
    @Published var isSessionActive: Bool = false
    @Published var sessionStartTime: Date?
    @Published var finalDuration: TimeInterval = 0.0
    @Published var sessionTimeline: [SessionSnapshot] = []
    private var timelineTimer: Timer?
    
    @AppStorage("isHapticEnabled") var isHapticEnabled: Bool = true
    private var lastHapticSentTime: Date?
    
    @Published var triggerVibration: Bool = false
    @Published var receivedRemoteCommand: String = ""
    
    #if os(iOS)
    private let healthStore = HKHealthStore()
    #endif
    
    @Published var isVoiceEnabled: Bool = false
    @Published var currentWPM: Double = 0.0

    private func updateAnxietyScore() {
        let bpmThreshold: Double = 70.0
        let movementThreshold: Double = 0.4
        
        let bpmComponent = max(0, (receivedBPM - bpmThreshold) * 1.5)
        let motionComponent = max(0, (smoothedMovement - movementThreshold) * 40)
        
        var voiceComponent: Double = 0.0
        if isVoiceEnabled { voiceComponent = max(0, (currentWPM - 140) * 0.8) }
        
        let targetScore = min(100, bpmComponent + motionComponent + voiceComponent)
        self.anxietyScore = (self.anxietyScore * 0.8) + (targetScore * 0.2)
        
        if isHapticEnabled && isSessionActive {
            #if os(iOS)
            let now = Date()
            
            if let lastTime = lastHapticSentTime, now.timeIntervalSince(lastTime) < 5 { return }
            
            if targetScore >= 70 {
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(["command": "vibrate_panico"], replyHandler: nil)
                    lastHapticSentTime = now
                    print("Invio Vibrazione PANICO")
                }
            } else if targetScore >= 30 {
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(["command": "vibrate_teso"], replyHandler: nil)
                    lastHapticSentTime = now
                    print("Invio Vibrazione TESO")
                }
            }
            #endif
        }
    }
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    #if os(iOS)
    func requestIOSPermissions() {
        let workoutType = HKObjectType.workoutType()
        Task { try? await healthStore.requestAuthorization(toShare: [workoutType], read: [workoutType]) }
    }
    #endif
    
    func resetSession() {
        self.receivedBPM = 0.0
        self.smoothedMovement = 0.0
        self.maxBPM = 0.0
        self.maxMovementRaw = 0.0
        self.anxietyScore = 0.0
        self.finalCalories = 0.0
        self.finalSteps = 0.0
        self.isSessionActive = false
        self.sessionStartTime = nil
        self.finalDuration = 0.0
        self.sessionTimeline = []
        self.timelineTimer?.invalidate()
        self.timelineTimer = nil
    }
    
    func sendBPM(_ bpm: Double) { guard WCSession.default.isReachable else { return }; WCSession.default.sendMessage(["bpm": bpm], replyHandler: nil) }
    func sendMovement(_ movement: Double) { guard WCSession.default.isReachable else { return }; WCSession.default.sendMessage(["movement": movement], replyHandler: nil) }
    func sendSessionSummary(calories: Double, steps: Double) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["command": "summary", "calories": calories, "steps": steps], replyHandler: nil)
    }
    
    func sendStartCommandToWatch() {
        #if os(iOS)
        self.isSessionActive = true
        self.sessionStartTime = Date()
        
        self.timelineTimer?.invalidate()
        self.timelineTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                self.takeSnapshot()
            }
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .unknown
        
        if WCSession.default.activationState == .activated {
            WCSession.default.transferUserInfo(["command": "start"])
        }
        
        healthStore.startWatchApp(with: configuration) { success, error in
            let schedule = [0.1, 0.5, 1.0, 1.5, 2.5]
            for delay in schedule {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if WCSession.default.isReachable {
                        WCSession.default.sendMessage(["command": "start"], replyHandler: nil) { _ in }
                    }
                }
            }
        }
        #endif
    }
    
    func sendStopCommandToWatch() {
        self.takeSnapshot()
        
        self.isSessionActive = false
        self.timelineTimer?.invalidate()
        self.timelineTimer = nil
        
        if WCSession.default.isReachable { WCSession.default.sendMessage(["command": "stop"], replyHandler: nil) }
        if WCSession.default.activationState == .activated { WCSession.default.transferUserInfo(["command": "stop"]) }
    }
    
    private func takeSnapshot() {
        guard let start = sessionStartTime, isSessionActive else { return }
        
        let elapsed = Date().timeIntervalSince(start)
        
        let snapshot = SessionSnapshot(
            timeElapsed: elapsed,
            bpm: self.receivedBPM,
            movement: self.smoothedMovement,
            wpm: self.currentWPM,
            anxietyScore: self.anxietyScore
        )
        
        self.sessionTimeline.append(snapshot)
        print("Snapshot salvato al secondo \(Int(elapsed)): Ansia \(Int(self.anxietyScore))%")
    }
    
    // MARK: - RICEZIONE
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            if let bpm = message["bpm"] as? Double {
                self.receivedBPM = bpm
                if bpm > self.maxBPM { self.maxBPM = bpm }
            }
            if let newMovementRaw = message["movement"] as? Double {
                self.smoothedMovement = (1.0 - smoothingFactor) * self.smoothedMovement + smoothingFactor * newMovementRaw
                if newMovementRaw > self.maxMovementRaw { self.maxMovementRaw = newMovementRaw }
            }
            
            self.updateAnxietyScore()
            
            if let command = message["command"] as? String {
                if command == "start" || command == "stop" || command.hasPrefix("vibrate") {
                    self.receivedRemoteCommand = "\(command)_\(Date().timeIntervalSince1970)"
                }
                else if command == "summary" {
                    self.finalCalories = message["calories"] as? Double ?? 0
                    self.finalSteps = message["steps"] as? Double ?? 0
                    self.showReport = true
                }
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            if let command = userInfo["command"] as? String {
                if command == "start" || command == "stop" {
                    self.receivedRemoteCommand = "\(command)_\(Date().timeIntervalSince1970)"
                    print("Comando [\(command)] ricevuto in BACKGROUND!")
                }
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}

