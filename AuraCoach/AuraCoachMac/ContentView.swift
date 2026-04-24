import SwiftUI
import Charts
import FirebaseFirestore

struct TintedBoxStyle: ViewModifier {
    var color: Color
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(25)
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

enum NavigationTarget: Hashable {
    case dashboard
    case achievements
    case session(UUID)
}

struct ContentView: View {
    @StateObject private var manager = DashboardManager()
    @State private var selection: NavigationTarget? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                Section("General") {
                    NavigationLink(value: NavigationTarget.dashboard) {
                        Label("Personal Dashboard", systemImage: "heart.text.square.fill")
                            .foregroundColor(selection == .dashboard ? .white : .pink)
                    }
                    NavigationLink(value: NavigationTarget.achievements) {
                        Label("Trophies & Achievements", systemImage: "trophy.fill")
                            .foregroundColor(selection == .achievements ? .white : .yellow)
                    }
                }
                
                Section("Session History") {
                    ForEach(Array(manager.downloadedSessions.enumerated()), id: \.element.id) { index, session in
                        NavigationLink(value: NavigationTarget.session(session.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Calcoliamo il numero esatto (La più vecchia è la S1)
                                let sessionNumber = manager.downloadedSessions.count - index
                                
                                Text("S\(sessionNumber) - \(session.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.headline)
                                
                                let anxiety = session.averageAnxiety
                                let statusColor: Color = anxiety < 35 ? .green : (anxiety < 65 ? .orange : .red)
                                
                                Text("Anxiety: \(Int(anxiety))%")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(selection == .session(session.id) ? .white : statusColor)
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) { deleteSession(session) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("AuraCoach")
            .frame(minWidth: 250)
            
        } detail: {
            switch selection {
            case .dashboard, .none:
                MainDashboardView(sessions: manager.downloadedSessions, selection: $selection)
            case .achievements:
                AchievementsView(sessions: manager.downloadedSessions)
            case .session(let id):
                if let session = manager.downloadedSessions.first(where: { $0.id == id }) {
                    SessionDetailView(session: session, allSessions: manager.downloadedSessions).id(id)
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear { manager.startListening() }
    }
    
    func deleteSession(_ session: SessionRecord) {
        Firestore.firestore().collection("sessions").document(session.id.uuidString).delete { _ in }
    }
}

// MARK: - TROPHIES & ACHIEVEMENTS
struct AchievementsView: View {
    let sessions: [SessionRecord]
    
    var achievements: [(title: String, desc: String, icon: String, color: Color, unlocked: Bool)] {
        [
            ("Icebreaker", "Complete your very first session.", "mic.fill", .blue, !sessions.isEmpty),
            ("Consistent Speaker", "Complete at least 5 sessions.", "star.fill", .orange, sessions.count >= 5),
            ("Stage Veteran", "Reach the milestone of 10 total sessions.", "crown.fill", .yellow, sessions.count >= 10),
            ("Zen Master", "Finish a session with an average anxiety below 30%.", "leaf.fill", .green, sessions.contains { $0.averageAnxiety < 30 }),
            ("Ice Heart", "Keep max heart rate below 90 BPM in a session.", "snowflake", .cyan, sessions.contains { $0.maxBPM < 90 }),
            ("Marathoner", "Speak continuously for over 10 minutes.", "timer", .purple, sessions.contains { $0.duration > 600 }),
            ("Machine Gun", "Reach a pace peak of over 180 WPM.", "bolt.fill", .red, sessions.contains { $0.maxWPM > 180 }),
            ("Dynamic Stage", "Take over 100 steps during a single presentation.", "figure.walk", .mint, sessions.contains { $0.steps > 100 }),
            ("Pure Energy", "Reach a heart rate of over 130 BPM (Enthusiasm!).", "flame.fill", .orange, sessions.contains { $0.maxBPM > 130 }),
            ("Survivor", "Complete a session facing an anxiety peak above 80%.", "shield.fill", .indigo, sessions.contains { s in s.timeline.contains { $0.anxietyScore > 80 } }),
            ("Elevator Pitch", "Deliver a punchy presentation under 3 minutes.", "arrow.up.forward.square.fill", .teal, sessions.contains { $0.duration > 30 && $0.duration <= 180 }),
            ("The Metronome", "Maintain a perfect average pace between 130 and 160 WPM.", "metronome.fill", .pink, sessions.contains { $0.averageWPM >= 130 && $0.averageWPM <= 160 })
        ]
    }
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Trophy Board")
                        .font(.system(size: 40, weight: .bold))
                    Text("Unlock these secret achievements to master the art of public speaking.")
                        .font(.title2).foregroundColor(.secondary)
                }
                
                LazyVGrid(columns: columns, spacing: 25) {
                    ForEach(0..<achievements.count, id: \.self) { index in
                        let ach = achievements[index]
                        AchievementCard(title: ach.title, description: ach.desc, icon: ach.icon, color: ach.color, isUnlocked: ach.unlocked)
                    }
                }
            }
            .padding(50)
        }
    }
}

struct AchievementCard: View {
    let title: String; let description: String; let icon: String; let color: Color; let isUnlocked: Bool
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: isUnlocked ? icon : "lock.fill")
                    .font(.system(size: 35, weight: .bold))
                    .foregroundColor(isUnlocked ? color : .gray.opacity(0.5))
            }
            
            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(height: 50, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity)
        .tintedBox(color: isUnlocked ? color : .gray, cornerRadius: 25)
        .shadow(color: isUnlocked ? color.opacity(0.6) : .clear, radius: 15, x: 0, y: 0)
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}

// MARK: - MAIN DASHBOARD
struct MainDashboardView: View {
    let sessions: [SessionRecord]
    @Binding var selection: NavigationTarget?
    
    var chronologicalSessions: [SessionRecord] {
        Array(sessions.prefix(10).reversed())
    }
    
    let kpiColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 4)
    let chartColumns = Array(repeating: GridItem(.flexible(), spacing: 30), count: 3)
    
    var globalAvgWPM: Int { sessions.isEmpty ? 0 : Int(sessions.reduce(0.0) { $0 + $1.averageWPM } / Double(sessions.count)) }
    var globalAvgAnxiety: Int { sessions.isEmpty ? 0 : Int(sessions.reduce(0.0) { $0 + $1.averageAnxiety } / Double(sessions.count)) }
    var globalAvgBPM: Int { sessions.isEmpty ? 0 : Int(sessions.reduce(0.0) { $0 + $1.maxBPM } / Double(sessions.count)) }
    var globalAvgSteps: Int { sessions.isEmpty ? 0 : Int(sessions.reduce(0.0) { $0 + $1.steps } / Double(sessions.count)) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome back")
                        .font(.system(size: 40, weight: .bold))
                    Text("Here is the complete analysis of your historical performances.")
                        .font(.title2).foregroundColor(.secondary)
                }
                
                ImprovementInsightCard(sessions: sessions)
                
                LazyVGrid(columns: kpiColumns, spacing: 20) {
                    TrendCard(title: "Total Sessions", value: "\(sessions.count)", unit: "", icon: "mic.fill", color: .pink)
                    TrendCard(title: "Avg Steps", value: "\(globalAvgSteps)", unit: "👣", icon: "figure.walk", color: .green)
                    TrendCard(title: "Avg Pace", value: "\(globalAvgWPM)", unit: "WPM", icon: "waveform", color: .purple)
                    TrendCard(title: "Avg Stress", value: "\(globalAvgAnxiety)", unit: "%", icon: "brain.head.profile", color: .indigo)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Recent Trends (Click on charts to open session)")
                        .font(.title2).bold()
                    
                    LazyVGrid(columns: chartColumns, spacing: 30) {
                        TrendLineChart(title: "Anxiety Trend", sessions: chronologicalSessions, totalCount: sessions.count, keyPath: \.averageAnxiety, color: .blue, unit: "%", range: 0...100, selection: $selection)
                        TrendLineChart(title: "Max Heart Rate Trend", sessions: chronologicalSessions, totalCount: sessions.count, keyPath: \.maxBPM, color: .red, unit: "BPM", range: 0...200, selection: $selection)
                        TrendLineChart(title: "Avg Pace (WPM)", sessions: chronologicalSessions, totalCount: sessions.count, keyPath: \.averageWPM, color: .purple, unit: "WPM", range: 0...300, selection: $selection)
                        
                        TrendLineChart(title: "Pace Peak (Max WPM)", sessions: chronologicalSessions, totalCount: sessions.count, keyPath: \.maxWPM, color: .yellow, unit: "WPM", range: 0...400, selection: $selection)
                        TrendLineChart(title: "Movement & Presence (Steps)", sessions: chronologicalSessions, totalCount: sessions.count, keyPath: \.steps, color: .green, unit: "👣", range: 0...200, selection: $selection)
                        DurationBarChart(title: "Session Duration", sessions: chronologicalSessions, totalCount: sessions.count, color: .orange, selection: $selection)
                    }
                }
                
                RecordsBoardView(sessions: sessions)
                
            }
            .padding(50)
        }
    }
}

// MARK: - LINE CHARTS
struct TrendLineChart: View {
    let title: String
    let sessions: [SessionRecord]
    let totalCount: Int
    let keyPath: KeyPath<SessionRecord, Double>
    let color: Color
    let unit: String
    let range: ClosedRange<Double>
    @Binding var selection: NavigationTarget?
    
    @State private var hoveredLabel: String?
    
    var sessionLabels: [String] {
        Array(sessions.enumerated()).map { "S\(totalCount - sessions.count + $0.offset + 1)" }
    }
    
    func getSession(for label: String) -> SessionRecord? {
        guard let index = sessionLabels.firstIndex(of: label) else { return nil }
        return sessions[index]
    }
    
    var body: some View {
        let dataMax = sessions.map { $0[keyPath: keyPath] }.max() ?? 0
        let dynamicUpperBound = max(range.upperBound, dataMax * 1.15)
        
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.headline).foregroundColor(.secondary)
            Chart {
                ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                    let label = sessionLabels[index]
                    let isHovered = hoveredLabel == label
                    
                    LineMark(
                        x: .value("Session", label),
                        y: .value(unit, session[keyPath: keyPath])
                    )
                    .foregroundStyle(color)
                    .symbol {
                        Circle()
                            .fill(isHovered ? .white : color)
                            .stroke(color, lineWidth: isHovered ? 3 : 0)
                            .frame(width: isHovered ? 14 : 6, height: isHovered ? 14 : 6)
                            .shadow(radius: isHovered ? 3 : 0)
                    }
                    .interpolationMethod(.monotone)
                    
                    AreaMark(
                        x: .value("Session", label),
                        y: .value(unit, session[keyPath: keyPath])
                    )
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                }
                
                if let hoveredLabel = hoveredLabel, let session = getSession(for: hoveredLabel) {
                    RuleMark(x: .value("Selected", hoveredLabel))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(color.opacity(0.5))
                        .annotation(position: .top) {
                            VStack(spacing: 4) {
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).bold()
                                    .foregroundColor(.primary)
                                Text("Click to open")
                                    .font(.caption2)
                                    .foregroundColor(color)
                            }
                            .padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 3)
                        }
                }
            }
            .frame(height: 200)
            .chartYScale(domain: range.lowerBound...dynamicUpperBound)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .clipped()
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let xValue = proxy.value(atX: location.x, as: String.self) {
                                    hoveredLabel = xValue
                                }
                            case .ended:
                                hoveredLabel = nil
                            }
                        }
                        .onTapGesture { location in
                            if let xValue = proxy.value(atX: location.x, as: String.self),
                               let session = getSession(for: xValue) {
                                selection = .session(session.id)
                            }
                        }
                }
            }
        }
        .padding(25)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - DURATION BAR CHART
struct DurationBarChart: View {
    let title: String
    let sessions: [SessionRecord]
    let totalCount: Int
    let color: Color
    @Binding var selection: NavigationTarget?
    
    @State private var hoveredLabel: String?
    
    var sessionLabels: [String] {
        Array(sessions.enumerated()).map { "S\(totalCount - sessions.count + $0.offset + 1)" }
    }
    
    func getSession(for label: String) -> SessionRecord? {
        guard let index = sessionLabels.firstIndex(of: label) else { return nil }
        return sessions[index]
    }
    
    var body: some View {
        let dataMax = sessions.map { $0.duration / 60.0 }.max() ?? 0
        let dynamicUpperBound = max(5.0, dataMax * 1.15)
        
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.headline).foregroundColor(.secondary)
            
            Chart {
                ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                    let label = sessionLabels[index]
                    let isHovered = hoveredLabel == label
                    
                    BarMark(
                        x: .value("Session", label),
                        y: .value("Minutes", session.duration / 60.0)
                    )
                    .foregroundStyle(isHovered ? color.opacity(0.5).gradient : color.gradient)
                    .cornerRadius(6)
                }
                
                if let hoveredLabel = hoveredLabel, let session = getSession(for: hoveredLabel) {
                    RuleMark(x: .value("Selected", hoveredLabel))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(color.opacity(0.5))
                        .annotation(position: .top) {
                            VStack(spacing: 4) {
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).bold()
                                    .foregroundColor(.primary)
                                Text("Click to open")
                                    .font(.caption2)
                                    .foregroundColor(color)
                            }
                            .padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 3)
                        }
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 0...dynamicUpperBound)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .clipped()
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let xValue = proxy.value(atX: location.x, as: String.self) {
                                    hoveredLabel = xValue
                                }
                            case .ended:
                                hoveredLabel = nil
                            }
                        }
                        .onTapGesture { location in
                            if let xValue = proxy.value(atX: location.x, as: String.self),
                               let session = getSession(for: xValue) {
                                selection = .session(session.id)
                            }
                        }
                }
            }
        }
        .padding(25)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - OTHER COMPONENTS
struct RecordsBoardView: View {
    let sessions: [SessionRecord]
    
    var longestSession: String {
        guard let maxS = sessions.max(by: { $0.duration < $1.duration }) else { return "-" }
        let m = Int(maxS.duration) / 60
        let s = Int(maxS.duration) % 60
        return "\(m)m \(s)s"
    }
    
    var calmestSession: String {
        guard let minS = sessions.min(by: { $0.averageAnxiety < $1.averageAnxiety }) else { return "-" }
        return "\(Int(minS.averageAnxiety))%"
    }
    
    var maxBPMRecord: String {
        guard let maxS = sessions.max(by: { $0.maxBPM < $1.maxBPM }) else { return "-" }
        return "\(Int(maxS.maxBPM)) BPM"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Records").font(.title2).bold()
            
            HStack(spacing: 20) {
                RecordBadge(title: "Longest Session", value: longestSession, icon: "timer", color: .orange)
                RecordBadge(title: "Best Anxiety Control", value: calmestSession, icon: "leaf.fill", color: .green)
                RecordBadge(title: "Energy Peak (Max BPM)", value: maxBPMRecord, icon: "flame.fill", color: .red)
            }
        }
        .padding(.top, 20)
    }
}

struct RecordBadge: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 50, height: 50)
                Image(systemName: icon).font(.title3).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).bold().foregroundColor(.secondary)
                Text(value).font(.title3).bold()
            }
            Spacer()
        }
        .tintedBox(color: color, cornerRadius: 20)
    }
}

struct ImprovementInsightCard: View {
    let sessions: [SessionRecord]
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Personal AI Insight", systemImage: "sparkles")
                .font(.headline).foregroundColor(.purple)
            
            if sessions.count >= 2 {
                let last = sessions[0].averageAnxiety
                let prev = sessions[1].averageAnxiety
                let diff = prev - last
                
                Text(last <= prev ? "You are improving your emotional control!" : "Stress peak detected.")
                    .font(.system(size: 28, weight: .bold))
                
                Text(last <= prev ? "Anxiety reduced by \(Int(abs(diff)))% compared to last time. Keep it up." : "You were a bit more tense this time (\(Int(abs(diff)))% higher). Take a deep breath before starting.")
                    .font(.subheadline).foregroundColor(.secondary)
            } else {
                Text("Processing data")
                    .font(.system(size: 28, weight: .bold))
                Text("Complete at least 2 sessions to unlock personalized advice.")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedBox(color: .purple, cornerRadius: 25)
    }
}

struct TrendCard: View {
    let title: String; let value: String; let unit: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: icon).font(.title).foregroundColor(color)
            Text(title).font(.headline).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(value).font(.system(size: 40, weight: .bold))
                Text(unit).font(.title3).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedBox(color: color, cornerRadius: 20)
    }
}

extension SessionRecord {
    var averageAnxiety: Double {
        guard !timeline.isEmpty else { return 0.0 }
        return timeline.reduce(0.0) { $0 + $1.anxietyScore } / Double(timeline.count)
    }
}

// MARK: - SINGLE SESSION DETAIL VIEW
struct SessionDetailView: View {
    let session: SessionRecord
    let allSessions: [SessionRecord]
    
    var formattedDuration: String {
        let m = Int(session.duration) / 60
        let s = Int(session.duration) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
    
    var energyScore: Int {
        guard !session.timeline.isEmpty, session.duration > 0 else { return 0 }
        let totalBPM = session.timeline.reduce(0.0) { $0 + Double($1.bpm) }
        let avgBPM = totalBPM / Double(session.timeline.count)
        let normalized = max(0.0, min(100.0, ((avgBPM - 70.0) / 60.0) * 100.0))
        return Int(normalized)
    }
    
    var maxAnxietyMoment: String {
        guard let peak = session.timeline.max(by: { $0.anxietyScore < $1.anxietyScore }) else { return "-" }
        let m = Int(peak.timeElapsed) / 60
        let s = Int(peak.timeElapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    var maxBPMMoment: String {
        guard let peak = session.timeline.max(by: { $0.bpm < $1.bpm }) else { return "-" }
        let m = Int(peak.timeElapsed) / 60
        let s = Int(peak.timeElapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    var globalAvgBPM: Int {
        allSessions.isEmpty ? 0 : Int(allSessions.reduce(0.0) { $0 + $1.maxBPM } / Double(allSessions.count))
    }
    
    let cardColumns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.date.formatted(date: .complete, time: .shortened)).font(.title).bold()
                        Text("Biometric Session Detail").foregroundColor(.secondary)
                    }
                    Spacer()
                    PerformanceBadge(anxiety: session.averageAnxiety)
                }
                
                LazyVGrid(columns: cardColumns, spacing: 20) {
                    DetailStatCard(title: "Duration", value: formattedDuration, unit: "", icon: "timer", color: .cyan)
                    DetailStatCard(title: "Total Steps", value: "\(Int(session.steps))", unit: "👣", icon: "figure.walk", color: .blue)
                    DetailStatCard(title: "Energy Output", value: "\(energyScore)", unit: "%", icon: "flame.fill", color: .orange)
                    
                    let isPaceGood = session.averageWPM >= 130 && session.averageWPM <= 160
                    DetailStatCard(title: "Avg Pace", value: "\(Int(session.averageWPM))", unit: "WPM", icon: "waveform", color: isPaceGood ? .green : .orange, subtitle: isPaceGood ? "Perfect Pace" : "Out of ideal range")
                    
                    DetailStatCard(title: "Vocal Peak", value: "\(Int(session.maxWPM))", unit: "WPM", icon: "bolt.fill", color: .yellow)
                    
                    let bpmDiff = Int(session.maxBPM) - globalAvgBPM
                    let bpmSubtitle = bpmDiff > 0 ? "📈 +\(bpmDiff) vs your avg" : "📉 \(bpmDiff) vs your avg"
                    DetailStatCard(title: "Max BPM", value: "\(Int(session.maxBPM))", unit: "BPM", icon: "heart.fill", color: .red, subtitle: bpmSubtitle)
                }
                
                AnxietyChartView(timeline: session.timeline)
                
                BPMChartView(timeline: session.timeline)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Key Moments").font(.title2).bold()
                    HStack(spacing: 20) {
                        HighlightBadge(icon: "brain.head.profile", title: "Anxiety Peak (\(Int(session.timeline.map{$0.anxietyScore}.max() ?? 0))%)", time: maxAnxietyMoment, color: .blue)
                        HighlightBadge(icon: "heart.fill", title: "Heart Rate Peak (\(Int(session.maxBPM)) BPM)", time: maxBPMMoment, color: .red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text("AuraCoach AI Feedback")
                            .font(.title2)
                            .bold()
                    }
                    
                    Text(session.aiReport.isEmpty ? "No AI report generated for this session." : session.aiReport)
                        .font(.body)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tintedBox(color: .purple, cornerRadius: 25)
                }
            }
            .padding(50)
        }
    }
}

struct DetailStatCard: View {
    let title: String; let value: String; let unit: String; let icon: String; let color: Color
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline).foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 32, weight: .bold))
                Text(unit).foregroundColor(.secondary).bold()
            }
            if let subtitle = subtitle {
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedBox(color: color, cornerRadius: 20)
    }
}

struct HighlightBadge: View {
    let icon: String; let title: String; let time: String; let color: Color
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 45, height: 45)
                Image(systemName: icon).foregroundColor(color).font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text("Detected at minute \(time)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .tintedBox(color: color, cornerRadius: 15)
    }
}

struct PerformanceBadge: View {
    let anxiety: Double
    var info: (String, Color, String) {
        if anxiety < 35 { return ("EXCELLENT", .green, "checkmark.seal.fill") }
        if anxiety < 65 { return ("GOOD", .orange, "exclamationmark.triangle.fill") }
        return ("HIGH STRESS", .red, "bolt.fill")
    }
    var body: some View {
        HStack {
            Image(systemName: info.2)
            Text(info.0).bold()
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(info.1.opacity(0.15)).foregroundColor(info.1).cornerRadius(20)
    }
}

struct AnxietyChartView: View {
    let timeline: [SessionSnapshot]
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Live Stress Analysis").font(.headline)
            Chart {
                ForEach(timeline, id: \.timeElapsed) { point in
                    LineMark(x: .value("Time", point.timeElapsed), y: .value("Anxiety %", point.anxietyScore))
                        .foregroundStyle(.blue).interpolationMethod(.monotone)
                        .symbol { Circle().fill(.blue).frame(width: 6, height: 6) }
                    AreaMark(x: .value("Time", point.timeElapsed), y: .value("Anxiety %", point.anxietyScore))
                        .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
            }
            .frame(height: 250).chartYScale(domain: 0...100)
            .clipped()
        }
        .padding(25)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct BPMChartView: View {
    let timeline: [SessionSnapshot]
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Live Heart Rate").font(.headline)
            Chart {
                ForEach(timeline, id: \.timeElapsed) { point in
                    LineMark(x: .value("Time", point.timeElapsed), y: .value("BPM", point.bpm))
                        .foregroundStyle(.red).interpolationMethod(.monotone)
                        .symbol { Circle().fill(.red).frame(width: 6, height: 6) }
                    AreaMark(x: .value("Time", point.timeElapsed), y: .value("BPM", point.bpm))
                        .foregroundStyle(LinearGradient(colors: [.red.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
            }
            .frame(height: 250).chartYScale(domain: 40...200)
            .clipped()
        }
        .padding(25)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}
