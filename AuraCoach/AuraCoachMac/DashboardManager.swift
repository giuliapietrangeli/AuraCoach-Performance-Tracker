import Foundation
import FirebaseFirestore
import SwiftUI
internal import Combine

@MainActor
class DashboardManager: ObservableObject {
    @Published var downloadedSessions: [SessionRecord] = []
    @Published var isLoading = false
    @Published var lastUpdate = Date()
    
    private var listener: ListenerRegistration?
    
    init() {}
    
    func startListening() {
        let db = Firestore.firestore()
        
        guard listener == nil else { return }
        
        isLoading = true
        print("Dashboard: Listening for updates...")
        
        listener = db.collection("sessions")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.isLoading = false
                    if let error = error {
                        print("Sync Error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    var tempSessions: [SessionRecord] = []
                    for doc in documents {
                        if let jsonData = try? JSONSerialization.data(withJSONObject: doc.data(), options: []),
                           let session = try? JSONDecoder().decode(SessionRecord.self, from: jsonData) {
                            tempSessions.append(session)
                        }
                    }
                    
                    self.downloadedSessions = tempSessions.sorted { $0.date > $1.date }
                    self.lastUpdate = Date()
                    print("Dashboard updated: \(tempSessions.count) sessions.")
                }
            }
    }
    
    deinit {
        listener?.remove()
    }
}
