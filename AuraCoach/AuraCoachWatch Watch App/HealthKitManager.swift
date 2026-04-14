import Foundation
import HealthKit
import SwiftUI
import Combine

@MainActor
class HealthKitManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    
    @Published var currentBPM: Double = 0.0
    @Published var activeCalories: Double = 0.0
    @Published var stepCount: Double = 0.0
    
    @Published var statusMessage: String = "READY"
    @Published var isWorkoutActive: Bool = false
    
    let healthStore = HKHealthStore()
    var workoutSession: HKWorkoutSession?
    var workoutBuilder: HKLiveWorkoutBuilder?
    var heartRateQuery: HKQuery?
    
    private var watchdogTask: Task<Void, Never>?
    
    func requestAuthorization() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        let workoutType = HKObjectType.workoutType()
        let typesToShare: Set<HKSampleType> = [workoutType]
        let typesToRead: Set<HKObjectType> = [heartRateType, activeEnergyType, stepCountType, workoutType]
        
        self.statusMessage = "AUTHORIZING..."
        Task {
            do {
                try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
                self.statusMessage = "AUTHORIZED"
            } catch {
                self.statusMessage = "ACCESS DENIED"
            }
        }
    }
    
    func startMockWorkout() {
        self.statusMessage = "STARTING..."
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .unknown

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self
            
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
                dataSource.enableCollection(for: stepType, predicate: nil)
            }
            if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                dataSource.enableCollection(for: energyType, predicate: nil)
            }
            workoutBuilder?.dataSource = dataSource
            workoutBuilder?.delegate = self
            
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            
            guard let builder = workoutBuilder else { return }
            
            Task {
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        builder.beginCollection(withStart: startDate) { success, error in
                            if let error = error { continuation.resume(throwing: error) }
                            else { continuation.resume(returning: ()) }
                        }
                    }
                    self.isWorkoutActive = true
                    self.statusMessage = "SENSORS ACTIVE"
                    self.startHeartRateQuery()
                    
                    self.resetWatchdog()
                    
                } catch {
                    self.statusMessage = "START ERROR"
                }
            }
        } catch {
            self.statusMessage = "SYSTEM ERROR"
        }
    }
    
    func stopMockWorkout() {
        guard isWorkoutActive else { return }
        self.isWorkoutActive = false
        
        watchdogTask?.cancel()
        watchdogTask = nil
        
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        
        workoutSession?.end()
        
        if let builder = workoutBuilder {
            builder.endCollection(withEnd: Date()) { [weak self] _, _ in
                builder.finishWorkout { [weak self] _, _ in
                    guard let strongSelf = self else { return }
                    
                    Task { @MainActor in
                        strongSelf.workoutSession = nil
                        strongSelf.workoutBuilder = nil
                    }
                }
            }
        }
        
        WatchConnectivityManager.shared.sendSessionSummary(calories: self.activeCalories, steps: self.stepCount)
        
        self.currentBPM = 0.0
        self.statusMessage = "SESSION ENDED"
        self.activeCalories = 0.0
        self.stepCount = 0.0
    }
    
    func startHeartRateQuery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            guard let manager = self else { return }
            Task { @MainActor in manager.processHeartRateSamples(samples) }
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            guard let manager = self else { return }
            Task { @MainActor in manager.processHeartRateSamples(samples) }
        }
        self.heartRateQuery = query
        healthStore.execute(query)
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample], let lastSample = heartRateSamples.last else { return }
        let bpm = lastSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        
        Task { @MainActor in
            self.currentBPM = bpm
            WatchConnectivityManager.shared.sendBPM(bpm)
            
            self.resetWatchdog()
        }
    }
    
    // MARK: - WATCHDOG
    private func resetWatchdog() {
        watchdogTask?.cancel()
        
        watchdogTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 12_000_000_000)
                
                guard !Task.isCancelled, self.isWorkoutActive else { return }
                
                print("No heartbeat detected for 12s. Watch removed!")
                
                self.currentBPM = 0.0
                WatchConnectivityManager.shared.sendBPM(0.0)
                
                self.stopMockWorkout()
                
            } catch {
            }
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended || toState == .stopped || toState == .paused {
            Task { @MainActor in self.stopMockWorkout() }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
    
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            Task { @MainActor in
                if quantityType == HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                    self.activeCalories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                }
                else if quantityType == HKObjectType.quantityType(forIdentifier: .stepCount) {
                    self.stepCount = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                }
            }
        }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
