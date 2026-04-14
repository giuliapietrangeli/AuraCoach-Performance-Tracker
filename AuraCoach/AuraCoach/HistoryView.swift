import SwiftUI

struct HistoryView: View {
    @StateObject private var storage = StorageManager.shared
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
    
    var body: some View {
        NavigationView {
            Group {
                if storage.savedSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "cloud")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No sessions in the Cloud")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Record your first presentation to sync it here and on your Mac.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(storage.savedSessions) { session in
                            
                            let maxAnxiety = session.timeline.map { $0.anxietyScore }.max() ?? 0.0
                            let statusColor: Color = maxAnxiety >= 70 ? .red : (maxAnxiety >= 30 ? .orange : .green)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(dateFormatter.string(from: session.date))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Label("\(Int(session.maxBPM)) BPM", systemImage: "heart.fill")
                                        .foregroundColor(.red)
                                        .font(.caption.bold())
                                    
                                    Spacer()
                                    
                                    Label("\(Int(maxAnxiety))% Anxiety", systemImage: "brain.head.profile")
                                        .foregroundColor(statusColor)
                                        .font(.caption.bold())
                                    
                                    Spacer()
                                    
                                    let m = Int(session.duration) / 60
                                    let s = Int(session.duration) % 60
                                    Label(m > 0 ? "\(m)m \(s)s" : "\(s)s", systemImage: "timer")
                                        .foregroundColor(.cyan)
                                        .font(.caption.bold())
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 15)
                            .background(statusColor.opacity(0.05))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(statusColor.opacity(0.2), lineWidth: 1.5)
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let sessionToDelete = storage.savedSessions[index]
                                storage.deleteSession(id: sessionToDelete.id)
                            }
                        }
                    }
                    .listStyle(.plain) 
                }
            }
            .navigationTitle("Cloud History")
        }
    }
}
