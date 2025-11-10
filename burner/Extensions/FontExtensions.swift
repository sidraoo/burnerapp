import SwiftUI

extension Font {
    private static let fontFamily = "Avenir Next"
    
    static func appFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black:
            return .custom("\(fontFamily)-Bold", size: size)
        case .medium, .semibold:
            return .custom("\(fontFamily)-Medium", size: size)
        default:
            return .custom("\(fontFamily)-Regular", size: size)
        }
    }
    
    
    // Semantic font sizes
    static var appCaption: Font { appFont(size: 12) }
    static var appSecondary: Font { appFont(size: 14) }
    static var appBody: Font { appFont(size: 16) }
    static var appSubheading: Font { appFont(size: 17, weight: .medium) }
    static var appCard: Font { appFont(size: 18) }
    static var appTitle: Font { appFont(size: 20, weight: .semibold) }
    static var appSectionHeader: Font { appFont(size: 24) }
    static var appPageHeader: Font { appFont(size: 28) }
    static var appHero: Font { appFont(size: 32) }
   
    static var appIcon: Font { .system(size: 16) }
    static var appLargeIcon: Font { .system(size: 60) }


}

extension View {
    func appFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.appFont(size: size, weight: weight))
    }
    
    // Semantic font modifiers
    func appCaption() -> some View {
        self.font(.appCaption)
    }
    
    func appSecondary() -> some View {
        self.font(.appSecondary)
    }
    
    func appBody() -> some View {
        self.font(.appBody)
    }
    
    func appCard() -> some View {
           self.font(.appCard)
       }
    
    func appTitle() -> some View {
        self.font(.appTitle)
    }
    
    func appSubheading() -> some View {
        self.font(.appSubheading)
    }
        
    func appSectionHeader() -> some View {
        self.font(.appSectionHeader)
    }
    
    func appPageHeader() -> some View {
        self.font(.appPageHeader)
    }
    
    func appHero() -> some View {
        self.font(.appHero)
    }
}
