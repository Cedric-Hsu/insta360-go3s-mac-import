import AppKit
import SwiftUI

/// iMovie-inspired light palette aligned with macOS system colors.
enum IMovieTheme {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
    static let browserBackground = Color(nsColor: .textBackgroundColor)
    static let cardBackground = Color.white
    static let cardHover = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let toolbarBackground = Color(nsColor: .windowBackgroundColor)
    static let accentGreen = Color(red: 0.16, green: 0.72, blue: 0.32)
    static let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let divider = Color(nsColor: .separatorColor)
    static let sidebarSelection = Color.accentColor.opacity(0.12)
    static let importedBorder = accentGreen
    static let pendingBorder = Color.orange.opacity(0.85)
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.35)
    static let placeholderTop = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let placeholderBottom = Color(red: 0.86, green: 0.87, blue: 0.90)

    static let sidebarWidth: CGFloat = 220
    static let cardCornerRadius: CGFloat = 10
    static let cardWidth: CGFloat = 168
}
