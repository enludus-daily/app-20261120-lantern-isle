import SwiftUI

/// 昼の島：浜で拾う → 作る → 住人の頼みごと → 夜へ
struct DayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            SeaBackground().ignoresSafeArea()
            VStack(spacing: 10) {
                DayHeader()
                MaterialStrip()
                if sizeClass == .regular {
                    // iPhone Duo の内側など：島を大きく、横に頼みごとと作り物の一覧
                    HStack(alignment: .top, spacing: 16) {
                        IslandBoard()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        ScrollView {
                            VStack(spacing: 12) {
                                if let r = model.featuredResident { RequestCard(resident: r) }
                                CraftList(compact: true)
                            }
                            .padding(.bottom, 12)
                        }
                        .frame(width: 360)
                    }
                } else {
                    IslandBoard()
                        .frame(maxHeight: .infinity)
                    if let r = model.featuredResident {
                        RequestCard(resident: r)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .safeAreaInset(edge: .bottom) { DayBar() }
    }
}

/// 海（ターコイズの面と、静かな波の線）
struct SeaBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Day.foam, Day.sea]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var rng = SeededRandom(seed: 3)
            for _ in 0..<26 {
                let x = rng.unit() * size.width
                let y = rng.unit() * size.height
                let w = 14 + rng.unit() * 22
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addQuadCurve(to: CGPoint(x: x + w, y: y), control: CGPoint(x: x + w / 2, y: y - 5))
                ctx.stroke(p, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct DayHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("灯り島", "Lantern Isle"))
                    .font(Fonts.title(26))
                    .foregroundStyle(Day.ink)
                Text(trf("次は第 %d 夜 · 夜明け %d 回 · 連続 %d 日", "Next: Night %d · %d dawns · %d-day streak", model.save.nextNight, model.save.nightsCleared, model.save.streak))
                    .font(Fonts.label(12))
                    .foregroundStyle(Day.inkSoft)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            RoundIconButton(id: "main.records", label: tr("夜の記録", "Night Log"), action: {
                model.press()
                model.activeSheet = .records
            }) { BarsGlyph() }
            RoundIconButton(id: "main.settings", label: tr("設定", "Settings"), action: {
                model.press()
                model.activeSheet = .settings
            }) { GearGlyph() }
        }
    }
}

/// 丸いアイコンのボタン（中の絵は自作）
struct RoundIconButton<Glyph: View>: View {
    let id: String
    let label: String
    let action: () -> Void
    @ViewBuilder let glyph: () -> Glyph

    var body: some View {
        Button(action: action) {
            glyph()
                .frame(width: 20, height: 20)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Day.paper))
                .overlay(Circle().stroke(Day.line, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(SquishStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

struct BarsGlyph: View {
    var body: some View {
        Canvas { ctx, s in
            let w = s.width / 5
            for (i, h) in [0.45, 0.8, 0.6].enumerated() {
                Paint.rect(ctx, CGRect(x: w * (0.5 + Double(i) * 1.6), y: s.height * (1 - h), width: w, height: s.height * h), Day.coralDeep, corner: 2)
            }
        }
    }
}

struct GearGlyph: View {
    var body: some View {
        Canvas { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            for k in 0..<8 {
                Paint.line(ctx, c, c + CGPoint.polar(Double(k) / 8 * 2 * .pi, s.width * 0.48), Day.inkSoft, 4)
            }
            Paint.circle(ctx, c, s.width * 0.34, Day.inkSoft)
            Paint.circle(ctx, c, s.width * 0.14, Day.paper)
        }
    }
}

/// 素材の数
struct MaterialStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Material.allCases) { m in
                HStack(spacing: 4) {
                    MaterialIcon(material: m, size: 16)
                    Text("\(model.save.amount(m))")
                        .font(Fonts.number(14))
                        .foregroundStyle(Day.ink)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(m == model.tideBonus ? Day.coralSoft : Day.paper.opacity(0.92)))
                .overlay(Capsule().stroke(m == .glow ? Night.mistDeep.opacity(0.35) : Day.line, lineWidth: 1))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(m.name) \(model.save.amount(m))")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: model.save.materials)
    }
}

/// 主役：昼の島（自作の Canvas）。浜の拾い物は上に置いた小さなボタン
struct IslandBoard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height / IslandMap.tilt * 0.98)
            let rect = CGRect(x: (geo.size.width - side) / 2, y: (geo.size.height - side) / 2, width: side, height: side)
            let map = IslandMap(rect: rect)
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: 1.0 / 24, paused: model.still || model.calm || reduceMotion || !model.active)) { tl in
                    Canvas { ctx, _ in
                        let t = model.still ? 1.3 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
                        DayIslandPainter.draw(ctx: ctx, map: map, model: model, t: t)
                    }
                }
                .allowsHitTesting(false)
                ForEach(model.pickups.filter { !model.pickedToday.contains($0.id) }) { p in
                    let q = map.project(p.pos)
                    Button {
                        model.pick(p)
                    } label: {
                        Color.clear.frame(width: 44, height: 44).contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(q)
                    .accessibilityLabel(trf("%@ ×%d を拾う", "Pick up %@ ×%d", p.material.name, p.amount))
                    .accessibilityIdentifier("main.pickup\(p.id)")
                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6), value: model.pickedToday)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(trf("島。作った物 %d、住人 %d 人、浜の拾い物 %d", "The island. %d built, %d residents, %d beach finds",
                                model.save.levels.count, model.save.residentSteps.filter { $0.value > 0 }.count, model.pickupsLeft))
    }
}

enum DayIslandPainter {
    @MainActor
    static func draw(ctx: GraphicsContext, map: IslandMap, model: AppModel, t: Double) {
        let u = map.unit
        // 浅瀬・島の厚み・砂・草
        ctx.fill(map.islandPath(scale: 1.14), with: .color(Day.foam.opacity(0.8)))
        ctx.fill(map.islandPath(scale: 1.0, lift: u * 0.35), with: .color(Day.sandDeep))
        ctx.fill(map.islandPath(scale: 1.0), with: .color(Day.sand))
        ctx.fill(map.islandPath(scale: 0.78), with: .color(Day.grass))
        ctx.stroke(map.islandPath(scale: 0.78), with: .color(Day.grassDeep.opacity(0.5)), lineWidth: 1.2)
        // 波打ち際
        ctx.stroke(map.islandPath(scale: 1.05), with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 7], dashPhase: t * 6))
        // ヤシの木（飾り）
        for (a, s) in [(2.4, 1.0), (4.0, 0.85), (0.6, 0.9)] {
            let base = map.project(IslandShape.point(a, scale: 0.72))
            palm(ctx, base, u * s, t)
        }
        let save = model.save
        // まだ作っていない場所：点線の輪
        for r in Content.recipes where save.level(r.kind) == 0 && (!r.pro || model.isPro) {
            let c = map.project(r.plot)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - u * 0.45, y: c.y - u * 0.18, width: u * 0.9, height: u * 0.36)),
                       with: .color(Day.grassDeep.opacity(0.7)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        }
        // 作った物と住人を、奥から手前の順に描く
        enum Item { case structure(Recipe), resident(Resident) }
        var items: [(Double, Item)] = []
        for r in Content.recipes where save.level(r.kind) > 0 { items.append((r.plot.y, .structure(r))) }
        for r in Content.residents where save.movedIn(r) || r.id == model.featuredResident?.id { items.append((r.home.y, .resident(r))) }
        for (_, item) in items.sorted(by: { $0.0 < $1.0 }) {
            switch item {
            case .structure(let r):
                let c = map.project(r.plot)
                StructureArt.draw(r.kind, level: save.level(r.kind), ctx: ctx, base: c, u: u, phase: .day, t: t)
                levelDots(ctx, c + CGPoint(x: 0, y: u * 0.32), save.level(r.kind), u)
            case .resident(let r):
                let bob = sin(t * 2.2 + r.home.x * 9) * u * 0.06
                let c = map.project(r.home) + CGPoint(x: 0, y: -u * 0.3 + bob)
                CreatureArt.draw(r, ctx: ctx, c: c, size: u * 0.27)
            }
        }
        // 頼みごとの吹き出し
        if let f = model.featuredResident {
            let c = map.project(f.home) + CGPoint(x: u * 0.45, y: -u * 0.95)
            let ready = save.canAfford(save.currentRequest(f)?.need ?? [:])
            do {
                Paint.rect(ctx, CGRect(x: c.x - u * 0.28, y: c.y - u * 0.24, width: u * 0.56, height: u * 0.44), Day.paper, corner: u * 0.16)
                Paint.poly(ctx, [c + CGPoint(x: -u * 0.12, y: u * 0.18), c + CGPoint(x: -u * 0.3, y: u * 0.38), c + CGPoint(x: u * 0.02, y: u * 0.18)], Day.paper)
                ctx.draw(Text(ready ? "!" : "…").font(Fonts.title(u * 0.32)).foregroundColor(ready ? Day.coralDeep : Day.inkSoft), at: c + CGPoint(x: 0, y: -u * 0.02))
            }
        }
        // 浜の拾い物（きらり）
        let picked = model.pickedToday
        for p in model.pickups where !picked.contains(p.id) {
            let c = map.project(p.pos)
            let pulse = 0.5 + 0.5 * sin(t * 3 + Double(p.id))
            Paint.circle(ctx, c, u * 0.3, .white.opacity(0.35 + 0.25 * pulse))
            pickupGlyph(ctx, c, p.material, u * 0.2)
            if p.material == model.tideBonus {
                Paint.circle(ctx, c + CGPoint(x: u * 0.22, y: -u * 0.22), u * 0.07, Day.coral)
            }
        }
    }

    static func levelDots(_ ctx: GraphicsContext, _ c: CGPoint, _ level: Int, _ u: Double) {
        for k in 0..<Recipe.maxLevel {
            let x = (Double(k) - 1) * u * 0.14
            Paint.circle(ctx, c + CGPoint(x: x, y: 0), u * 0.045, k < level ? Day.coralDeep : Day.sandDeep)
        }
    }

    static func palm(_ ctx: GraphicsContext, _ b: CGPoint, _ u: Double, _ t: Double) {
        var trunk = Path()
        trunk.move(to: b)
        trunk.addQuadCurve(to: b + CGPoint(x: u * 0.25, y: -u * 1.1), control: b + CGPoint(x: u * 0.3, y: -u * 0.5))
        ctx.stroke(trunk, with: .color(Color(hex: 0xA77B55)), style: StrokeStyle(lineWidth: u * 0.12, lineCap: .round))
        let top = b + CGPoint(x: u * 0.25, y: -u * 1.1)
        for k in 0..<5 {
            let a = -.pi / 2 + (Double(k) - 2) * 0.62 + sin(t * 1.2) * 0.04
            let tip = top + CGPoint.polar(a, u * 0.55)
            var leaf = Path()
            leaf.move(to: top)
            leaf.addQuadCurve(to: tip + CGPoint(x: 0, y: u * 0.15), control: top + CGPoint.polar(a, u * 0.3) + CGPoint(x: 0, y: -u * 0.15))
            ctx.stroke(leaf, with: .color(Day.grassDeep), style: StrokeStyle(lineWidth: u * 0.13, lineCap: .round))
        }
    }

    static func pickupGlyph(_ ctx: GraphicsContext, _ c: CGPoint, _ m: Material, _ s: Double) {
        switch m {
        case .shell:
            var p = Path()
            p.move(to: c + CGPoint(x: 0, y: s * 0.8))
            p.addLine(to: c + CGPoint(x: -s * 0.9, y: -s * 0.2))
            p.addQuadCurve(to: c + CGPoint(x: s * 0.9, y: -s * 0.2), control: c + CGPoint(x: 0, y: -s * 1.3))
            p.closeSubpath()
            ctx.fill(p, with: .color(m.color))
        case .wood:
            Paint.rect(ctx, CGRect(x: c.x - s, y: c.y - s * 0.35, width: s * 2, height: s * 0.7), m.color, corner: s * 0.35)
        case .flower:
            for k in 0..<5 { Paint.circle(ctx, c + CGPoint.polar(Double(k) / 5 * 2 * .pi, s * 0.5), s * 0.38, m.color) }
            Paint.circle(ctx, c, s * 0.3, Day.sun)
        case .stone:
            Paint.ellipse(ctx, c, s * 0.9, s * 0.65, m.color)
        case .glow:
            Paint.circle(ctx, c, s * 0.6, m.color)
        }
    }
}

/// 住人の頼みごと（昼の画面の下）
struct RequestCard: View {
    @Environment(AppModel.self) private var model
    let resident: Resident

    var body: some View {
        let save = model.save
        let req = save.currentRequest(resident)
        let ready = req.map { save.canAfford($0.need) } ?? false
        HStack(alignment: .center, spacing: 12) {
            ResidentIcon(resident: resident, size: 52)
                .background(Circle().fill(Day.coralSoft))
            VStack(alignment: .leading, spacing: 4) {
                Text(save.movedIn(resident) ? resident.name : trf("%@（引っ越し前）", "%@ (wants to move in)", resident.name))
                    .font(Fonts.head(15))
                    .foregroundStyle(Day.ink)
                Text(req?.line ?? "")
                    .font(Fonts.body(13))
                    .foregroundStyle(Day.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let req { CostRow(cost: req.need) }
            }
            Spacer(minLength: 0)
            Button {
                model.deliver(resident)
            } label: {
                Text(tr("届ける", "Give"))
                    .font(Fonts.head(14))
                    .foregroundStyle(ready ? .white : Day.inkSoft)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Capsule().fill(ready ? Day.coralDeep : Day.sandDeep))
            }
            .buttonStyle(SquishStyle())
            .accessibilityIdentifier("main.deliver")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Day.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Day.line, lineWidth: 1))
    }
}

/// 材料の並び（足りないものはサンゴ色で）
struct CostRow: View {
    @Environment(AppModel.self) private var model
    let cost: [Material: Int]
    var dark = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(cost.ordered, id: \.0) { pair in
                let m = pair.0
                let n = pair.1
                let have = model.save.amount(m)
                HStack(spacing: 3) {
                    MaterialIcon(material: m, size: 14)
                    Text("\(min(have, n))/\(n)")
                        .font(Fonts.label(12))
                        .monospacedDigit()
                        .foregroundStyle(have >= n ? (dark ? Night.text : Day.ink) : Day.coralDeep)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(trf("%@ %d / %d", "%@ %d of %d", m.name, min(have, n), n))
            }
        }
    }
}

/// 画面の下に固定するボタン
struct DayBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Button(tr("作る", "Build")) {
                model.press()
                model.activeSheet = .craft
            }
            .buttonStyle(ChunkyButtonStyle(fill: Day.paper, edge: Day.sandDeep, text: Day.ink))
            .accessibilityIdentifier("main.craft")
            Button(tr("住人", "Islanders")) {
                model.press()
                model.activeSheet = .residents
            }
            .buttonStyle(ChunkyButtonStyle(fill: Day.paper, edge: Day.sandDeep, text: Day.ink))
            .accessibilityIdentifier("main.residents")
            Button {
                model.startNight()
            } label: {
                HStack(spacing: 6) {
                    MoonGlyph().frame(width: 18, height: 18)
                    Text(tr("夜へ", "Nightfall"))
                }
            }
            .buttonStyle(ChunkyButtonStyle(fill: Night.mistDeep, edge: Night.island))
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            .accessibilityIdentifier("main.night")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Day.sand.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }
}

struct MoonGlyph: View {
    var body: some View {
        Canvas { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            Paint.circle(ctx, c, s.width * 0.45, Night.amber)
            Paint.circle(ctx, c + CGPoint(x: s.width * 0.2, y: -s.width * 0.15), s.width * 0.38, Night.mistDeep)
        }
        .accessibilityHidden(true)
    }
}
