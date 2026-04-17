import Foundation
import WatchKit
import SwiftUI
import Combine

#if os(watchOS)
@MainActor
final class WatchHapticManager: ObservableObject {
    
    private var isHapticActive = false
    
    func triggerHaptic(type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    
    func triggerPanicoHaptic() {
        guard !isHapticActive else { return }
        Task {
            for _ in 0..<2 {
                WKInterfaceDevice.current().play(.failure)
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
    
    func triggerCrownHaptic() {
        WKInterfaceDevice.current().play(.click)
    }

    func triggerResetHaptic() {
        guard !isHapticActive else { return }
        
        isHapticActive = true
        
        Task {
            print("Avvio Heartbeat Sync PROFONDO (iMessage Style)...")
            
            for _ in 0..<3 {
                WKInterfaceDevice.current().play(.notification)
                try? await Task.sleep(nanoseconds: 200_000_000)
                WKInterfaceDevice.current().play(.notification)
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            isHapticActive = false 
        }
    }
}
#endif
