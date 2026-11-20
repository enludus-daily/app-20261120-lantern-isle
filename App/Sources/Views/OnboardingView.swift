import SwiftUI

/// 最初の案内（3 ページ）。動く見本：昼の島 → 夜のもや → 作った物が夜に光る
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private var pages: [(String, String)] {
        [
            (tr("昼は、島づくり", "By day, build"), tr("浜で貝や流木を拾って、灯台やランタンを作る。毎日の潮で拾い物が変わる", "Gather shells and driftwood on the beach, then build lighthouses and lanterns. The tide brings new finds every day.")),
            (tr("夜は、3 分生きのびる", "By night, survive 3 minutes"), tr("もやが島に押し寄せる。指を置いて歩くだけ。攻撃は自動", "Mist swarms the island. Just touch and drag to walk — you attack automatically.")),
            (tr("作った物が、夜の力に", "What you build fights for you"), tr("灯台は見える範囲を広げ、柵はもやを押し返す。住人は夜の仲間になる。島のデータは端末の中だけ", "Lighthouses widen your light, fences push the mist back, islanders become night buddies. Your island stays on this device.")),
        ]
    }

    var body: some View {
        ZStack {
            (page == 1 ? Night.sky : Day.sand).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 10)
                TimelineView(.animation(minimumInterval: 1.0 / 24, paused: model.still || model.calm || reduceMotion)) { tl in
                    Canvas { ctx, size in
                        let t = model.still ? 1.0 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
                        OnboardingArt.draw(page: page, ctx: ctx, size: size, t: t)
                    }
                }
                .frame(maxWidth: 420, maxHeight: 340)
                .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text(pages[page].0)
                        .font(Fonts.title(28))
                        .foregroundStyle(page == 1 ? Night.amber : Day.ink)
                        .multilineTextAlignment(.center)
                    Text(pages[page].1)
                        .font(Fonts.body(15))
                        .foregroundStyle(page == 1 ? Night.text : Day.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .id(page)
                .transition(.opacity.combined(with: .offset(y: 8)))
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(i == page ? Day.coralDeep : Day.inkSoft.opacity(0.3)).frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                Spacer(minLength: 10)
            }
            .frame(maxWidth: 560)
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if page < 2 {
                    Button(tr("次へ", "Next")) {
                        model.press()
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { page += 1 }
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: page == 1 ? Night.mistDeep : Day.coralDeep, edge: page == 1 ? Night.island : Color(hex: 0xA94434)))
                    .accessibilityIdentifier("main.onboardingNext")
                } else {
                    Button(tr("島へ", "To the island")) {
                        model.press()
                        model.setOnboarded()
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Day.coralDeep, edge: Color(hex: 0xA94434)))
                    .accessibilityIdentifier("main.start")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

enum OnboardingArt {
    static func draw(page: Int, ctx: GraphicsContext, size: CGSize, t: Double) {
        let side = min(size.width, size.height / IslandMap.tilt)
        let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side * IslandMap.tilt) / 2 - side * (1 - IslandMap.tilt) / 2, width: side, height: side)
        let map = IslandMap(rect: rect)
        let u = map.unit
        let night = page == 1
        ctx.fill(map.islandPath(scale: 1.14), with: .color(night ? Night.sea : Day.foam))
        ctx.fill(map.islandPath(lift: u * 0.35), with: .color(night ? Night.rim : Day.sandDeep))
        ctx.fill(map.islandPath(), with: .color(night ? Night.island : Day.sand))
        ctx.fill(map.islandPath(scale: 0.78), with: .color(night ? Color(hex: 0x261A45) : Day.grass))
        let phase: LightPhase = night ? .night : .day
        let kinds: [Recipe.Kind] = page == 0 ? [.bonfire, .lighthouse, .chimes] : [.bonfire, .lighthouse, .chimes, .fence, .lantern]
        for k in kinds {
            StructureArt.draw(k, level: 1, ctx: ctx, base: map.project(Content.recipe(k).plot), u: u * 1.1, phase: phase, t: t)
        }
        switch page {
        case 0:
            // 浜のきらり（順に拾われる）
            let picks = Tide.pickups(day: "onboarding")
            let shown = Int(t * 1.2) % (picks.count + 3)
            for p in picks.prefix(max(0, picks.count - shown)) {
                let c = map.project(p.pos)
                Paint.circle(ctx, c, u * 0.3, .white.opacity(0.55))
                DayIslandPainter.pickupGlyph(ctx, c, p.material, u * 0.2)
            }
            CreatureArt.draw(Content.residents[0], ctx: ctx, c: map.project(Content.residents[0].home) + CGPoint(x: 0, y: -u * 0.3 + sin(t * 2.2) * u * 0.06), size: u * 0.3)
        case 1:
            let center = map.project(CGPoint(x: 0.5, y: 0.6))
            let me = center + CGPoint(x: cos(t * 0.8) * u * 1.2, y: sin(t * 1.1) * u * 0.6)
            for k in 0..<9 {
                let a = Double(k) / 9 * 2 * .pi + t * 0.3
                let d = u * (3.2 - (t * 0.6 + Double(k) * 0.37).truncatingRemainder(dividingBy: 2.2))
                let p = me + CGPoint.polar(a, d)
                Paint.glow(ctx, p, u * 0.5, Night.mist, 0.35)
                Paint.circle(ctx, p, u * 0.22, Night.mist)
                Paint.circle(ctx, p + CGPoint(x: -u * 0.07, y: -u * 0.03), u * 0.035, Night.amber)
                Paint.circle(ctx, p + CGPoint(x: u * 0.07, y: -u * 0.03), u * 0.035, Night.amber)
            }
            for k in 0..<3 {
                let a = t * 3.1 + Double(k) / 3 * 2 * .pi
                Paint.glow(ctx, me + CGPoint.polar(a, u * 0.9), u * 0.4, Night.amber, 0.6)
            }
            CreatureArt.player(ctx: ctx, c: me, s: u * 0.28, facing: t, hurt: false, t: t)
        default:
            for r in Content.residents.prefix(3) {
                CreatureArt.draw(r, ctx: ctx, c: map.project(r.home) + CGPoint(x: 0, y: -u * 0.3 + sin(t * 2.2 + r.home.x * 9) * u * 0.06), size: u * 0.27)
            }
            // 作った物から光が立ちのぼる
            for k in kinds {
                let c = map.project(Content.recipe(k).plot) + CGPoint(x: 0, y: -u * (0.8 + (t * 0.8).truncatingRemainder(dividingBy: 1.0)))
                Paint.glow(ctx, c, u * 0.45, Night.amber, 0.5)
            }
        }
    }
}
