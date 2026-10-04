import SwiftUI

struct LumiPalette {
    let body: Color
    let shade: Color
    let cap: Color
    let pom: Color
    let z: Color

    static let ink = Color(hex: 0x231E3A)
    static let cheek = Color(hex: 0xF4A99B)
    static let mouth = Color(hex: 0xB85479)
    static let capStar = Color(hex: 0xFFE38F)
    static let sparkle = Color(hex: 0xFFC94D)

    static let day = LumiPalette(body: Color(hex: 0xFFE7A0), shade: Color(hex: 0xF2CB6B),
                                 cap: Color(hex: 0x8E7CC3), pom: Color(hex: 0xF6F2FF), z: Color(hex: 0x8E7CC3))
    static let night = LumiPalette(body: Color(hex: 0xEADFB8), shade: Color(hex: 0xD6C68F),
                                   cap: Color(hex: 0x6F62A8), pom: Color(hex: 0xCFC6EE), z: Color(hex: 0xCFC6EE))
}

/// Stillmoon's mascot: a sleepy little moon in a nightcap. Decorative only; pair it with text.
struct LumiView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mood: LumiMood
    var motion: LumiMotion = .float
    var size: CGFloat = 160
    /// False holds a still pose with no blinking (sound session: PRD §7 "no animation").
    var animated = true

    var body: some View {
        let live = animated && !reduceMotion
        let pose = LumiPose.of(mood.effective(isNight: theme.isNight))
        let palette = theme.isNight ? LumiPalette.night : LumiPalette.day
        let resolvedMotion = live ? motion.effective(reduceMotion: false, isNight: theme.isNight) : .still
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { context in
            let t = live ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { gc, canvasSize in
                LumiArt.draw(in: &gc, size: canvasSize, pose: pose, palette: palette, motion: resolvedMotion, t: t, live: live)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Draws Lumi into a 200×200 space.
enum LumiArt {
    static func draw(in gc: inout GraphicsContext, size: CGSize, pose: LumiPose, palette: LumiPalette,
                     motion: LumiMotion, t: Double, live: Bool) {
        gc.scaleBy(x: size.width / 200, y: size.height / 200)
        gc.fill(ellipse(100, 188, 52, 7), with: .color(LumiPalette.ink.opacity(0.10))) // shadow stays put
        let m = LumiAnimation.transform(motion, at: t)
        gc.translateBy(x: 100, y: 186 + m.dy)
        gc.scaleBy(x: m.scaleX, y: m.scaleY)
        gc.translateBy(x: -100, y: -186)
        drawArms(&gc, pose, palette)
        drawBody(&gc, palette)
        drawCap(&gc, palette, t: t, live: live)
        drawFace(&gc, pose, t: t, live: live)
        if pose.zzz { drawZzz(&gc, palette, t: t, live: live) }
        if pose.sparkles { drawSparkles(&gc, t: t, live: live) }
    }

    private static func drawArms(_ gc: inout GraphicsContext, _ pose: LumiPose, _ p: LumiPalette) {
        let left = pose.leftArmUp ? ellipse(26, 82, 11, 16, rotate: -30) : ellipse(36, 142, 11, 15, rotate: 20)
        let right = pose.rightArmUp ? ellipse(174, 82, 11, 16, rotate: 30) : ellipse(164, 142, 11, 15, rotate: -20)
        for arm in [left, right] {
            gc.fill(arm, with: .color(p.body))
            gc.stroke(arm, with: .color(p.shade), lineWidth: 2)
        }
    }

    private static func drawBody(_ gc: inout GraphicsContext, _ p: LumiPalette) {
        let body = ellipse(100, 116, 68, 62)
        gc.fill(body, with: .color(p.body))
        var inner = gc
        inner.clip(to: body)
        inner.fill(ellipse(100, 156, 50, 18), with: .color(p.shade.opacity(0.45)))
        inner.fill(ellipse(70, 90, 15, 9, rotate: -30), with: .color(.white.opacity(0.45)))
        inner.fill(ellipse(150, 104, 5, 5), with: .color(p.shade))
        inner.fill(ellipse(140, 160, 6, 6), with: .color(p.shade.opacity(0.8)))
        inner.fill(ellipse(58, 156, 4, 4), with: .color(p.shade.opacity(0.8)))
    }

    private static func drawCap(_ gc: inout GraphicsContext, _ p: LumiPalette, t: Double, live: Bool) {
        var cap = Path()
        cap.move(to: pt(44, 88))
        cap.addCurve(to: pt(154, 50), control1: pt(50, 40), control2: pt(116, 14))
        cap.addCurve(to: pt(182, 104), control1: pt(170, 64), control2: pt(180, 84))
        cap.addLine(to: pt(170, 102))
        cap.addCurve(to: pt(148, 78), control1: pt(166, 88), control2: pt(158, 80))
        cap.addQuadCurve(to: pt(44, 88), control: pt(96, 70))
        cap.closeSubpath()
        gc.fill(cap, with: .color(p.cap))
        gc.fill(star4(cx: 104, cy: 44, r: 10), with: .color(LumiPalette.capStar))
        var brim = Path()
        brim.move(to: pt(40, 90))
        brim.addQuadCurve(to: pt(156, 80), control: pt(98, 66))
        gc.stroke(brim, with: .color(p.pom), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        var pom = gc // sways around the cap's tip
        pom.translateBy(x: 150, y: 60)
        pom.rotate(by: .degrees(live ? LumiAnimation.pomAngle(at: t) : 0))
        pom.translateBy(x: -150, y: -60)
        pom.fill(ellipse(180, 108, 11, 11), with: .color(p.pom))
    }

    private static func drawFace(_ gc: inout GraphicsContext, _ pose: LumiPose, t: Double, live: Bool) {
        let ink = GraphicsContext.Shading.color(LumiPalette.ink)
        let line = StrokeStyle(lineWidth: 4.5, lineCap: .round)
        switch pose.eyes {
        case .open:
            let s = live ? LumiAnimation.eyeScale(at: t) : 1
            for cx in [78.0, 122.0] {
                gc.fill(ellipse(cx, 118, 6.5, 8.5 * s), with: ink)
                if s > 0.5 { gc.fill(ellipse(cx + 2.5, 114.5, 2.3, 2.3), with: .color(.white)) }
            }
        case .happy:
            gc.stroke(arc(70, 120, 78, 109, 86, 120), with: ink, style: line)
            gc.stroke(arc(114, 120, 122, 109, 130, 120), with: ink, style: line)
        case .sleepy:
            gc.stroke(arc(70, 116, 78, 125, 86, 116), with: ink, style: line)
            gc.stroke(arc(114, 116, 122, 125, 130, 116), with: ink, style: line)
        }
        if pose.brows {
            var brows = Path()
            brows.move(to: pt(68, 105)); brows.addLine(to: pt(86, 100))
            brows.move(to: pt(114, 100)); brows.addLine(to: pt(132, 105))
            gc.stroke(brows, with: ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
        gc.fill(ellipse(60, 134, 11, 6.5), with: .color(LumiPalette.cheek.opacity(0.75)))
        gc.fill(ellipse(140, 134, 11, 6.5), with: .color(LumiPalette.cheek.opacity(0.75)))
        switch pose.mouth {
        case .smile:
            gc.stroke(arc(90, 134, 100, 144, 110, 134), with: ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        case .open:
            var mouth = arc(88, 132, 100, 154, 112, 132)
            mouth.closeSubpath()
            gc.fill(mouth, with: .color(LumiPalette.mouth))
            gc.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        case .o:
            gc.fill(ellipse(100, 139, 4.5, 3.5), with: ink)
        case .wobble:
            var mouth = Path()
            mouth.move(to: pt(90, 141))
            mouth.addQuadCurve(to: pt(100, 141), control: pt(95, 136))
            mouth.addQuadCurve(to: pt(110, 141), control: pt(105, 146))
            gc.stroke(mouth, with: ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
    }

    private static func drawZzz(_ gc: inout GraphicsContext, _ p: LumiPalette, t: Double, live: Bool) {
        let letters: [(x: Double, y: Double, size: Double)] = [(166, 34, 24), (186, 14, 17)]
        for (i, z) in letters.enumerated() {
            let drift = live ? LumiAnimation.zDrift(at: t + Double(i) * 1.5) : LumiAnimation.Drift(dx: 0, dy: 0, opacity: 1)
            var layer = gc
            layer.opacity = drift.opacity
            layer.draw(Text("z").font(.system(size: z.size, weight: .semibold, design: .rounded)).foregroundStyle(p.z),
                       at: pt(z.x + drift.dx, z.y + drift.dy))
        }
    }

    private static func drawSparkles(_ gc: inout GraphicsContext, t: Double, live: Bool) {
        let spots: [(x: Double, y: Double, r: Double)] = [(24, 52, 10), (178, 36, 8), (26, 150, 7)]
        for (i, s) in spots.enumerated() {
            let scale = live ? LumiAnimation.sparkleScale(at: t, index: i) : 1
            gc.fill(star4(cx: s.x, cy: s.y, r: s.r * scale), with: .color(LumiPalette.sparkle))
        }
    }

    // MARK: Geometry helpers

    private static func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    private static func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, rotate degrees: Double = 0) -> Path {
        let path = Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        guard degrees != 0 else { return path }
        let turn = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -cx, y: -cy)
        return path.applying(turn)
    }

    /// A quadratic stroke from (x0, y0) through control (cx, cy) to (x1, y1).
    private static func arc(_ x0: Double, _ y0: Double, _ cx: Double, _ cy: Double, _ x1: Double, _ y1: Double) -> Path {
        var p = Path()
        p.move(to: pt(x0, y0))
        p.addQuadCurve(to: pt(x1, y1), control: pt(cx, cy))
        return p
    }

    /// Four-point twinkle star.
    private static func star4(cx: Double, cy: Double, r: Double) -> Path {
        let w = r * 0.3
        var p = Path()
        p.move(to: pt(cx, cy - r))
        p.addLine(to: pt(cx + w, cy - w)); p.addLine(to: pt(cx + r, cy))
        p.addLine(to: pt(cx + w, cy + w)); p.addLine(to: pt(cx, cy + r))
        p.addLine(to: pt(cx - w, cy + w)); p.addLine(to: pt(cx - r, cy))
        p.addLine(to: pt(cx - w, cy - w))
        p.closeSubpath()
        return p
    }
}

/// Empty states: a small Lumi and one line of copy.
struct LumiEmptyState: View {
    @Environment(\.theme) private var theme
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            LumiView(mood: theme.isNight ? .sleepy : .calm, motion: theme.isNight ? .drift : .float, size: 110)
            Text(title).font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Moods") {
    ScrollView {
        LazyVGrid(columns: [GridItem(), GridItem()]) {
            ForEach(LumiMood.allCases, id: \.self) { mood in
                VStack {
                    LumiView(mood: mood, motion: mood == .cheer ? .bounce : .float, size: 150)
                    Text(mood.rawValue)
                }
            }
        }
    }
    .background(Theme.day.background)
}
