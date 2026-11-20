import SwiftUI

// 島・作り物・住人・素材の絵（自作の Canvas。画像や SF Symbols に置き換えない）。
// 昼と夜で同じ形を使い、色だけ大きく変える（夜は暗い影絵になり、灯りだけが光る）。

enum Paint {
    static func circle(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, _ color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color))
    }

    static func ellipse(_ ctx: GraphicsContext, _ c: CGPoint, _ rx: Double, _ ry: Double, _ color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)), with: .color(color))
    }

    static func rect(_ ctx: GraphicsContext, _ r: CGRect, _ color: Color, corner: Double = 0) {
        ctx.fill(Path(roundedRect: r, cornerRadius: corner, style: .continuous), with: .color(color))
    }

    static func poly(_ ctx: GraphicsContext, _ pts: [CGPoint], _ color: Color) {
        guard let first = pts.first else { return }
        var p = Path()
        p.move(to: first)
        for q in pts.dropFirst() { p.addLine(to: q) }
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }

    static func line(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ color: Color, _ w: Double) {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round))
    }

    static func glow(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, _ color: Color, _ strength: Double = 0.55) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(Gradient(colors: [color.opacity(strength), color.opacity(0)]), center: c, startRadius: 0, endRadius: r))
    }
}

/// 島の地図（0〜1 の座標を、少し斜めから見た画面の座標へ）
struct IslandMap {
    let rect: CGRect
    static let tilt = 0.8

    func project(_ p: CGPoint) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + (0.5 + (p.y - 0.5) * Self.tilt) * rect.height)
    }

    var unit: Double { rect.width / 13 }

    func islandPath(scale: Double = 1, lift: Double = 0) -> Path {
        var path = Path()
        let n = 96
        for i in 0...n {
            let a = Double(i) / Double(n) * 2 * .pi
            let q = project(IslandShape.point(a, scale: scale)) + CGPoint(x: 0, y: lift)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        path.closeSubpath()
        return path
    }
}

/// 昼か夜か
enum LightPhase { case day, night }

enum StructureArt {
    /// base は地面の点（物の下の中央）。u は大きさの単位
    static func draw(_ kind: Recipe.Kind, level: Int, ctx: GraphicsContext, base: CGPoint, u: Double, phase: LightPhase, t: Double = 0) {
        let s = u * (1 + 0.1 * Double(max(0, level - 1)))
        let night = phase == .night
        let wood = night ? Color(hex: 0x3B2C5E) : Color(hex: 0xB98A5E)
        let woodDeep = night ? Color(hex: 0x2A1F45) : Color(hex: 0x86603F)
        let white = night ? Color(hex: 0x4D3D78) : Color(hex: 0xFFFBF4)
        let stone = night ? Color(hex: 0x3E3263) : Color(hex: 0xB3B9C0)
        let coral = night ? Color(hex: 0x6A4C8F) : Day.coral
        let light = Night.amber
        let b = base
        // 影
        Paint.ellipse(ctx, b, s * 0.55, s * 0.16, Color.black.opacity(night ? 0.25 : 0.10))
        switch kind {
        case .bonfire:
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi
                Paint.ellipse(ctx, b + CGPoint(x: cos(a) * s * 0.36, y: sin(a) * s * 0.13), s * 0.11, s * 0.08, stone)
            }
            Paint.line(ctx, b + CGPoint(x: -s * 0.25, y: 0), b + CGPoint(x: s * 0.2, y: -s * 0.12), woodDeep, s * 0.1)
            Paint.line(ctx, b + CGPoint(x: s * 0.25, y: 0), b + CGPoint(x: -s * 0.2, y: -s * 0.12), wood, s * 0.1)
            let flick = 1 + 0.08 * sin(t * 9)
            let fh = s * 0.55 * flick
            Paint.poly(ctx, [b + CGPoint(x: -s * 0.17, y: -s * 0.08), b + CGPoint(x: 0, y: -s * 0.08 - fh), b + CGPoint(x: s * 0.17, y: -s * 0.08)], Color(hex: 0xFF9B4A))
            Paint.poly(ctx, [b + CGPoint(x: -s * 0.09, y: -s * 0.08), b + CGPoint(x: 0, y: -s * 0.08 - fh * 0.6), b + CGPoint(x: s * 0.09, y: -s * 0.08)], Color(hex: 0xFFE08A))
            if night { Paint.glow(ctx, b + CGPoint(x: 0, y: -s * 0.25), s * 1.4, light, 0.5) }
        case .lighthouse:
            let h = s * 1.5
            Paint.poly(ctx, [b + CGPoint(x: -s * 0.26, y: 0), b + CGPoint(x: -s * 0.16, y: -h), b + CGPoint(x: s * 0.16, y: -h), b + CGPoint(x: s * 0.26, y: 0)], white)
            for k in 0..<2 {
                let y0 = -h * (0.22 + Double(k) * 0.36)
                Paint.poly(ctx, [b + CGPoint(x: -s * 0.235, y: y0), b + CGPoint(x: -s * 0.2, y: y0 - h * 0.14), b + CGPoint(x: s * 0.2, y: y0 - h * 0.14), b + CGPoint(x: s * 0.235, y: y0)], coral)
            }
            Paint.rect(ctx, CGRect(x: b.x - s * 0.17, y: b.y - h - s * 0.28, width: s * 0.34, height: s * 0.28), night ? light : Color(hex: 0xFFE7A8), corner: s * 0.05)
            Paint.poly(ctx, [b + CGPoint(x: -s * 0.22, y: -h - s * 0.28), b + CGPoint(x: 0, y: -h - s * 0.52), b + CGPoint(x: s * 0.22, y: -h - s * 0.28)], coral)
            if night { Paint.glow(ctx, b + CGPoint(x: 0, y: -h - s * 0.14), s * 1.1, light, 0.6) }
        case .chimes:
            Paint.line(ctx, b, b + CGPoint(x: 0, y: -s * 1.1), woodDeep, s * 0.09)
            Paint.line(ctx, b + CGPoint(x: -s * 0.35, y: -s * 1.05), b + CGPoint(x: s * 0.35, y: -s * 1.05), wood, s * 0.08)
            for k in 0..<3 {
                let x = (Double(k) - 1) * s * 0.3
                let sway = sin(t * 2 + Double(k)) * s * 0.04
                Paint.line(ctx, b + CGPoint(x: x, y: -s * 1.05), b + CGPoint(x: x + sway, y: -s * 0.72), woodDeep.opacity(0.6), 1)
                Paint.ellipse(ctx, b + CGPoint(x: x + sway, y: -s * 0.66), s * 0.09, s * 0.11, night ? light.opacity(0.85) : Material.shell.color)
            }
        case .fence:
            Paint.line(ctx, b + CGPoint(x: -s * 0.5, y: -s * 0.25), b + CGPoint(x: s * 0.5, y: -s * 0.35), wood, s * 0.07)
            Paint.line(ctx, b + CGPoint(x: -s * 0.5, y: -s * 0.5), b + CGPoint(x: s * 0.5, y: -s * 0.6), wood, s * 0.07)
            for k in 0..<4 {
                let x = -s * 0.45 + Double(k) * s * 0.3
                let y = -Double(k) * s * 0.035
                Paint.rect(ctx, CGRect(x: b.x + x - s * 0.06, y: b.y + y - s * 0.72, width: s * 0.12, height: s * 0.72), woodDeep, corner: s * 0.05)
            }
        case .lantern:
            Paint.line(ctx, b, b + CGPoint(x: 0, y: -s * 0.95), woodDeep, s * 0.07)
            Paint.rect(ctx, CGRect(x: b.x - s * 0.17, y: b.y - s * 1.2, width: s * 0.34, height: s * 0.36), night ? light : Material.flower.color, corner: s * 0.12)
            Paint.circle(ctx, b + CGPoint(x: 0, y: -s * 1.02), s * 0.07, night ? .white : Material.flower.deep)
            if night { Paint.glow(ctx, b + CGPoint(x: 0, y: -s * 1.02), s, light, 0.55) }
        case .hammock:
            Paint.line(ctx, b + CGPoint(x: -s * 0.5, y: 0), b + CGPoint(x: -s * 0.5, y: -s * 0.8), woodDeep, s * 0.08)
            Paint.line(ctx, b + CGPoint(x: s * 0.5, y: 0), b + CGPoint(x: s * 0.5, y: -s * 0.8), woodDeep, s * 0.08)
            var p = Path()
            p.move(to: b + CGPoint(x: -s * 0.5, y: -s * 0.65))
            p.addQuadCurve(to: b + CGPoint(x: s * 0.5, y: -s * 0.65), control: b + CGPoint(x: 0, y: -s * 0.05))
            p.addQuadCurve(to: b + CGPoint(x: -s * 0.5, y: -s * 0.65), control: b + CGPoint(x: 0, y: -s * 0.3))
            ctx.fill(p, with: .color(coral))
        case .path:
            for k in 0..<4 {
                let c = b + CGPoint(x: -s * 0.45 + Double(k) * s * 0.3, y: -Double(k % 2) * s * 0.1)
                Paint.ellipse(ctx, c, s * 0.14, s * 0.08, stone)
                Paint.ellipse(ctx, c + CGPoint(x: -s * 0.03, y: -s * 0.02), s * 0.06, s * 0.03, white.opacity(0.6))
            }
        case .pool:
            Paint.ellipse(ctx, b + CGPoint(x: 0, y: -s * 0.1), s * 0.55, s * 0.26, stone)
            Paint.ellipse(ctx, b + CGPoint(x: 0, y: -s * 0.12), s * 0.46, s * 0.2, night ? Color(hex: 0x3B6E9E) : Day.sea)
            Paint.ellipse(ctx, b + CGPoint(x: -s * 0.12, y: -s * 0.16), s * 0.12, s * 0.04, white.opacity(0.7))
        case .tower:
            for x in [-0.3, 0.3] {
                Paint.line(ctx, b + CGPoint(x: x * s, y: 0), b + CGPoint(x: x * s * 0.6, y: -s * 1.0), woodDeep, s * 0.08)
            }
            Paint.rect(ctx, CGRect(x: b.x - s * 0.36, y: b.y - s * 1.08, width: s * 0.72, height: s * 0.14), wood, corner: s * 0.03)
            Paint.poly(ctx, [b + CGPoint(x: -s * 0.42, y: -s * 1.35), b + CGPoint(x: 0, y: -s * 1.65), b + CGPoint(x: s * 0.42, y: -s * 1.35)], coral)
            Paint.line(ctx, b + CGPoint(x: -s * 0.3, y: -s * 1.08), b + CGPoint(x: -s * 0.3, y: -s * 1.35), woodDeep, s * 0.05)
            Paint.line(ctx, b + CGPoint(x: s * 0.3, y: -s * 1.08), b + CGPoint(x: s * 0.3, y: -s * 1.35), woodDeep, s * 0.05)
        case .windmill:
            Paint.poly(ctx, [b + CGPoint(x: -s * 0.25, y: 0), b + CGPoint(x: -s * 0.12, y: -s * 1.0), b + CGPoint(x: s * 0.12, y: -s * 1.0), b + CGPoint(x: s * 0.25, y: 0)], white)
            let hub = b + CGPoint(x: 0, y: -s * 0.95)
            for k in 0..<4 {
                let a = t * 1.5 + Double(k) * .pi / 2
                Paint.line(ctx, hub, hub + CGPoint.polar(a, s * 0.55), wood, s * 0.12)
            }
            Paint.circle(ctx, hub, s * 0.07, coral)
        case .bell:
            var arch = Path()
            arch.move(to: b + CGPoint(x: -s * 0.35, y: 0))
            arch.addLine(to: b + CGPoint(x: -s * 0.35, y: -s * 0.9))
            arch.addQuadCurve(to: b + CGPoint(x: s * 0.35, y: -s * 0.9), control: b + CGPoint(x: 0, y: -s * 1.3))
            arch.addLine(to: b + CGPoint(x: s * 0.35, y: 0))
            ctx.stroke(arch, with: .color(woodDeep), style: StrokeStyle(lineWidth: s * 0.09, lineCap: .round))
            Paint.poly(ctx, [b + CGPoint(x: -s * 0.2, y: -s * 0.45), b + CGPoint(x: -s * 0.12, y: -s * 0.85), b + CGPoint(x: s * 0.12, y: -s * 0.85), b + CGPoint(x: s * 0.2, y: -s * 0.45)], night ? light : Day.sun)
            Paint.circle(ctx, b + CGPoint(x: 0, y: -s * 0.42), s * 0.05, woodDeep)
        case .flowerbed:
            Paint.rect(ctx, CGRect(x: b.x - s * 0.5, y: b.y - s * 0.25, width: s, height: s * 0.25), wood, corner: s * 0.05)
            for k in 0..<5 {
                let c = b + CGPoint(x: -s * 0.4 + Double(k) * s * 0.2, y: -s * 0.32 - Double(k % 2) * s * 0.08)
                Paint.circle(ctx, c, s * 0.09, night ? Color(hex: 0x6A4C8F) : (k % 2 == 0 ? Material.flower.color : Day.sun))
                Paint.circle(ctx, c, s * 0.035, night ? light.opacity(0.7) : .white)
            }
        case .scope:
            Paint.line(ctx, b + CGPoint(x: -s * 0.3, y: 0), b + CGPoint(x: 0, y: -s * 0.6), woodDeep, s * 0.06)
            Paint.line(ctx, b + CGPoint(x: s * 0.3, y: 0), b + CGPoint(x: 0, y: -s * 0.6), woodDeep, s * 0.06)
            Paint.line(ctx, b + CGPoint(x: -s * 0.25, y: -s * 0.45), b + CGPoint(x: s * 0.35, y: -s * 1.0), night ? Color(hex: 0x6E5AA8) : Color(hex: 0x6C7FA8), s * 0.18)
            Paint.circle(ctx, b + CGPoint(x: s * 0.36, y: -s * 1.0), s * 0.08, night ? light : Day.sun)
        case .cannon:
            Paint.rect(ctx, CGRect(x: b.x - s * 0.4, y: b.y - s * 0.3, width: s * 0.8, height: s * 0.3), wood, corner: s * 0.08)
            var conch = Path()
            conch.move(to: b + CGPoint(x: -s * 0.35, y: -s * 0.3))
            conch.addQuadCurve(to: b + CGPoint(x: s * 0.55, y: -s * 0.9), control: b + CGPoint(x: -s * 0.2, y: -s * 1.1))
            conch.addQuadCurve(to: b + CGPoint(x: -s * 0.35, y: -s * 0.3), control: b + CGPoint(x: s * 0.3, y: -s * 0.3))
            ctx.fill(conch, with: .color(night ? Color(hex: 0x7A5C9E) : Material.shell.color))
            Paint.circle(ctx, b + CGPoint(x: s * 0.5, y: -s * 0.86), s * 0.1, night ? light : Material.shell.deep)
        case .fireflies:
            Paint.rect(ctx, CGRect(x: b.x - s * 0.25, y: b.y - s * 0.7, width: s * 0.5, height: s * 0.7), (night ? Color(hex: 0x6E5AA8) : Day.foam).opacity(0.85), corner: s * 0.14)
            Paint.rect(ctx, CGRect(x: b.x - s * 0.2, y: b.y - s * 0.8, width: s * 0.4, height: s * 0.12), wood, corner: s * 0.03)
            for k in 0..<4 {
                let c = b + CGPoint(x: sin(t * 2 + Double(k) * 1.7) * s * 0.13, y: -s * 0.2 - Double(k) * s * 0.11)
                Paint.circle(ctx, c, s * 0.045, night ? light : Color(hex: 0xE8C547))
            }
            if night { Paint.glow(ctx, b + CGPoint(x: 0, y: -s * 0.4), s * 0.8, light, 0.4) }
        case .boat:
            var hull = Path()
            hull.move(to: b + CGPoint(x: -s * 0.55, y: -s * 0.25))
            hull.addQuadCurve(to: b + CGPoint(x: s * 0.55, y: -s * 0.25), control: b + CGPoint(x: 0, y: s * 0.2))
            hull.closeSubpath()
            ctx.fill(hull, with: .color(wood))
            Paint.line(ctx, b + CGPoint(x: 0, y: -s * 0.2), b + CGPoint(x: 0, y: -s * 1.0), woodDeep, s * 0.06)
            Paint.circle(ctx, b + CGPoint(x: 0, y: -s * 1.0), s * 0.1, night ? light : Day.sun)
            if night { Paint.glow(ctx, b + CGPoint(x: 0, y: -s * 1.0), s * 0.9, light, 0.5) }
        case .frostlamp:
            Paint.rect(ctx, CGRect(x: b.x - s * 0.12, y: b.y - s * 0.5, width: s * 0.24, height: s * 0.5), stone, corner: s * 0.04)
            Paint.rect(ctx, CGRect(x: b.x - s * 0.24, y: b.y - s * 0.82, width: s * 0.48, height: s * 0.34), stone, corner: s * 0.06)
            Paint.rect(ctx, CGRect(x: b.x - s * 0.12, y: b.y - s * 0.76, width: s * 0.24, height: s * 0.2), night ? Color(hex: 0xBFE9FF) : Color(hex: 0xDCEFFA), corner: s * 0.03)
            Paint.ellipse(ctx, b + CGPoint(x: 0, y: -s * 0.86), s * 0.32, s * 0.1, .white.opacity(night ? 0.7 : 0.95))
            if night { Paint.glow(ctx, b + CGPoint(x: 0, y: -s * 0.66), s, Color(hex: 0xBFE9FF), 0.45) }
        case .festival:
            Paint.line(ctx, b + CGPoint(x: -s * 0.35, y: 0), b + CGPoint(x: -s * 0.25, y: -s * 1.1), woodDeep, s * 0.08)
            Paint.line(ctx, b + CGPoint(x: s * 0.35, y: 0), b + CGPoint(x: s * 0.25, y: -s * 1.1), woodDeep, s * 0.08)
            Paint.rect(ctx, CGRect(x: b.x - s * 0.4, y: b.y - s * 1.2, width: s * 0.8, height: s * 0.16), coral, corner: s * 0.04)
            let colors: [Color] = night ? [light, Color(hex: 0xFF9CC2), Night.glow] : [Day.sun, Day.coral, Day.sea]
            for k in 0..<6 {
                let x = -s * 0.6 + Double(k) * s * 0.24
                Paint.poly(ctx, [b + CGPoint(x: x, y: -s * 1.3), b + CGPoint(x: x + s * 0.2, y: -s * 1.3), b + CGPoint(x: x + s * 0.1, y: -s * 1.12)], colors[k % 3])
            }
        }
    }
}

enum CreatureArt {
    /// 住人。c は体の中心、r は体の半径。swing は動きの大きさ（0〜1）
    static func draw(_ r: Resident, ctx: GraphicsContext, c: CGPoint, size: Double, swing: Double = 0, night: Bool = false) {
        draw(id: r.id, color: r.color, accent: r.accent, ctx: ctx, c: c, size: size, swing: swing, night: night)
    }

    static func draw(id: String, color: UInt32, accent: UInt32, ctx: GraphicsContext, c: CGPoint, size s: Double, swing: Double = 0, night: Bool = false) {
        let body = Color(hex: color)
        let acc = Color(hex: accent)
        let eye = Color(hex: 0x2B2230)
        Paint.ellipse(ctx, c + CGPoint(x: 0, y: s * 0.9), s * 0.8, s * 0.22, Color.black.opacity(night ? 0.3 : 0.12))
        switch id {
        case "tako":
            let open = swing * s * 0.2
            Paint.circle(ctx, c + CGPoint(x: -s * 1.0 - open, y: -s * 0.1), s * 0.38, acc)
            Paint.circle(ctx, c + CGPoint(x: s * 1.0 + open, y: -s * 0.1), s * 0.38, acc)
        case "puffin", "gull":
            Paint.ellipse(ctx, c + CGPoint(x: -s * 0.85, y: s * 0.1 - swing * s * 0.3), s * 0.3, s * 0.5, body.opacity(0.9))
            Paint.ellipse(ctx, c + CGPoint(x: s * 0.85, y: s * 0.1 - swing * s * 0.3), s * 0.3, s * 0.5, body.opacity(0.9))
        case "turtle", "hermit":
            Paint.ellipse(ctx, c + CGPoint(x: s * 0.35, y: -s * 0.05), s * 0.95, s * 0.75, acc)
        case "fox":
            Paint.ellipse(ctx, c + CGPoint(x: s * 0.9, y: s * 0.3), s * 0.55, s * 0.28, acc)
            Paint.circle(ctx, c + CGPoint(x: s * 1.3, y: s * 0.25), s * 0.16, .white)
        default:
            break
        }
        Paint.circle(ctx, c, s, body)
        switch id {
        case "puffin":
            Paint.ellipse(ctx, c + CGPoint(x: 0, y: -s * 0.15), s * 0.62, s * 0.55, .white)
            Paint.poly(ctx, [c + CGPoint(x: -s * 0.15, y: s * 0.05), c + CGPoint(x: s * 0.15, y: s * 0.05), c + CGPoint(x: 0, y: s * 0.42)], acc)
        case "gull":
            Paint.poly(ctx, [c + CGPoint(x: -s * 0.12, y: s * 0.05), c + CGPoint(x: s * 0.12, y: s * 0.05), c + CGPoint(x: 0, y: s * 0.35)], acc)
        case "turtle":
            Paint.circle(ctx, c + CGPoint(x: 0, y: s * 0.35), s * 0.3, body.opacity(0.85))
        case "seal":
            for dy in [-0.05, 0.08] {
                Paint.line(ctx, c + CGPoint(x: -s * 0.25, y: s * (0.22 + dy)), c + CGPoint(x: -s * 0.7, y: s * (0.15 + dy * 2)), acc, 1)
                Paint.line(ctx, c + CGPoint(x: s * 0.25, y: s * (0.22 + dy)), c + CGPoint(x: s * 0.7, y: s * (0.15 + dy * 2)), acc, 1)
            }
            Paint.ellipse(ctx, c + CGPoint(x: 0, y: s * 0.22), s * 0.12, s * 0.08, eye)
        case "fox":
            Paint.poly(ctx, [c + CGPoint(x: -s * 0.85, y: -s * 0.35), c + CGPoint(x: -s * 0.6, y: -s * 1.25), c + CGPoint(x: -s * 0.2, y: -s * 0.8)], body)
            Paint.poly(ctx, [c + CGPoint(x: s * 0.85, y: -s * 0.35), c + CGPoint(x: s * 0.6, y: -s * 1.25), c + CGPoint(x: s * 0.2, y: -s * 0.8)], body)
            Paint.ellipse(ctx, c + CGPoint(x: 0, y: s * 0.35), s * 0.5, s * 0.35, .white.opacity(0.85))
        case "owl":
            Paint.ellipse(ctx, c + CGPoint(x: 0, y: -s * 0.05), s * 0.75, s * 0.65, Color(hex: 0xFFF6E8))
            Paint.poly(ctx, [c + CGPoint(x: -s * 0.75, y: -s * 0.5), c + CGPoint(x: -s * 0.55, y: -s * 1.15), c + CGPoint(x: -s * 0.25, y: -s * 0.8)], acc)
            Paint.poly(ctx, [c + CGPoint(x: s * 0.75, y: -s * 0.5), c + CGPoint(x: s * 0.55, y: -s * 1.15), c + CGPoint(x: s * 0.25, y: -s * 0.8)], acc)
        case "tako", "hermit":
            Paint.line(ctx, c + CGPoint(x: -s * 0.3, y: -s * 0.7), c + CGPoint(x: -s * 0.4, y: -s * 1.2), acc, max(1, s * 0.12))
            Paint.line(ctx, c + CGPoint(x: s * 0.3, y: -s * 0.7), c + CGPoint(x: s * 0.4, y: -s * 1.2), acc, max(1, s * 0.12))
        default:
            break
        }
        let eyeY = id == "tako" || id == "hermit" ? -s * 1.2 : -s * 0.15
        let eyeX = id == "tako" || id == "hermit" ? s * 0.4 : s * 0.33
        if id == "tako" || id == "hermit" {
            Paint.circle(ctx, c + CGPoint(x: -eyeX, y: eyeY), s * 0.2, .white)
            Paint.circle(ctx, c + CGPoint(x: eyeX, y: eyeY), s * 0.2, .white)
        }
        Paint.circle(ctx, c + CGPoint(x: -eyeX, y: eyeY), s * 0.12, eye)
        Paint.circle(ctx, c + CGPoint(x: eyeX, y: eyeY), s * 0.12, eye)
        Paint.circle(ctx, c + CGPoint(x: -eyeX + s * 0.04, y: eyeY - s * 0.04), s * 0.04, .white)
        Paint.circle(ctx, c + CGPoint(x: eyeX + s * 0.04, y: eyeY - s * 0.04), s * 0.04, .white)
        Paint.ellipse(ctx, c + CGPoint(x: -s * 0.55, y: s * 0.2), s * 0.14, s * 0.09, Color(hex: 0xFF8FA0).opacity(0.55))
        Paint.ellipse(ctx, c + CGPoint(x: s * 0.55, y: s * 0.2), s * 0.14, s * 0.09, Color(hex: 0xFF8FA0).opacity(0.55))
    }

    /// 自分（ランタンを持った島の子）
    static func player(ctx: GraphicsContext, c: CGPoint, s: Double, facing: Double, hurt: Bool, t: Double) {
        Paint.ellipse(ctx, c + CGPoint(x: 0, y: s * 0.95), s * 0.8, s * 0.25, Color.black.opacity(0.35))
        Paint.circle(ctx, c, s, hurt ? Color(hex: 0xFFB3C0) : Color(hex: 0xFFF3DD))
        // 葉っぱの帽子
        Paint.ellipse(ctx, c + CGPoint(x: 0, y: -s * 0.85), s * 0.75, s * 0.28, Color(hex: 0x7CC08A))
        Paint.ellipse(ctx, c + CGPoint(x: s * 0.3, y: -s * 1.05), s * 0.3, s * 0.14, Color(hex: 0x5FA372))
        let look = CGPoint.polar(facing, s * 0.12)
        Paint.circle(ctx, c + CGPoint(x: -s * 0.3, y: -s * 0.1) + look, s * 0.12, Color(hex: 0x2B2230))
        Paint.circle(ctx, c + CGPoint(x: s * 0.3, y: -s * 0.1) + look, s * 0.12, Color(hex: 0x2B2230))
        Paint.ellipse(ctx, c + CGPoint(x: -s * 0.55, y: s * 0.2), s * 0.14, s * 0.09, Color(hex: 0xFF8FA0).opacity(0.6))
        Paint.ellipse(ctx, c + CGPoint(x: s * 0.55, y: s * 0.2), s * 0.14, s * 0.09, Color(hex: 0xFF8FA0).opacity(0.6))
        // 手に持つランタン
        let lamp = c + CGPoint(x: s * 1.05, y: s * 0.2 + sin(t * 4) * s * 0.06)
        Paint.glow(ctx, lamp, s * 2.2, Night.amber, 0.45)
        Paint.rect(ctx, CGRect(x: lamp.x - s * 0.22, y: lamp.y - s * 0.3, width: s * 0.44, height: s * 0.55), Night.amber, corner: s * 0.12)
        Paint.circle(ctx, lamp, s * 0.1, .white)
    }
}

/// 素材の小さな絵
struct MaterialIcon: View {
    let material: Material
    var size: CGFloat = 18

    var body: some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let s = Double(min(sz.width, sz.height)) / 2
            switch material {
            case .shell:
                var p = Path()
                p.move(to: c + CGPoint(x: 0, y: s * 0.8))
                p.addLine(to: c + CGPoint(x: -s * 0.9, y: -s * 0.2))
                p.addQuadCurve(to: c + CGPoint(x: s * 0.9, y: -s * 0.2), control: c + CGPoint(x: 0, y: -s * 1.3))
                p.closeSubpath()
                ctx.fill(p, with: .color(material.color))
                for k in -1...1 {
                    Paint.line(ctx, c + CGPoint(x: 0, y: s * 0.7), c + CGPoint(x: Double(k) * s * 0.45, y: -s * 0.55), material.deep, 1)
                }
            case .wood:
                Paint.rect(ctx, CGRect(x: c.x - s * 0.9, y: c.y - s * 0.4, width: s * 1.8, height: s * 0.8), material.color, corner: s * 0.4)
                Paint.ellipse(ctx, c + CGPoint(x: s * 0.6, y: 0), s * 0.3, s * 0.4, material.deep)
            case .flower:
                for k in 0..<5 {
                    Paint.circle(ctx, c + CGPoint.polar(Double(k) / 5 * 2 * .pi - .pi / 2, s * 0.5), s * 0.38, material.color)
                }
                Paint.circle(ctx, c, s * 0.3, Day.sun)
            case .stone:
                Paint.ellipse(ctx, c + CGPoint(x: 0, y: s * 0.1), s * 0.9, s * 0.65, material.color)
                Paint.ellipse(ctx, c + CGPoint(x: -s * 0.25, y: -s * 0.15), s * 0.3, s * 0.15, .white.opacity(0.6))
            case .glow:
                Paint.glow(ctx, c, s, material.color, 0.6)
                Paint.poly(ctx, [c + CGPoint(x: 0, y: -s * 0.9), c + CGPoint(x: s * 0.2, y: -s * 0.2), c + CGPoint(x: s * 0.9, y: 0), c + CGPoint(x: s * 0.2, y: s * 0.2),
                                 c + CGPoint(x: 0, y: s * 0.9), c + CGPoint(x: -s * 0.2, y: s * 0.2), c + CGPoint(x: -s * 0.9, y: 0), c + CGPoint(x: -s * 0.2, y: -s * 0.2)], material.deep)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 作り物の小さな絵（一覧用）
struct StructureIcon: View {
    let kind: Recipe.Kind
    var level: Int = 1
    var phase: LightPhase = .day
    var size: CGFloat = 48

    var body: some View {
        Canvas { ctx, sz in
            StructureArt.draw(kind, level: 1, ctx: ctx, base: CGPoint(x: sz.width / 2, y: sz.height * 0.88), u: Double(sz.width) * 0.48, phase: phase)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ResidentIcon: View {
    let resident: Resident
    var size: CGFloat = 44

    var body: some View {
        Canvas { ctx, sz in
            CreatureArt.draw(resident, ctx: ctx, c: CGPoint(x: sz.width / 2, y: sz.height * 0.55), size: Double(sz.width) * 0.27)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
