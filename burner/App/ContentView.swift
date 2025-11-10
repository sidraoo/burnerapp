import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var burnerManager = BurnerModeManager()
    @State private var showLocationPrompt = false
    @AppStorage("hasSeenLocationPrompt") private var hasSeenLocationPrompt = false

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
            
            // Check if we should show location prompt
            checkLocationPrompt()
        }
        .onChange(of: onboardingManager.shouldShowOnboarding) { _, isShowing in
            // Show location prompt after onboarding is complete
            if !isShowing {
                checkLocationPrompt()
            }
        }
        .onChange(of: appState.locationManager.hasLocationPreference) { _, hasPreference in
            // Hide prompt when location preference is set
            if hasPreference {
                showLocationPrompt = false
                hasSeenLocationPrompt = true
            }
        }
    }
    
    private func checkLocationPrompt() {
        // Show location prompt if:
        // 1. Onboarding is complete
        // 2. User hasn't set location preference
        // 3. Not already showing the prompt
        if !onboardingManager.shouldShowOnboarding &&
           !appState.locationManager.hasLocationPreference &&
           !showLocationPrompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showLocationPrompt = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
