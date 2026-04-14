import Foundation
import CoreMotion
import Combine

@MainActor
class MotionManager: ObservableObject {
    
    let motionManager = CMMotionManager()
    
    @Published var movementMagnitude: Double = 0.0
    @Published var isGesticulating: Bool = false
    
    private var lastSendTime: Date = Date()
    
    func startTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Sensori non disponibili (Simulatore)")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            
            let x = data.userAcceleration.x
            let y = data.userAcceleration.y
            let z = data.userAcceleration.z
            let magnitude = sqrt(x*x + y*y + z*z)
            
            Task { @MainActor in
                guard let self = self else { return }
                
                self.movementMagnitude = magnitude
                self.isGesticulating = magnitude > 1.5
                
                let now = Date()
                if now.timeIntervalSince(self.lastSendTime) >= 0.2 {
                    WatchConnectivityManager.shared.sendMovement(magnitude)
                    self.lastSendTime = now
                }
            }
        }
    }
    
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
        self.movementMagnitude = 0.0
        self.isGesticulating = false
    }
}
