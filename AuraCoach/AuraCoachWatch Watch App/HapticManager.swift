import Foundation
import WatchKit
import SwiftUI
import Combine

#if os(watchOS)
@MainActor
final class WatchHapticManager: ObservableObject {
    
    func triggerHaptic(type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
        print("Eseguita vibrazione: \(type.rawValue)")
    }
    
    func triggerPanicoHaptic() {
        Task {
            print("Avviso PANICO: Raffica forte in corso...")
            for _ in 0..<2 {
                WKInterfaceDevice.current().play(.failure)
                try? await Task.sleep(nanoseconds: 400_000_000) 
            }
        }
    }
}
#endif
