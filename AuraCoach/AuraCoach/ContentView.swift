import SwiftUI
import Charts

struct TintedBoxStyle: ViewModifier {
    var color: Color
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(color.opacity(0.05))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(0.15), lineWidth: 1.5)
            )
    }
}

extension View {
    func tintedBox(color: Color, cornerRadius: CGFloat = 20) -> some View {
        self.modifier(TintedBoxStyle(color: color, cornerRadius: cornerRadius))
    }
}


struct ContentView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var aiManager = AIManager.shared
    @StateObject private var storage = StorageManager.shared
    
    private func getAvgAnxiety() -> Int {
        guard !connectivity.sessionTimeline.isEmpty else { return 0 }
        let total = connectivity.sessionTimeline.reduce(0.0) { $0 + $1.anxietyScore }
        return Int(total / Double(connectivity.sessionTimeline.count))
    }
    
    private func getEnergyScore() -> Int {
        guard !connectivity.sessionTimeline.isEmpty, connectivity.finalDuration > 0 else { return 0 }
        
        var totalBPM: Double = 0.0
        for snapshot in connectivity.sessionTimeline {
            totalBPM += Double(snapshot.bpm)
        }
        
        let avgBPM = totalBPM / Double(connectivity.sessionTimeline.count)
        let normalized = max(0.0, min(100.0, ((avgBPM - 70.0) / 60.0) * 100.0))
        
        return Int(normalized)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            
            VStack(spacing: 15) {
                VStack(spacing: 5) {
                    Text("AuraCoach")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                    Text("Real-Time Biometric Analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(connectivity.anxietyColor)
                        Text("Anxiety Level:")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundColor(.secondary)
                        Text(connectivity.anxietyLevel.uppercased())
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundColor(connectivity.anxietyColor)
                        Spacer()
                        Text("\(Int(connectivity.anxietyScore))%")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(connectivity.anxietyColor)
                                .frame(width: geo.size.width * CGFloat(connectivity.anxietyScore / 100), height: 8)
                                .shadow(color: connectivity.anxietyColor.opacity(0.5), radius: 4)
                                .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.7), value: connectivity.anxietyScore)
                        }
                    }
                    .frame(height: 8)
                }
                .tintedBox(color: connectivity.anxietyColor, cornerRadius: 20)
            }
            .padding(.top, 20)
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                
                VStack(spacing: 15) {
                    Label("Heart Rate", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    HStack(alignment: .bottom, spacing: 2) {
                        Text("\(Int(connectivity.receivedBPM))")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: connectivity.receivedBPM))
                            .animation(.snappy, value: connectivity.receivedBPM)
                        
                        Text("BPM")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .tintedBox(color: .red, cornerRadius: 20)
                
                VStack(spacing: 15) {
                    Label("Agitation", systemImage: "waveform.path.ecg")
                        .font(.headline)
                        .foregroundColor(connectivity.smoothedMovement > 1.5 ? .orange : .green)
                    
                    HStack(alignment: .bottom, spacing: 2) {
                        Text(String(format: "%.1f", connectivity.smoothedMovement))
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .animation(.linear(duration: 0.1), value: connectivity.smoothedMovement)
                        
                        Text("G")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .tintedBox(color: connectivity.smoothedMovement > 1.5 ? .orange : .green, cornerRadius: 20)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Session Records")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack(spacing: 15) {
                    HStack {
                        Image(systemName: "arrow.up.heart.fill")
                            .foregroundColor(.red)
                        Text("Max BPM:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(connectivity.maxBPM))")
                            .font(.title3.bold())
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "figure.walk.motion")
                            .foregroundColor(.orange)
                        Text("Max G:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f G", connectivity.maxMovementRaw))
                            .font(.title3.bold())
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)
            }
            .padding(.top, 10)

            VStack(spacing: 10) {
                
                Toggle(isOn: $connectivity.isHapticEnabled) {
                    Label("Wrist Haptic Feedback", systemImage: "hand.tap.fill")
                        .foregroundColor(connectivity.isHapticEnabled ? .orange : .secondary)
                }
                .tintedBox(color: .orange, cornerRadius: 15)
                
                Toggle(isOn: $connectivity.isVoiceEnabled) {
                    Label("Voice Analysis (WPM)", systemImage: "mic.fill")
                        .foregroundColor(connectivity.isVoiceEnabled ? .blue : .secondary)
                }
                .tintedBox(color: .blue, cornerRadius: 15)
                .disabled(connectivity.isSessionActive)
                .onChange(of: connectivity.isVoiceEnabled) { oldValue, newValue in
                    if newValue { speechManager.requestPermissions() }
                }
                
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(speechManager.isRecording ? .red : .gray)
                        .font(.system(size: 8))
                    
                    Text(speechManager.isRecording ? "Analysis in progress..." : "Microphone off")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(speechManager.currentWPM)) WPM")
                        .bold()
                        .monospacedDigit()
                        .foregroundColor(speechManager.currentWPM > 160 ? .red : .primary)
                }
                .padding(.horizontal)
                .opacity(connectivity.isVoiceEnabled ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: connectivity.isVoiceEnabled)
                .onChange(of: speechManager.currentWPM) { oldValue, newValue in
                    connectivity.currentWPM = newValue
                }
                
                .onChange(of: connectivity.receivedBPM) { oldValue, newValue in
                    if connectivity.isSessionActive && oldValue > 0 && newValue == 0 {
                        if let start = connectivity.sessionStartTime, Date().timeIntervalSince(start) > 5.0 {
                            print("Watch removed! Auto-closing session...")
                            
                            speechManager.stopRecording()
                            connectivity.sendStopCommandToWatch()
                            
                            if connectivity.isVoiceEnabled {
                                connectivity.currentWPM = speechManager.currentWPM
                            }
                            
                            connectivity.finalDuration = Date().timeIntervalSince(start)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                connectivity.showReport = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 15) {
                Text("Apple Watch Remote")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                if !connectivity.isSessionActive {
                    // PULSANTE START
                    Button(action: {
                        connectivity.sendStartCommandToWatch()
                        if connectivity.isVoiceEnabled {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                speechManager.startRecording()
                            }
                        }
                    }) {
                        Label("Start Session", systemImage: "play.fill")
                            .font(.headline.bold())
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .tintedBox(color: .green, cornerRadius: 15)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                } else {
                    Button(action: {
                        connectivity.sendStopCommandToWatch()
                        speechManager.stopRecording()
                        
                        if connectivity.isVoiceEnabled {
                            connectivity.currentWPM = speechManager.currentWPM
                        }
                        
                        if let start = connectivity.sessionStartTime {
                            connectivity.finalDuration = Date().timeIntervalSince(start)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            connectivity.showReport = true
                        }
                    }) {
                        Label("End Session", systemImage: "stop.fill")
                            .font(.headline.bold())
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .tintedBox(color: .red, cornerRadius: 15)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .onAppear {
            connectivity.requestIOSPermissions()
        }
        .sheet(isPresented: $connectivity.showReport, onDismiss: {
            connectivity.resetSession()
            speechManager.resetData()
        }) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Report")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 30)
                    
                    Text("Here is how your session went:")
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        let minutes = Int(connectivity.finalDuration) / 60
                        let seconds = Int(connectivity.finalDuration) % 60
                        let durationString = minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
                        let energyPercent = getEnergyScore()
                        let anxietyAvg = getAvgAnxiety()
                        
                        ReportCard(icon: "timer", color: .cyan, value: durationString, title: "Duration")
                        ReportCard(icon: "figure.walk", color: .blue, value: String(format: "%.0f", connectivity.finalSteps), title: "Steps")
                        ReportCard(icon: "waveform", color: .purple, value: String(format: "%.0f", speechManager.averageWPM), title: "Avg WPM")
                        ReportCard(icon: "bolt.fill", color: .yellow, value: String(format: "%.0f", speechManager.maxWPM), title: "Peak WPM")
                        ReportCard(icon: "arrow.up.heart.fill", color: .red, value: "\(Int(connectivity.maxBPM))", title: "Max BPM")
                        ReportCard(icon: "flame.fill", color: .orange, value: "\(energyPercent)%", title: "Energy")
                        ReportCard(icon: "brain.head.profile", color: .indigo, value: "\(anxietyAvg)%", title: "Avg Stress")
                        ReportCard(icon: "waveform.path.ecg", color: .green, value: String(format: "%.1f", connectivity.maxMovementRaw), title: "Peak Agitation")
                    }
                    .padding()
                    
                    if !connectivity.sessionTimeline.isEmpty {
                        AnxietyChartView(timeline: connectivity.sessionTimeline)
                            .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Anxiety Analysis (AuraCoach AI)")
                            .font(.headline)
                        
                        if aiManager.isGenerating {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 5)
                                Text("AuraCoach is writing the report...")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        } else {
                            Text(aiManager.generatedReport)
                                .font(.body)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .tintedBox(color: .purple, cornerRadius: 15)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)
                    
                    .onAppear {
                        Task {
                            await aiManager.fetchAIReport(
                                maxBPM: connectivity.maxBPM,
                                maxG: connectivity.maxMovementRaw,
                                avgWPM: speechManager.averageWPM,
                                maxWPM: speechManager.maxWPM,
                                calories: connectivity.finalCalories,
                                duration: connectivity.finalDuration,
                                timeline: connectivity.sessionTimeline
                            )
                        }
                    }
                    
                    Button(action: {
                        let newRecord = SessionRecord(
                            id: UUID(),
                            date: connectivity.sessionStartTime ?? Date(),
                            duration: connectivity.finalDuration,
                            maxBPM: connectivity.maxBPM,
                            maxMovementRaw: connectivity.maxMovementRaw,
                            averageWPM: speechManager.averageWPM,
                            maxWPM: speechManager.maxWPM,
                            calories: connectivity.finalCalories,
                            steps: connectivity.finalSteps,
                            timeline: connectivity.sessionTimeline,
                            aiReport: aiManager.generatedReport
                        )
                        
                        storage.saveSession(record: newRecord)
                        
                        connectivity.showReport = false
                        connectivity.resetSession()
                        speechManager.resetData()
                        aiManager.generatedReport = ""
                    }) {
                        Label("Save Report", systemImage: "arrow.down.doc.fill")
                            .font(.headline.bold())
                            .foregroundColor(.indigo)
                            .frame(maxWidth: .infinity)
                            .tintedBox(color: .indigo, cornerRadius: 15)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .presentationDetents([.large])
        }
    }
}

// MARK: - COMPONENTI ESTERNI AGGIORNATI
struct ReportCard: View {
    var icon: String
    var color: Color
    var value: String
    var title: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .tintedBox(color: color, cornerRadius: 15)
    }
}

struct AnxietyChartView: View {
    let timeline: [SessionSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anxiety Trend")
                .font(.headline)
            
            Chart {
                ForEach(timeline, id: \.timeElapsed) { snap in
                    LineMark(
                        x: .value("Time", snap.timeElapsed),
                        y: .value("Anxiety", snap.anxietyScore)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
            }
            .foregroundStyle(
                .linearGradient(
                    colors: [.green, .yellow, .red],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    if let timeSeconds = value.as(TimeInterval.self) {
                        let m = Int(timeSeconds) / 60
                        let s = Int(timeSeconds) % 60
                        AxisValueLabel(String(format: "%02d:%02d", m, s))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    if let score = value.as(Double.self) {
                        AxisValueLabel("\(Int(score))%")
                    }
                }
            }
            .frame(height: 200)
        }
    }
}
