import SwiftUI
import Kingfisher
import FirebaseAuth

// MARK: - Unified Event Row Component
struct EventRow: View {
    let event: Event
    let ticket: Ticket?
    let bookmarkManager: BookmarkManager?
    let configuration: Configuration
    let onCancel: (() -> Void)?
    let distanceText: String?
    
    init(
        event: Event,
        ticket: Ticket? = nil,
        bookmarkManager: BookmarkManager? = nil,
        configuration: Configuration = .eventList,
        onCancel: (() -> Void)? = nil,
        distanceText: String? = nil
    ) {
        self.event = event
        self.ticket = ticket
        self.bookmarkManager = bookmarkManager
        self.configuration = configuration
        self.onCancel = onCancel
        self.distanceText = distanceText
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Event Image
            eventImage
            
            // Event Details
            eventDetails
            
            Spacer()
            
            // Right side content (bookmark, QR code, status)
            rightSideContent
        }
        .padding(.horizontal, configuration.horizontalPadding)
        .padding(.vertical, configuration.verticalPadding)
        .background(configuration.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .contextMenu {
            contextMenuContent
        }
    }
    
    // MARK: - Event Image
    private var eventImage: some View {
        Group {
            if let url = URL(string: event.imageUrl), !event.imageUrl.isEmpty {
                KFImage(url)
                    .placeholder {
                        imagePlaceholder
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                imagePlaceholder
            }
        }
    }
    
    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "music.note")
                    .font(.appIcon)
                    .foregroundColor(.gray)
            )
    }
    
    // MARK: - Event Details
    private var eventDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.name)
                .appBody()
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            if configuration.showVenue {
                Text(event.venue)
                    .appSecondary()
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // Date formatting based on configuration
            if configuration.showDetailedDate {
                if let startTime = event.startTime {
                    HStack(spacing: 4) {
                        Text(startTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .appSecondary()
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("-")
                        .appSecondary()
                        .foregroundColor(.gray)
                }
            } else {
                Text(event.startTime?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) ?? "-")
                    .appSecondary()
                    .foregroundColor(.gray)
            }
            
            // Show distance if available
            if let distance = distanceText {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(distance)
                        .appCaption()
                        .foregroundColor(.gray)
                }
            }
            
            // Only show cancelled badge here
            if let ticket = ticket, ticket.status == "cancelled" {
                HStack(spacing: 8) {
                    Text("Cancelled")
                        .appCaption()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    
    // MARK: - Right Side Content
    private var rightSideContent: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Bookmark button
            if configuration.showBookmark, let bookmarkManager = bookmarkManager {
                BookmarkButton(
                    event: event,
                    bookmarkManager: bookmarkManager,
                    size: configuration.bookmarkSize
                )
            }
            
            // QR code for all tickets (including past/used)
            if let ticket = ticket {
                if ticket.status == "confirmed" || ticket.status == "used" {
                    Image(systemName: "qrcode")
                        .font(.appIcon)
                        .foregroundColor(isPastEvent ? .gray : .white)
                }
            }
        }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuContent: some View {
        // Context menu removed - using swipe actions instead
        EmptyView()
    }
    
    // MARK: - Helper Properties
    private var isPastEvent: Bool {
        guard let startTime = event.startTime else { return false }
        
        let calendar = Calendar.current
        let nextDayEnd = calendar.dateInterval(of: .day, for: startTime)?.end ?? startTime
        let nextDay6AM = calendar.date(byAdding: .hour, value: 6, to: nextDayEnd) ?? startTime
        return Date() > nextDay6AM
    }
}

// MARK: - Configuration
extension EventRow {
    struct Configuration {
        let showBookmark: Bool
        let showPrice: Bool
        let showVenue: Bool
        let showDetailedDate: Bool
        let bookmarkSize: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let backgroundColor: Color
        let cornerRadius: CGFloat
        
        static let eventList = Configuration(
            showBookmark: true,
            showPrice: true,
            showVenue: true,
            showDetailedDate: false,
            bookmarkSize: 18,
            horizontalPadding: 20,
            verticalPadding: 12,
            backgroundColor: Color.clear,
            cornerRadius: 0
        )
        
        static let ticketRow = Configuration(
            showBookmark: false,
            showPrice: false,
            showVenue: true,
            showDetailedDate: true,
            bookmarkSize: 16,
            horizontalPadding: 20,
            verticalPadding: 12,
            backgroundColor: Color.clear,
            cornerRadius: 0
        )

        static let ticketRowWithBookmark = Configuration(
            showBookmark: true,
            showPrice: false,
            showVenue: true,
            showDetailedDate: true,
            bookmarkSize: 16,
            horizontalPadding: 20,
            verticalPadding: 12,
            backgroundColor: Color.clear,
            cornerRadius: 0
        )
    }
}

// MARK: - Convenience Initializers
extension EventRow {
    init(event: Event, bookmarkManager: BookmarkManager) {
        self.init(
            event: event,
            ticket: nil,
            bookmarkManager: bookmarkManager,
            configuration: .eventList,
            onCancel: nil
        )
    }
    
    init(ticketWithEvent: TicketWithEventData, isPast: Bool, onCancel: @escaping () -> Void) {
        self.init(
            event: ticketWithEvent.event,
            ticket: ticketWithEvent.ticket,
            bookmarkManager: nil,
            configuration: .ticketRow,
            onCancel: onCancel
        )
    }
    
    init(ticketWithEvent: TicketWithEventData, isPast: Bool, bookmarkManager: BookmarkManager, onCancel: @escaping () -> Void) {
        self.init(
            event: ticketWithEvent.event,
            ticket: ticketWithEvent.ticket,
            bookmarkManager: bookmarkManager,
            configuration: .ticketRowWithBookmark,
            onCancel: onCancel
        )
    }
}

// MARK: - Bookmark Button Component
struct BookmarkButton: View {
    let event: Event
    @ObservedObject var bookmarkManager: BookmarkManager
    let size: CGFloat
    @EnvironmentObject var appState: AppState

    init(event: Event, bookmarkManager: BookmarkManager, size: CGFloat = 18) {
        self.event = event
        self.bookmarkManager = bookmarkManager
        self.size = size
    }

    var body: some View {
        Button(action: {
            // Check if user is authenticated
            if Auth.auth().currentUser == nil {
                // Show sign-in sheet if not authenticated
                appState.isSignInSheetPresented = true
            } else {
                // Toggle bookmark if authenticated
                Task {
                    await bookmarkManager.toggleBookmark(for: event)
                }
            }
        }) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.appIcon)
                .foregroundColor(isBookmarked ? .white : .gray)
                .scaleEffect(isBookmarked ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: isBookmarked)
        }
    }

    private var isBookmarked: Bool {
        guard let eventId = event.id else { return false }
        return bookmarkManager.isBookmarked(eventId)
    }
}

// MARK: - Supporting Types
struct TicketWithEventData: Codable, Identifiable {
    let ticket: Ticket
    let event: Event
    var id: String {
        ticket.id ?? UUID().uuidString
    }
}
