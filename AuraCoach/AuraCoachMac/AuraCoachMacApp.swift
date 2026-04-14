import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct AuraCoachMacApp: App {
    
    init() {
        FirebaseApp.configure()
        print("Firebase configured at App launch!")
        
        Auth.auth().signInAnonymously { _, _ in
            print("Login successful.")
        }
    }

    var body: some Scene {
        WindowGroup("AuraCoach") {
            ContentView()
        }
    }
}
