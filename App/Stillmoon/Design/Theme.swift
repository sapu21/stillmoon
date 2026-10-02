import SwiftUI

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// nonisolated + Sendable so it can be an environment default under main-actor default isolation.
nonisolated struct Theme: Equatable, Sendable {
    let background: Color
    let surface: Color
    let text: Color
    let secondaryText: Color
    let accent: Color
    let accent2: Color
    let isNight: Bool

    static let day = Theme(background: Color(hex: 0xFAF7F2), surface: Color(hex: 0xFFFFFF),
                           text: Color(hex: 0x1E1B2E), secondaryText: Color(hex: 0x5C5870),
                           accent: Color(hex: 0x8E7CC3), accent2: Color(hex: 0xE8907E), isNight: false)

    static let night = Theme(background: Color(hex: 0x12142B), surface: Color(hex: 0x2A2140),
                             text: Color(hex: 0xD9D4EE), secondaryText: Color(hex: 0x9A93B8),
                             accent: Color(hex: 0xA99BE0), accent2: Color(hex: 0xC98B80), isNight: true)
}

extension EnvironmentValues {
    @Entry var theme: Theme = .day
}

/// Rounded, spacious card (PRD §2 "Cards").
struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .foregroundStyle(theme.text)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
