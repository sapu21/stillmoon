import SwiftUI

// MARK: Buttons

/// Duolingo-style pressable button: the face sits on a darker edge and sinks into it when pressed.
/// Flat at night (PRD §2: nothing stimulating at night).
struct ChunkyButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        ChunkyFace(kind: kind, configuration: configuration)
    }

    private struct ChunkyFace: View {
        @Environment(\.theme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        let kind: Kind
        let configuration: ButtonStyleConfiguration

        var body: some View {
            let depth: CGFloat = theme.isNight ? 0 : 5
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            let primary = kind == .primary
            let fill = primary ? (isEnabled ? theme.accent : theme.cardBorder) : theme.surface
            let edge = primary && isEnabled ? theme.accentEdge : theme.cardBorder
            let text = primary ? (isEnabled ? theme.onAccent : theme.secondaryText) : theme.text
            configuration.label
                .font(.headline)
                .foregroundStyle(text)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 16)
                .background(shape.fill(fill))
                .overlay(shape.strokeBorder(primary ? Color.clear : theme.cardBorder, lineWidth: 2))
                .offset(y: configuration.isPressed ? min(3, depth) : 0)
                .background(shape.fill(edge).offset(y: depth))
                .padding(.bottom, depth)
                .contentShape(shape)
                .animation(.spring(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// Round chunky button, e.g. the play button on a suggestion.
struct RoundChunkyButtonStyle: ButtonStyle {
    var diameter: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        RoundFace(diameter: diameter, configuration: configuration)
    }

    private struct RoundFace: View {
        @Environment(\.theme) private var theme
        let diameter: CGFloat
        let configuration: ButtonStyleConfiguration

        var body: some View {
            let depth: CGFloat = theme.isNight ? 0 : 5
            configuration.label
                .foregroundStyle(theme.onAccent)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(theme.accent))
                .offset(y: configuration.isPressed ? min(3, depth) : 0)
                .background(Circle().fill(theme.accentEdge).offset(y: depth))
                .padding(.bottom, depth)
                .contentShape(Circle())
                .animation(.spring(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// A pressable tile with a border-colored edge (moon buttons, goal cards).
struct TileButtonStyle: ButtonStyle {
    let fill: Color
    let border: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: 2))
            .offset(y: configuration.isPressed ? 3 : 0)
            .background(shape.fill(border).offset(y: 4))
            .padding(.bottom, 4)
            .contentShape(shape)
            .animation(.spring(duration: 0.12), value: configuration.isPressed)
    }
}

/// Toggleable capsule; 44pt minimum height.
struct Chip: View {
    @Environment(\.theme) private var theme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(isSelected ? theme.accent : theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(Capsule().fill(isSelected ? theme.accentSoft : theme.surface))
                .overlay(Capsule().strokeBorder(isSelected ? theme.accent : theme.cardBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Moons

/// Restedness and weekly progress as moon phases: level 1 is a new moon, 5 is full.
enum MoonPhase {
    static let labels = ["Not rested", "A little rested", "Okay", "Rested", "Very rested"]

    private static func clamped(_ level: Int) -> Int { min(max(level, 1), 5) }

    /// How far the shadow disc sits from the moon's center, as a fraction of its radius.
    static func shadowOffset(level: Int) -> CGFloat {
        let offsets: [CGFloat] = [0, 0.62, 1.15, 1.77, 4.6]
        return offsets[clamped(level) - 1]
    }

    static func label(level: Int) -> String { labels[clamped(level) - 1] }

    /// The week's moon: new with nothing done, full once the goal is met, never past full.
    static func level(done: Int, goal: Int) -> Int {
        let goal = max(1, goal)
        if done >= goal { return 5 }
        return 1 + Int(Double(max(0, done)) / Double(goal) * 4)
    }
}

struct MoonPhaseView: View {
    @Environment(\.theme) private var theme
    let level: Int
    /// The color behind the moon; the shadow disc is painted in it.
    let background: Color
    var size: CGFloat = 32

    var body: some View {
        let diameter = size * 26 / 32
        ZStack {
            Circle().fill(theme.moon).frame(width: diameter, height: diameter)
            Circle().fill(background).frame(width: diameter, height: diameter)
                .offset(x: MoonPhase.shadowOffset(level: level) * diameter / 2)
            Circle().strokeBorder(theme.moonEdge, lineWidth: 2).frame(width: diameter, height: diameter)
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityHidden(true)
    }
}

struct MoonButton: View {
    @Environment(\.theme) private var theme
    let level: Int
    let isSelected: Bool
    var size: CGFloat = 54
    let action: () -> Void

    var body: some View {
        let fill = isSelected ? theme.accentSoft : theme.surface
        Button(action: action) {
            MoonPhaseView(level: level, background: fill, size: size * 0.6)
                .frame(width: size, height: size)
        }
        .buttonStyle(TileButtonStyle(fill: fill, border: isSelected ? theme.accent : theme.cardBorder))
        .accessibilityLabel(MoonPhase.label(level: level))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Text pieces

/// What Lumi says. Pops in once; later changes cross-fade.
struct SpeechBubble: View {
    enum Tail { case leading, trailing }
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let text: String
    var tail: Tail = .leading
    @State private var shown = false

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: tail == .leading ? 6 : 18,
                                           bottomTrailingRadius: tail == .trailing ? 6 : 18, topTrailingRadius: 18,
                                           style: .continuous)
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(shape.fill(theme.surface))
            .overlay(shape.strokeBorder(theme.cardBorder, lineWidth: 2))
            .scaleEffect(shown || reduceMotion ? 1 : 0.6, anchor: tail == .leading ? .bottomLeading : .bottomTrailing)
            .opacity(shown || reduceMotion ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: text)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.3)) { shown = true }
            }
    }
}

/// "Why: …" under a suggestion (PRD principle 4).
struct ReasonLine: View {
    @Environment(\.theme) private var theme
    let reason: String

    var body: some View {
        Text("Why: \(reason)")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.reasonText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.reasonFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Small label pill, e.g. "Apple Watch estimate". (Not `Tag`: Swift Testing has one.)
struct LabelPill: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.accentSoft, in: Capsule())
    }
}

struct IconTile: View {
    @Environment(\.theme) private var theme
    let systemName: String
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(theme.accent)
            .frame(width: size, height: size)
            .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct StepProgress: View {
    @Environment(\.theme) private var theme
    let value: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.cardBorder)
                Capsule().fill(theme.accent)
                    .frame(width: geo.size.width * CGFloat(value) / CGFloat(max(total, 1)))
            }
        }
        .frame(height: 14)
        .animation(.spring(duration: 0.4), value: value)
        .accessibilityElement()
        .accessibilityLabel("Step \(value) of \(total)")
    }
}

// MARK: Motion helpers

private struct RiseIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear { withAnimation(.easeOut(duration: 0.5).delay(delay)) { shown = true } }
    }
}

extension View {
    /// Fades and slides the view up on first appearance (cards on Today).
    func riseIn(delay: Double = 0) -> some View { modifier(RiseIn(delay: delay)) }
}

/// Wraps children onto new lines, left to right (chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = makeRows(maxWidth, subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? (rows.map(\.width).max() ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in makeRows(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[i].place(at: CGPoint(x: x, y: y),
                                  proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func makeRows(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if !current.indices.isEmpty && current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(i)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: Sky

struct SkyDot {
    let x: CGFloat // 0...1 of the width
    let y: CGFloat // 0...1 of the height
    let r: CGFloat // points
}

/// Twinkling dots. Day twinkles in 3 s, night in a slow 6 s at low opacity.
struct StarField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stars: [SkyDot]
    let color: Color
    var period: Double = 3
    var alphaRange: ClosedRange<Double> = 0.25...1

    static let day = [SkyDot(x: 0.10, y: 0.50, r: 2.5), SkyDot(x: 0.38, y: 0.36, r: 2),
                      SkyDot(x: 0.77, y: 0.30, r: 3), SkyDot(x: 0.90, y: 0.50, r: 2)]
    static let night = [SkyDot(x: 0.08, y: 0.14, r: 1.5), SkyDot(x: 0.25, y: 0.30, r: 1),
                        SkyDot(x: 0.44, y: 0.12, r: 1.5), SkyDot(x: 0.64, y: 0.26, r: 1),
                        SkyDot(x: 0.85, y: 0.16, r: 1.5), SkyDot(x: 0.93, y: 0.42, r: 1),
                        SkyDot(x: 0.06, y: 0.50, r: 1), SkyDot(x: 0.77, y: 0.56, r: 1.5),
                        SkyDot(x: 0.16, y: 0.70, r: 1), SkyDot(x: 0.54, y: 0.64, r: 1)]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                for (i, star) in stars.enumerated() {
                    let phase = reduceMotion ? 0.5 : (sin((t / period + Double(i) * 0.37) * 2 * .pi) + 1) / 2
                    let alpha = alphaRange.lowerBound + (alphaRange.upperBound - alphaRange.lowerBound) * phase
                    let rect = CGRect(x: star.x * size.width - star.r, y: star.y * size.height - star.r,
                                      width: star.r * 2, height: star.r * 2)
                    gc.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Rolling hill silhouette along the bottom of its rect.
struct Hills: Shape {
    var lift: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.45))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * (0.42 + lift)),
                       control: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.02))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.35),
                       control: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * (0.72 - lift)))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A soft cloud for Lumi to rest on at night.
struct Cloud: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + w * x, y: r.minY + h * y) }
        var p = Path()
        p.move(to: pt(0.09, 1))
        p.addQuadCurve(to: pt(0.15, 0.43), control: pt(0, 0.5))
        p.addQuadCurve(to: pt(0.49, 0.22), control: pt(0.25, -0.1))
        p.addQuadCurve(to: pt(0.83, 0.4), control: pt(0.7, -0.15))
        p.addQuadCurve(to: pt(0.92, 1), control: pt(1.05, 0.45))
        p.closeSubpath()
        return p
    }
}

/// Lavender sky with hills and twinkling stars (Today and Log in headers).
struct SkyBackdrop: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.sky
            StarField(stars: theme.isNight ? StarField.night : StarField.day,
                      color: theme.isNight ? Color(hex: 0xCFC6EE) : .white,
                      period: theme.isNight ? 6 : 3,
                      alphaRange: theme.isNight ? 0.15...0.6 : 0.25...1)
            Hills().fill(theme.hill).frame(height: 110)
            Hills(lift: 0.2).fill(theme.hill2).frame(height: 70)
        }
        .accessibilityHidden(true)
    }
}
