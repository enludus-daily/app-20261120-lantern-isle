import SwiftUI

/// 夜の 3 分。スティックは画面のどこでも（指を置いた所が中心）。攻撃は自動
struct NightView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Night.sky.ignoresSafeArea()
            if let engine = model.engine {
                TimelineView(.animation(minimumInterval: nil, paused: model.still || model.upgradeChoices != nil || !model.nightRunning || !model.active)) { tl in
                    let _ = tick(engine, tl.date)
                    ZStack(alignment: .top) {
                        Canvas { ctx, size in
                            NightPainter.draw(ctx: ctx, size: size, engine: engine, reduceMotion: reduceMotion)
                        }
                        .ignoresSafeArea()
                        NightHUD(sim: engine.sim)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        if engine.sim.time < 3.5 {
                            StingerText(title: engine.sim.isEndless ? tr("終わらない夜", "Endless Night") : trf("第 %d 夜", "NIGHT %d", engine.sim.loadout.night),
                                        detail: tr("指を置いて、動かして歩く", "Touch and drag to move"))
                                .opacity(min(1, (3.5 - engine.sim.time) * 2))
                                .frame(maxHeight: .infinity)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in engine.setStick(origin: v.startLocation, point: v.location) }
                        .onEnded { _ in engine.releaseStick() }
                )
                .accessibilityElement()
                .accessibilityLabel(tr("夜の島。画面のどこかに指を置いて動かすと歩く。攻撃は自動", "The island at night. Touch anywhere and drag to walk. Attacks are automatic."))
            }
            if let choices = model.upgradeChoices {
                LevelUpOverlay(choices: choices, level: model.engine?.sim.level ?? 1)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    model.retreat()
                } label: {
                    Text(tr("昼にもどる", "Back to day"))
                        .font(Fonts.head(14))
                        .foregroundStyle(Night.text)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Capsule().fill(Night.panel.opacity(0.9)))
                        .overlay(Capsule().stroke(Night.rim, lineWidth: 1))
                }
                .buttonStyle(SquishStyle())
                .accessibilityIdentifier("main.retreat")
                Spacer()
                Text(tr("集めた砂は持ち帰れる", "You keep the sand you gathered"))
                    .font(Fonts.label(11))
                    .foregroundStyle(Night.textSoft)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: model.upgradeChoices)
    }

    private func tick(_ engine: NightEngine, _ date: Date) -> Bool {
        guard !model.still, model.nightRunning, model.upgradeChoices == nil else { return false }
        if let events = engine.advance(to: date, autopilot: model.autopilot) {
            Task { @MainActor in model.nightChanged(events) }
        }
        return true
    }
}

/// 上の表示：残り時間・体力・レベル
struct NightHUD: View {
    let sim: NightSim

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Bar(value: sim.hp / sim.maxHP, color: sim.hp < sim.maxHP * 0.3 ? Night.danger : Color(hex: 0x8CE39A), width: 120)
                    Text(trf("体力 %d", "HP %d", Int(sim.hp.rounded(.up))))
                        .font(Fonts.label(11)).foregroundStyle(Night.textSoft).monospacedDigit()
                }
                Spacer()
                Text(Clock.text(sim.remaining))
                    .font(Fonts.number(34))
                    .kerning(-1)
                    .foregroundStyle(sim.isEndless ? Night.glow : sim.remaining < 30 ? Night.amber : Night.text)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Bar(value: Double(sim.xp) / Double(sim.xpNeeded), color: Night.glow, width: 120)
                    Text(trf("Lv %d · 砂 %d", "Lv %d · Sand %d", sim.level, sim.sand))
                        .font(Fonts.label(11)).foregroundStyle(Night.textSoft).monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("残り %@、体力 %d", "%@ left, HP %d", Clock.text(sim.remaining), Int(sim.hp)))
    }
}

struct Bar: View {
    let value: Double
    let color: Color
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Night.panel)
            Capsule().fill(color).frame(width: max(6, width * min(1, max(0, value))))
        }
        .frame(width: width, height: 9)
        .overlay(Capsule().stroke(Night.rim, lineWidth: 1))
    }
}

/// 場面の切れ目の大きな文字
struct StingerText: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(Fonts.title(36)).kerning(2).foregroundStyle(Night.amber)
            Text(detail).font(Fonts.body(14)).foregroundStyle(Night.text)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Night.sky.opacity(0.6)))
    }
}

/// レベルアップの 3 枚（時間が止まる）
struct LevelUpOverlay: View {
    @Environment(AppModel.self) private var model
    let choices: [Upgrade]
    let level: Int

    var body: some View {
        ZStack {
            Night.sky.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(trf("レベル %d！", "LEVEL %d!", level)).font(Fonts.title(32)).foregroundStyle(Night.amber)
                Text(tr("ひとつ選ぶ（この夜だけ）", "Pick one (for this night)")).font(Fonts.body(14)).foregroundStyle(Night.text)
                ForEach(Array(choices.enumerated()), id: \.offset) { i, u in
                    Button {
                        model.chooseUpgrade(i)
                    } label: {
                        HStack(spacing: 12) {
                            UpgradeGlyph(upgrade: u).frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.title).font(Fonts.head(17)).foregroundStyle(Night.text)
                                Text(u.detail).font(Fonts.body(13)).foregroundStyle(Night.textSoft)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: 420)
                        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Night.panel))
                        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Night.amber.opacity(0.5), lineWidth: 1.5))
                    }
                    .buttonStyle(SquishStyle())
                    .accessibilityIdentifier("main.upgrade\(i)")
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct UpgradeGlyph: View {
    let upgrade: Upgrade

    var body: some View {
        Canvas { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let r = s.width / 2
            Paint.circle(ctx, c, r, Night.island)
            switch upgrade {
            case .sparkPower, .sparkRate, .sparkCount:
                let n = upgrade == .sparkCount ? 3 : 1
                for k in 0..<n {
                    let p = c + CGPoint(x: (Double(k) - Double(n - 1) / 2) * r * 0.5, y: 0)
                    Paint.glow(ctx, p, r * 0.6, Night.amber, 0.7)
                    Paint.circle(ctx, p, r * 0.18, Night.amber)
                }
                if upgrade == .sparkRate {
                    Paint.line(ctx, c + CGPoint(x: -r * 0.7, y: -r * 0.2), c + CGPoint(x: -r * 0.3, y: -r * 0.2), Night.text, 2)
                    Paint.line(ctx, c + CGPoint(x: -r * 0.7, y: r * 0.2), c + CGPoint(x: -r * 0.3, y: r * 0.2), Night.text, 2)
                }
            case .speed:
                Paint.ellipse(ctx, c + CGPoint(x: -r * 0.2, y: r * 0.25), r * 0.3, r * 0.18, Night.text)
                Paint.ellipse(ctx, c + CGPoint(x: r * 0.25, y: -r * 0.15), r * 0.3, r * 0.18, Night.text)
            case .magnet:
                Paint.circle(ctx, c, r * 0.6, Night.glow.opacity(0.3))
                Paint.circle(ctx, c, r * 0.2, Night.glow)
            case .vigor, .rest:
                Paint.circle(ctx, c + CGPoint(x: -r * 0.2, y: -r * 0.1), r * 0.28, Color(hex: 0x8CE39A))
                Paint.circle(ctx, c + CGPoint(x: r * 0.2, y: -r * 0.1), r * 0.28, Color(hex: 0x8CE39A))
                Paint.poly(ctx, [c + CGPoint(x: -r * 0.47, y: 0), c + CGPoint(x: r * 0.47, y: 0), c + CGPoint(x: 0, y: r * 0.5)], Color(hex: 0x8CE39A))
            case .light:
                Paint.glow(ctx, c, r, Night.amber, 0.8)
            case .allPower:
                Paint.poly(ctx, [c + CGPoint(x: 0, y: -r * 0.7), c + CGPoint(x: r * 0.6, y: r * 0.5), c + CGPoint(x: -r * 0.6, y: r * 0.5)], Night.amber)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 夜の世界を描く（深い紫のもや。灯りと作った物だけが光る）
enum NightPainter {
    @MainActor
    static func draw(ctx: GraphicsContext, size: CGSize, engine: NightEngine, reduceMotion: Bool) {
        let sim = engine.sim
        let t = sim.time
        var shake = CGPoint.zero
        if !reduceMotion && sim.shake > 0 {
            shake = CGPoint(x: sin(t * 61) * 7 * sim.shake, y: cos(t * 47) * 5 * sim.shake)
        }
        let offset = CGPoint(x: size.width / 2, y: size.height / 2) - sim.player + shake
        func s(_ p: CGPoint) -> CGPoint { p + offset }
        let W = NightSim.world
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Night.sea))
        // 海の小さな光
        var rng = SeededRandom(seed: 11)
        for _ in 0..<60 {
            let p = s(CGPoint(x: rng.unit() * W * 1.4 - W * 0.2, y: rng.unit() * W * 1.4 - W * 0.2))
            Paint.circle(ctx, p, 1.2, Night.mist.opacity(0.25))
        }
        // 島
        var island = Path()
        var grass = Path()
        for i in 0...96 {
            let a = Double(i) / 96 * 2 * .pi
            let q = s(NightSim.toWorld(IslandShape.point(a)))
            let g = s(NightSim.toWorld(IslandShape.point(a, scale: 0.78)))
            if i == 0 { island.move(to: q); grass.move(to: g) } else { island.addLine(to: q); grass.addLine(to: g) }
        }
        ctx.fill(island, with: .color(Night.island))
        ctx.stroke(island, with: .color(Night.rim), lineWidth: 3)
        ctx.fill(grass, with: .color(Color(hex: 0x261A45)))
        // 潮だまり・たき火の輪
        for p in sim.pools {
            Paint.circle(ctx, s(p), sim.poolRadius, Color(hex: 0x2E4C86).opacity(0.65))
        }
        if sim.loadout.lv(.bonfire) > 0 {
            ctx.stroke(Path(ellipseIn: CGRect(x: s(sim.bonfire).x - sim.bonfireRadius, y: s(sim.bonfire).y - sim.bonfireRadius, width: sim.bonfireRadius * 2, height: sim.bonfireRadius * 2)),
                       with: .color(Night.amber.opacity(0.22)), style: StrokeStyle(lineWidth: 2, dash: [5, 7]))
        }
        // 灯台の回る光
        if sim.loadout.lv(.lighthouse) > 0 {
            let o = s(sim.lighthouse)
            var beam = Path()
            beam.move(to: o)
            beam.addLine(to: o + CGPoint.polar(sim.beamAngle - 0.11, 620))
            beam.addLine(to: o + CGPoint.polar(sim.beamAngle + 0.11, 620))
            beam.closeSubpath()
            ctx.fill(beam, with: .linearGradient(Gradient(colors: [Night.amber.opacity(0.4), Night.amber.opacity(0)]), startPoint: o, endPoint: o + CGPoint.polar(sim.beamAngle, 620)))
        }
        // 作り物
        for r in Content.recipes where sim.loadout.lv(r.kind) > 0 && r.kind != .boat {
            StructureArt.draw(r.kind, level: sim.loadout.lv(r.kind), ctx: ctx, base: s(NightSim.toWorld(r.plot)), u: 46, phase: .night, t: t)
        }
        for post in sim.fencePosts {
            Paint.rect(ctx, CGRect(x: s(post).x - 6, y: s(post).y - 22, width: 12, height: 26), Color(hex: 0x4A3A70), corner: 4)
            Paint.circle(ctx, s(post) + CGPoint(x: 0, y: -22), 3, Night.amber.opacity(0.8))
        }
        if let boat = sim.boatPos {
            StructureArt.draw(.boat, level: sim.loadout.lv(.boat), ctx: ctx, base: s(boat), u: 40, phase: .night, t: t)
        }
        // 光る砂
        for g in sim.gems {
            let p = s(g.pos)
            let r = g.value > 3 ? 7.0 : g.value > 1 ? 5.0 : 3.6
            Paint.glow(ctx, p, r * 2.4, Night.glow, 0.35)
            Paint.poly(ctx, [p + CGPoint(x: 0, y: -r), p + CGPoint(x: r * 0.7, y: 0), p + CGPoint(x: 0, y: r), p + CGPoint(x: -r * 0.7, y: 0)], Night.glow)
        }
        // もや
        for e in sim.enemies {
            let p = s(e.pos)
            guard p.x > -80, p.y > -80, p.x < size.width + 80, p.y < size.height + 80 else { continue }
            let wob = sin(t * 5 + e.wobble) * e.radius * 0.08
            let body = e.flash > 0.5 ? Color.white : e.kind == .dart ? Color(hex: 0xC48BE8) : e.kind == .lump ? Night.mistDeep : e.kind == .shade ? Color(hex: 0x3C2470) : Night.mist
            Paint.glow(ctx, p, e.radius * 1.9, body, 0.3)
            Paint.ellipse(ctx, p, e.radius + wob, e.radius - wob, body.opacity(0.9))
            // すそ（3 つの小さな山）
            for k in 0..<3 {
                Paint.circle(ctx, p + CGPoint(x: (Double(k) - 1) * e.radius * 0.6, y: e.radius * 0.75), e.radius * 0.32, body.opacity(0.9))
            }
            let eye = e.kind == .shade ? Night.danger : Night.amber
            Paint.circle(ctx, p + CGPoint(x: -e.radius * 0.32, y: -e.radius * 0.1), max(1.6, e.radius * 0.14), eye)
            Paint.circle(ctx, p + CGPoint(x: e.radius * 0.32, y: -e.radius * 0.1), max(1.6, e.radius * 0.14), eye)
            if e.kind == .shade || e.kind == .lump {
                let w = e.radius * 1.6
                Paint.rect(ctx, CGRect(x: p.x - w / 2, y: p.y - e.radius - 12, width: w, height: 4), Night.panel, corner: 2)
                Paint.rect(ctx, CGRect(x: p.x - w / 2, y: p.y - e.radius - 12, width: w * max(0, e.hp / e.maxHP), height: 4), Night.danger, corner: 2)
            }
        }
        // 弾
        for shot in sim.shots {
            let p = s(shot.pos)
            switch shot.kind {
            case .spark, .fireball:
                Paint.glow(ctx, p, shot.radius * 3, Night.amber, 0.5)
                Paint.circle(ctx, p, shot.radius, shot.kind == .fireball ? Night.amberDeep : Color(hex: 0xFFE7B0))
            case .shell, .conch:
                Paint.circle(ctx, p, shot.radius, Material.shell.color)
                Paint.circle(ctx, p, shot.radius * 0.45, .white.opacity(0.8))
            case .arrow:
                let tail = p - shot.vel.normalized * 16
                Paint.line(ctx, tail, p, Color(hex: 0xE9D8B4), 2.5)
            case .firefly:
                Paint.glow(ctx, p, 14, Color(hex: 0xE8F27A), 0.6)
                Paint.circle(ctx, p, 3, Color(hex: 0xF4FFB0))
            case .pebble:
                Paint.circle(ctx, p, shot.radius, Material.stone.color)
            }
        }
        // 光の玉
        for o in sim.orbPositions() {
            Paint.glow(ctx, s(o), 22, Night.amber, 0.6)
            Paint.circle(ctx, s(o), 7, Material.flower.color)
        }
        // 仲間と自分
        for b in sim.buddies {
            CreatureArt.draw(id: b.helper.id, color: b.helper.color, accent: b.helper.accent, ctx: ctx, c: s(b.pos) + CGPoint(x: 0, y: -b.swing * 5), size: 11, swing: b.swing, night: true)
        }
        CreatureArt.player(ctx: ctx, c: s(sim.player), s: 15, facing: sim.facing, hurt: sim.shake > 0.3, t: t)
        // 輪（はじける・鐘・星・レベルアップ）
        for r in sim.rings {
            let k = 1 - r.life / r.maxLife
            let color: Color = switch r.kind {
            case .pop: Night.mist
            case .bell: Night.amber
            case .star: Color(hex: 0xFFF2A8)
            case .levelUp: Night.glow
            case .hurt: Night.danger
            }
            let rad = r.radius * (0.4 + 0.6 * k)
            ctx.stroke(Path(ellipseIn: CGRect(x: s(r.pos).x - rad, y: s(r.pos).y - rad, width: rad * 2, height: rad * 2)), with: .color(color.opacity(1 - k)), lineWidth: r.kind == .pop ? 2 : 4)
        }
        // 闇（灯りの届かない所は暗い）
        ctx.drawLayer { layer in
            layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Night.sky.opacity(0.78)))
            layer.blendMode = .destinationOut
            var lights: [(CGPoint, Double)] = [(s(sim.player), sim.light)]
            if sim.loadout.lv(.bonfire) > 0 { lights.append((s(sim.bonfire), sim.bonfireRadius * 1.2)) }
            if sim.loadout.lv(.lighthouse) > 0 { lights.append((s(sim.lighthouse), 120)) }
            if let boat = sim.boatPos { lights.append((s(boat), 90)) }
            for (p, r) in lights {
                layer.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                           with: .radialGradient(Gradient(colors: [.black, .black, .black.opacity(0)]), center: p, startRadius: 0, endRadius: r))
            }
        }
        // 赤い縁（体力が少ない）
        if sim.hp < sim.maxHP * 0.3 {
            ctx.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(Night.danger.opacity(0.35)), lineWidth: 14)
        }
        // スティック
        if let o = engine.stickOrigin, let p = engine.stickPoint {
            ctx.stroke(Path(ellipseIn: CGRect(x: o.x - 56, y: o.y - 56, width: 112, height: 112)), with: .color(Night.text.opacity(0.25)), lineWidth: 2)
            let d = p - o
            let knob = o + d.normalized * min(56, d.length)
            Paint.circle(ctx, knob, 22, Night.text.opacity(0.35))
        }
    }
}
