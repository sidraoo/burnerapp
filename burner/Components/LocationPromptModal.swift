import SwiftUI
import CoreLocation

struct LocationPromptModal: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingManualEntry = false
    @State private var cityInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't dismiss on background tap
                }
            
            VStack {
                Spacer()
                
                // Modal content
                VStack(spacing: 0) {
                    // Handle bar
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    if showingManualEntry {
                        manualEntryView
                    } else {
                        defaultView
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 0)
            }
        }
        .transition(.move(edge: .bottom))
    }
    
    // MARK: - Default View
    
    private var defaultView: some View {
        VStack(spacing: 24) {
            // Title
            VStack(spacing: 8) {
                Text("Find Events Near You")
                    .appTitle()
                    .foregroundColor(.white)
                
                Text("Choose how you'd like to discover nearby events")
                    .appBody()
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            // Options
            VStack(spacing: 12) {
                // Use Current Location Button
                Button {
                    requestLocationPermission()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Current Location")
                                .appSubheading()
                                .foregroundColor(.white)
                            
                            Text("Automatically find events near you")
                                .appCaption()
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.appIcon)
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Manual Entry Button
                Button {
                    withAnimation {
                        showingManualEntry = true
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enter City or Town")
                                .appSubheading()
                                .foregroundColor(.white)
                            
                            Text("Manually type your UK location")
                                .appCaption()
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.appIcon)
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            
            // Error message
            if let error = locationManager.errorMessage {
                Text(error)
                    .appCaption()
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Skip button
            Button {
                onDismiss()
            } label: {
                Text("Skip for Now")
                    .appBody()
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Manual Entry View
    
    private var manualEntryView: some View {
        VStack(spacing: 24) {
            // Title
            VStack(spacing: 8) {
                Text("Enter Your Location")
                    .appTitle()
                    .foregroundColor(.white)
                
                Text("Type the name of your city or town in the UK")
                    .appBody()
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                TextField("e.g., London, Manchester, Edinburgh", text: $cityInput)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
                    .autocapitalization(.words)
                    .disabled(isLoading)
                
                if let error = errorMessage {
                    Text(error)
                        .appCaption()
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 20)
            
            // Buttons
            VStack(spacing: 12) {
                // Confirm button
                Button {
                    confirmCityLocation()
                } label: {
                    HStack {
                        if isLoading {
                            CustomLoadingIndicator(size: 20)
                                .padding(.trailing, 8)
                        }
                        
                        Text(isLoading ? "Validating..." : "Confirm Location")
                            .appSubheading()
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(cityInput.isEmpty || isLoading ? Color.gray.opacity(0.3) : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(cityInput.isEmpty || isLoading)
                .buttonStyle(PlainButtonStyle())
                
                // Back button
                Button {
                    withAnimation {
                        showingManualEntry = false
                        cityInput = ""
                        errorMessage = nil
                    }
                } label: {
                    Text("Back")
                        .appBody()
                        .foregroundColor(.gray)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Actions
    
    private func requestLocationPermission() {
        locationManager.requestLocationPermission()
        
        // Wait a bit to see if permission was granted
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if locationManager.authorizationStatus == .authorizedWhenInUse ||
               locationManager.authorizationStatus == .authorizedAlways {
                
                // Wait for location to be updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let location = locationManager.currentLocation {
                        locationManager.saveLocationPreference(.coordinate(location.coordinate))
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func confirmCityLocation() {
        guard !cityInput.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        locationManager.geocodeCity(cityInput.trimmingCharacters(in: .whitespaces)) { result in
            Task { @MainActor in
                isLoading = false
                
                switch result {
                case .success:
                    locationManager.saveLocationPreference(.city(cityInput.trimmingCharacters(in: .whitespaces)))
                    onDismiss()
                    
                case .failure:
                    errorMessage = "Could not find '\(cityInput)' in the UK. Please try again."
                }
            }
        }
    }
}

// MARK: - Preview

struct LocationPromptModal_Previews: PreviewProvider {
    static var previews: some View {
        LocationPromptModal {
            print("Dismissed")
        }
        .environmentObject(LocationManager())
        .preferredColorScheme(.dark)
    }
}
