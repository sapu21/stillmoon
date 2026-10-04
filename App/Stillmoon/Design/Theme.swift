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
    /// Primary buttons, links and selected states.
    let accent: Color
    /// The darker edge under chunky accent buttons (unused at night: night controls are flat).
    let accentEdge: Color
    /// Selected fills, chips and icon tiles.
    let accentSoft: Color
    /// Text and icons on `accent`.
    let onAccent: Color
    let accent2: Color
    let cardBorder: Color
    /// Today and Log in header sky, with its two hill layers.
    let sky: Color
    let hill: Color
    let hill2: Color
    /// The "Why: …" box under a suggestion.
    let reasonFill: Color
    let reasonText: Color
    /// Full moons and lit stars.
    let moon: Color
    let moonEdge: Color
    let isNight: Bool

    static let day = Theme(background: Color(hex: 0xFBF7F1), surface: Color(hex: 0xFFFFFF),
                           text: Color(hex: 0x231E3A), secondaryText: Color(hex: 0x5E5876),
                           accent: Color(hex: 0x6F5BB0), accentEdge: Color(hex: 0x4E3F8A),
                           accentSoft: Color(hex: 0xEDE8FA), onAccent: Color(hex: 0xFFFFFF),
                           accent2: Color(hex: 0xE8907E), cardBorder: Color(hex: 0xECE6F6),
                           sky: Color(hex: 0xE9E3FA), hill: Color(hex: 0xDCD3F6), hill2: Color(hex: 0xCDC1F1),
                           reasonFill: Color(hex: 0xFDF1EC), reasonText: Color(hex: 0x8A3F2E),
                           moon: Color(hex: 0xFFD66B), moonEdge: Color(hex: 0xE0AE33), isNight: false)

    static let night = Theme(background: Color(hex: 0x12142B), surface: Color(hex: 0x1E1F3F),
                             text: Color(hex: 0xD9D4EE), secondaryText: Color(hex: 0x9A93B8),
                             accent: Color(hex: 0xA99BE0), accentEdge: Color(hex: 0xA99BE0),
                             accentSoft: Color(hex: 0x2A2650), onAccent: Color(hex: 0x12142B),
                             accent2: Color(hex: 0xC98B80), cardBorder: Color(hex: 0x2C2B55),
                             sky: Color(hex: 0x12142B), hill: Color(hex: 0x1A1B3A), hill2: Color(hex: 0x16183A),
                             reasonFill: Color(hex: 0x1E1F3F), reasonText: Color(hex: 0x9A93B8),
                             moon: Color(hex: 0xEADFB8), moonEdge: Color(hex: 0xC9BD8F), isNight: true)
}

extension EnvironmentValues {
    @Entry var theme: Theme = .day
}

/// Rounded card (PRD §2 "Cards"): soft border and a chunky bottom edge by day, flat at night.
struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.isNight ? 26 : 22, style: .continuous)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.isNight ? 20 : 16)
            .foregroundStyle(theme.text)
            .background(shape.fill(theme.surface))
            .overlay(shape.strokeBorder(theme.isNight ? Color.clear : theme.cardBorder, lineWidth: 2))
            .background(shape.fill(theme.isNight ? Color.clear : theme.cardBorder).offset(y: 3))
            .padding(.bottom, theme.isNight ? 0 : 3)
    }
}
