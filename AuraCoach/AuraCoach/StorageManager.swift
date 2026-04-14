import Foundation
import FirebaseFirestore
import Combine

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    @Published var savedSessions: [SessionRecord] = []
    
    private let db = Firestore.firestore()
    
    init() {
        startListeningToCloud()
    }
    
    private func startListeningToCloud() {
        db.collection("sessions").addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Errore fetch Firebase: \(error?.localizedDescription ?? "Sconosciuto")")
                return
            }
            
            var fetchedSessions: [SessionRecord] = []
            
            for doc in documents {
                do {
                    let data = try JSONSerialization.data(withJSONObject: doc.data(), options: [])
                    let record = try JSONDecoder().decode(SessionRecord.self, from: data)
                    fetchedSessions.append(record)
                } catch {
                    print("Errore decodifica sessione \(doc.documentID): \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.savedSessions = fetchedSessions.sorted(by: { $0.date > $1.date })
            }
        }
    }
    
    func saveSession(record: SessionRecord) {
        do {
            let data = try JSONEncoder().encode(record)
            guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else { return }
            
            db.collection("sessions").document(record.id.uuidString).setData(dictionary) { error in
                if let error = error {
                    print("Errore caricamento Firebase: \(error.localizedDescription)")
                } else {
                    print("Sessione attivata su Firebase con successo!")
                }
            }
        } catch {
            print("Errore di preparazione per Firebase: \(error.localizedDescription)")
        }
    }
    
    func deleteSession(id: UUID) {
        db.collection("sessions").document(id.uuidString).delete { error in
            if let error = error {
                print("Errore durante l'eliminazione: \(error.localizedDescription)")
            } else {
                print("Sessione eliminata dal Cloud!")
            }
        }
    }
}
