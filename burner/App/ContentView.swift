import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var burnerManager = BurnerModeManager()
    @State private var showLocationPrompt = false

    var body: some View {
        ZStack {
            // Main app content
            MainTabView()

            // Onboarding overlay (shown on first launch)
            if onboardingManager.shouldShowOnboarding {
                OnboardingFlowView(
                    onboardingManager: onboardingManager,
                    burnerManager: burnerManager
                )
                .transition(.opacity)
                .zIndex(100)
            }
            
            // Location prompt modal (shown after onboarding if no location set)
            if showLocationPrompt {
                LocationPromptModal {
                    withAnimation {
                        showLocationPrompt = false
                    }
                }
                .transition(.move(edge: .bottom))
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingManager.shouldShowOnboarding)
        .animation(.easeInOut(duration: 0.3), value: showLocationPrompt)
        .onAppear {
            // Load initial data when the app starts
            appState.loadInitialData()
        }
        .onChange(of: onboardingManager.shouldShowOnboarding) { _, isShowing in
            // Show location prompt after onboarding is complete
            if !isShowing && !appState.locationManager.hasLocationPreference {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showLocationPrompt = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
