import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        return false
    }
}

// MARK: - Global Appearance
private func configureGlobalAppearance() {
    // Navigation Bar
    let nav = UINavigationBarAppearance()
    nav.configureWithOpaqueBackground()
    nav.backgroundColor = .black
    nav.titleTextAttributes = [
        .foregroundColor: UIColor.white,
        .font: UIFont(name: "Avenir", size: 20)!
    ]
    nav.largeTitleTextAttributes = [
        .foregroundColor: UIColor.white,
        .font: UIFont(name: "Avenir", size: 32)!
    ]
    
    UINavigationBar.appearance().standardAppearance = nav
    UINavigationBar.appearance().scrollEdgeAppearance = nav
    UINavigationBar.appearance().compactAppearance = nav
    UINavigationBar.appearance().tintColor = .white

    // Tab Bar
    let tab = UITabBarAppearance()
    tab.configureWithOpaqueBackground()
    tab.backgroundColor = .black
    tab.stackedLayoutAppearance.selected.iconColor = .white
    tab.inlineLayoutAppearance.selected.iconColor = .white
    tab.compactInlineLayoutAppearance.selected.iconColor = .white
    tab.stackedLayoutAppearance.normal.iconColor = .lightGray
    tab.inlineLayoutAppearance.normal.iconColor = .lightGray
    tab.compactInlineLayoutAppearance.normal.iconColor = .lightGray
    UITabBar.appearance().standardAppearance = tab
    if #available(iOS 15.0, *) {
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
    UITabBar.appearance().tintColor = .white
    UITabBar.appearance().unselectedItemTintColor = .lightGray

    // UILabel (for all UIKit text)
    UILabel.appearance().textColor = .white
}

// MARK: - App
@main
struct BurnerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    @State private var shouldResetApp = false
    @State private var showingVideoSplash = true
    @Environment(\.scenePhase) private var scenePhase

    init() {
        configureGlobalAppearance()

    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(appState.navigationCoordinator)
                    .environmentObject(appState.eventViewModel)
                    .environmentObject(appState.bookmarkManager)
                    .environmentObject(appState.ticketsViewModel)
                    .environmentObject(appState.tagViewModel)
                    .environmentObject(appState.authService)
                    .environmentObject(appState.locationManager)
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
                    .onAppear {
                        appState.loadInitialData()
                        setupResetObserver()
                    }
                    .id(shouldResetApp)
                    .tint(.white)
                    .foregroundColor(.white)
                    .preferredColorScheme(.dark)

                if appState.showingBurnerLockScreen {
                    BurnerModeLockScreen()
                        .environmentObject(appState)
                        .transition(.opacity)
                        .zIndex(1000)
                }

                if appState.showingError {
                    CustomAlertView(
                        title: "Error",
                        description: appState.errorMessage ?? "An error occurred",
                        primaryAction: { appState.clearError() },
                        primaryActionTitle: "OK",
                        customContent: EmptyView()
                    )
                    .transition(.opacity)
                    .zIndex(1001)
                }
                
                // Video splash - separate from error block
                if showingVideoSplash {
                    VideoSplashView(videoName: "splash", loop: false) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showingVideoSplash = false
                        }
                    }
                    .zIndex(2000)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState.showingBurnerLockScreen)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            configureGlobalAppearance()
        }
    }

    // MARK: - URL Handling
    private func handleIncomingURL(_ url: URL) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔗 INCOMING URL")
        print("   Full URL: \(url.absoluteString)")
        print("   Scheme: \(url.scheme ?? "nil")")
        print("   Host: \(url.host ?? "nil")")
        print("   Path: \(url.path)")
        print("   Path Components: \(url.pathComponents)")
        print("   Last Component: \(url.lastPathComponent)")

        // 1) Google Sign-In first
        if GIDSignIn.sharedInstance.handle(url) {
            print("✅ Handled by Google Sign-In")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        // 2) Check for Firebase passwordless sign-in link
        if appState.passwordlessAuthHandler.handleSignInLink(url: url) {
            print("✅ Handled by Passwordless Auth")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        // 3) Our custom scheme(s)
        guard url.scheme?.lowercased() == "burner" else {
            print("⚠️ Not a burner:// URL, ignoring")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        if let deeplink = parseBurnerDeepLink(url) {
            switch deeplink {
            case .event(let id):
                print("✅ Parsed as event deep link")
                print("   Event ID: \(id)")
                print("   ID length: \(id.count)")
                navigateToEvent(eventId: id)
            case .auth(let link):
                print("✅ Parsed as auth deep link")
                print("   Link: \(link)")
                // Handle the passwordless auth link
                if let linkUrl = URL(string: link) {
                    _ = appState.passwordlessAuthHandler.handleSignInLink(url: linkUrl)
                }
            }
        } else {
            print("❌ Failed to parse deep link")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }

    private enum BurnerDeepLink {
        case event(String)
        case auth(String)
    }

    private func parseBurnerDeepLink(_ url: URL) -> BurnerDeepLink? {
        print("🔍 Parsing deep link...")

        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("❌ Failed to create URLComponents")
            return nil
        }

        // Case A: burner://auth?link=<url> (passwordless auth)
        if comps.host == "auth" {
            print("   Detected auth format: burner://auth?link=<url>")
            if let linkParam = comps.queryItems?.first(where: { $0.name == "link" })?.value {
                print("   Extracted link: '\(linkParam)'")
                return .auth(linkParam)
            }
            print("   No link parameter found")
            return nil
        }

        // Case B: burner://event/12345 (host-based)
        if comps.host == "event" {
            print("   Detected host-based format: burner://event/ID")
            let id = url.lastPathComponent
            print("   Extracted ID: '\(id)'")
            return id.isEmpty ? nil : .event(id)
        }

        // Case C: burner:///event/12345 (path-based)
        let parts = url.pathComponents.filter { $0 != "/" }
        print("   Path components (filtered): \(parts)")

        if parts.count >= 2, parts[0] == "event" {
            print("   Detected path-based format: burner:///event/ID")
            let id = parts[1]
            print("   Extracted ID: '\(id)'")
            return id.isEmpty ? nil : .event(id)
        }

        print("   No valid format detected")
        return nil
    }
    
    private func navigateToEvent(eventId: String) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚀 DEEP LINK NAVIGATION")
        print("   Event ID: \(eventId)")
        print("   Current tab: \(appState.navigationCoordinator.selectedTab)")

        // Use NavigationCoordinator for deep linking
        appState.navigationCoordinator.handleDeepLink(eventId: eventId)
        print("✅ Handled deep link via NavigationCoordinator")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    private func setupResetObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ResetOnboarding"),
            object: nil,
            queue: .main
        ) { _ in
            shouldResetApp.toggle()
        }
    }
}
