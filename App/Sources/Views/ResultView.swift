import SwiftUI

/// 夜の終わり：夜明け（生きのびた）か、もやにのまれたか
struct ResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let o = model.lastOutcome ?? NightOutcome(night: 1, seconds: 0, kills: 0, sand: 0, survived: false, endless: false, retreated: true)
        let dawn = o.survived
        ZStack {
            DawnSky(dawn: dawn).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: 30)
                    Text(title(o))
                        .font(Fonts.title(40))
                        .kerning(1)
                        .foregroundStyle(dawn ? Day.ink : Night.text)
                        .multilineTextAlignment(.center)
                        .scaleEffect(shown || reduceMotion ? 1 : 0.6)
                        .opacity(shown || reduceMotion ? 1 : 0)
                    Text(detail(o))
                        .font(Fonts.body(15))
                        .foregroundStyle(dawn ? Day.inkSoft : Night.textSoft)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        ResultTile(value: Clock.text(o.seconds), label: tr("生きのびた", "Survived"), dawn: dawn, best: model.lastWasBest)
                        ResultTile(value: "\(o.kills)", label: tr("払ったもや", "Mist cleared"), dawn: dawn, best: false)
                    }
                    HStack(spacing: 10) {
                        MaterialIcon(material: .glow, size: 30)
                        Text(trf("光る砂 +%d", "Glowsand +%d", model.lastGlow))
                            .font(Fonts.number(24))
                            .foregroundStyle(dawn ? Day.ink : Night.glow)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 56)
                    .background(Capsule().fill(dawn ? Day.paper.opacity(0.85) : Night.panel))
                    if let next = suggestion() {
                        HStack(spacing: 10) {
                            StructureIcon(kind: next.kind, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trf("次は「%@」を作れる", "Next up: %@", next.name)).font(Fonts.head(14)).foregroundStyle(Day.ink)
                                Text(trf("夜：%@", "Night: %@", next.night)).font(Fonts.body(12)).foregroundStyle(Day.inkSoft)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Day.paper.opacity(0.9)))
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(tr("昼の島にもどる", "Back to the island")) { model.backToDay() }
                .buttonStyle(ChunkyButtonStyle(fill: Day.coralDeep, edge: Color(hex: 0xA94434)))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .accessibilityIdentifier("main.backToDay")
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) { shown = true }
        }
    }

    private func title(_ o: NightOutcome) -> String {
        if o.endless { return tr("長い夜が明けた", "The long night ends") }
        if o.survived { return tr("夜明け！", "Dawn!") }
        if o.retreated { return tr("昼にもどった", "Back to daylight") }
        return tr("もやにのまれた…", "Swallowed by mist…")
    }

    private func detail(_ o: NightOutcome) -> String {
        if o.endless { return trf("終わらない夜を %@ 生きのびた", "You lasted %@ in the Endless Night", Clock.text(o.seconds)) }
        if o.survived { return trf("第 %d 夜を越えた。島がまた少し強くなる", "Night %d survived. The island grows stronger.", o.night) }
        return tr("集めた砂で島を作り直して、もう一度", "Build with the sand you gathered, then try again")
    }

    /// いま作れる、まだ作っていない物（夜の結果から、昼の次の一歩へ）
    private func suggestion() -> Recipe? {
        let save = model.save
        return Content.recipes.first { r in
            (!r.pro || model.isPro) && save.level(r.kind) < Recipe.maxLevel && save.canAfford(r.cost(toLevel: save.level(r.kind) + 1))
        }
    }
}

struct ResultTile: View {
    let value: String
    let label: String
    let dawn: Bool
    let best: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(Fonts.number(34)).kerning(-1).foregroundStyle(dawn ? Day.ink : Night.amber)
            Text(label).font(Fonts.label(12)).foregroundStyle(dawn ? Day.inkSoft : Night.textSoft)
            if best {
                Text(tr("新記録", "New best")).font(Fonts.label(11)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Day.coralDeep))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(dawn ? Day.paper.opacity(0.85) : Night.panel))
        .accessibilityElement(children: .combine)
    }
}

/// 夜明けの空（題材に理由があるので、ここだけグラデーション）
struct DawnSky: View {
    let dawn: Bool

    var body: some View {
        Canvas { ctx, size in
            let colors: [Color] = dawn
                ? [Color(hex: 0xFFD9B8), Color(hex: 0xFDE3DA), Day.foam, Day.sea]
                : [Night.sky, Color(hex: 0x231544), Night.sea]
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let horizon = size.height * 0.62
            if dawn {
                Paint.glow(ctx, CGPoint(x: size.width / 2, y: horizon), size.width * 0.6, Day.sun, 0.7)
                Paint.circle(ctx, CGPoint(x: size.width / 2, y: horizon), 46, Day.sun)
            } else {
                var rng = SeededRandom(seed: 5)
                for _ in 0..<40 {
                    Paint.circle(ctx, CGPoint(x: rng.unit() * size.width, y: rng.unit() * horizon), 1.3, Night.text.opacity(0.6))
                }
            }
            // 水平線の島の影
            var isle = Path()
            isle.move(to: CGPoint(x: size.width * 0.2, y: horizon + 10))
            isle.addQuadCurve(to: CGPoint(x: size.width * 0.8, y: horizon + 10), control: CGPoint(x: size.width * 0.5, y: horizon - 60))
            isle.closeSubpath()
            ctx.fill(isle, with: .color(dawn ? Day.grassDeep : Night.island))
            Paint.rect(ctx, CGRect(x: 0, y: horizon + 8, width: size.width, height: size.height - horizon), dawn ? Day.sea : Night.sea)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
