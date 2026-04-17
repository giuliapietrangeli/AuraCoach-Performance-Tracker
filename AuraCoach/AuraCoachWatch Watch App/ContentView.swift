import SwiftUI

struct ContentView: View {
    @StateObject private var hkManager = HealthKitManager()
    @StateObject private var motionManager = MotionManager()
    @StateObject private var hapticManager = WatchHapticManager()
    
    @ObservedObject private var connectivity = WatchConnectivityManager.shared
    @AppStorage("permissionsGranted") private var permissionsGranted = false
    
    @State private var sessionStartTime: Date? = nil
    
    @State private var crownValue: Double = 0.0
    @State private var isAlertsPaused: Bool = false
    @State private var lastHapticValue: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                if isAlertsPaused {
                    Text("CALM MODE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.indigo)
                        .tracking(1.2)
                } else {
                    Text(hkManager.statusMessage)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(hkManager.isWorkoutActive ? .green : .gray)
                        .tracking(1.2)
                }
                
                Spacer()
                
                if let startTime = sessionStartTime, hkManager.isWorkoutActive {
                    Text(startTime, style: .timer)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.top, 5)
            
            Spacer()
            
            HStack(alignment: .center, spacing: 6) {
                ZStack {
                    Image(systemName: "heart.fill")
                        .opacity(0.25)
                    Image(systemName: "heart")
                        .fontWeight(.bold)
                }
                .foregroundColor(hkManager.isWorkoutActive ? .red : .gray)
                .font(.system(size: 28))
                .shadow(color: hkManager.isWorkoutActive ? .red.opacity(0.6) : .clear, radius: 4)
                .scaleEffect(hkManager.isWorkoutActive && hkManager.currentBPM > 0 ? 1.15 : 1.0)
                .animation(hkManager.isWorkoutActive ? .easeInOut(duration: 0.5).repeatForever() : .default, value: hkManager.currentBPM)
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(hkManager.isWorkoutActive ? "\(Int(hkManager.currentBPM))" : "--")
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText(value: hkManager.currentBPM))
                    
                    Text("BPM")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(hkManager.isWorkoutActive ? .white : .gray)
            
            Spacer()
            
            if hkManager.isWorkoutActive {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(motionManager.isGesticulating ? .orange : .green)
                        
                        Text(String(format: "%.1f G", motionManager.movementMagnitude))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(motionManager.isGesticulating ? .orange : .green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Gauge(value: min(motionManager.movementMagnitude, 3.0), in: 0...3.0) {}
                        .gaugeStyle(.accessoryLinear)
                        .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 35)
                
            } else if permissionsGranted {
                Text("Start session from iPhone")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            
            if !permissionsGranted {
                Button(action: {
                    hkManager.requestAuthorization()
                    permissionsGranted = true
                }) {
                    Text("Allow")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .clipShape(Capsule())
                .padding(.horizontal, 15)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .edgesIgnoringSafeArea(.bottom)
        
        .focusable(hkManager.isWorkoutActive)
        .digitalCrownRotation(
            $crownValue,
            from: -1000,
            through: 1000,
            by: 1,
            sensitivity: .low,
            isContinuous: true,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crownValue) { oldValue, newValue in
            if hkManager.isWorkoutActive {
                if abs(newValue - lastHapticValue) >= 2 {
                    hapticManager.triggerCrownHaptic()
                    lastHapticValue = newValue
                }
            }
        }
        
        .onLongPressGesture(minimumDuration: 1.5) {
            if hkManager.isWorkoutActive {
                hapticManager.triggerResetHaptic()
                isAlertsPaused = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                    isAlertsPaused = false
                }
            }
        }
        
        .onChange(of: hkManager.isWorkoutActive) { oldValue, newValue in
            if newValue {
                sessionStartTime = Date()
                isAlertsPaused = false
            } else {
                sessionStartTime = nil
                isAlertsPaused = false
            }
        }
        
        .onChange(of: connectivity.receivedRemoteCommand) { oldValue, newValue in
            if newValue.hasPrefix("start") && !hkManager.isWorkoutActive {
                hkManager.startMockWorkout()
                motionManager.startTracking()
            } else if newValue.hasPrefix("stop") && hkManager.isWorkoutActive {
                hkManager.stopMockWorkout()
                motionManager.stopTracking()
            } else if newValue.hasPrefix("vibrate_teso") && hkManager.isWorkoutActive {
                if !isAlertsPaused { hapticManager.triggerHaptic(type: .notification) }
            } else if newValue.hasPrefix("vibrate_panico") && hkManager.isWorkoutActive {
                if !isAlertsPaused { hapticManager.triggerPanicoHaptic() }
            }
        }
    }
}
