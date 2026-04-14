import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        FirebaseApp.configure()
        print("Firebase inizializzato con successo!")
        
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("Errore login: \(error.localizedDescription)")
            } else if let user = authResult?.user {
                print("Login riuscito! Il tuo ID è: \(user.uid)")
            }
        }
        
        return true
    }
}

@main
struct AuraCoachApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView(showSplash: $showSplash)
                } else {
                    TabView {
                        ContentView()
                            .tabItem { Label("Registra", systemImage: "record.circle") }
                        
                        HistoryView()
                            .tabItem { Label("Storico", systemImage: "list.bullet.rectangle.portrait") }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - SPLASH SCREEN ANIMATA
struct SplashScreenView: View {
    @Binding var showSplash: Bool
    
    @State private var opacity = 0.0
    @State private var scale = 0.85
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text("AuraCoach")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
            }
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    self.opacity = 1.0
                    self.scale = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeIn(duration: 0.4)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
