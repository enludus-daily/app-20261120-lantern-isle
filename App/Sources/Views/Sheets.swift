import StoreKit
import SwiftUI

/// 下から出る紙の面の共通の枠（見出し・閉じる）
struct SheetFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    let subtitle: String
    var dark = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Fonts.title(24)).foregroundStyle(dark ? Night.text : Day.ink)
                    Text(subtitle).font(Fonts.body(13)).foregroundStyle(dark ? Night.textSoft : Day.inkSoft)
                }
                Spacer()
                Button {
                    model.press()
                    model.activeSheet = nil
                } label: {
                    Text(tr("閉じる", "Close"))
                        .font(Fonts.head(14))
                        .foregroundStyle(dark ? Night.text : Day.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Capsule().fill(dark ? Night.island : Day.sand))
                }
                .buttonStyle(SquishStyle())
                .accessibilityIdentifier("main.closeSheet")
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 12)
            ScrollView {
                content()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
            }
        }
        .background((dark ? Night.sky : Day.paper).ignoresSafeArea())
    }
}

// MARK: - 作る

struct CraftSheet: View {
    var body: some View {
        SheetFrame(title: tr("作る", "Build"), subtitle: tr("昼に作った物が、夜の力になる", "What you build by day fights for you at night")) {
            CraftList(compact: false)
        }
    }
}

struct CraftList: View {
    @Environment(AppModel.self) private var model
    let compact: Bool

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(Content.recipes) { r in
                CraftRow(recipe: r)
            }
        }
    }
}

struct CraftRow: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe

    var body: some View {
        let save = model.save
        let level = save.level(recipe.kind)
        let locked = recipe.pro && !model.isPro
        let maxed = level >= Recipe.maxLevel
        let cost = recipe.cost(toLevel: min(Recipe.maxLevel, level + 1))
        let ready = !locked && !maxed && save.canAfford(cost)
        HStack(alignment: .center, spacing: 12) {
            StructureIcon(kind: recipe.kind, level: max(1, level), size: 56)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(level > 0 ? Day.grass.opacity(0.45) : Day.sand))
                .opacity(locked ? 0.55 : 1)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(recipe.name).font(Fonts.head(15)).foregroundStyle(Day.ink)
                    if recipe.pro {
                        Text("Pro").font(Fonts.label(10)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Night.mistDeep))
                    }
                    if level > 0 {
                        Text(trf("Lv %d", "Lv %d", level)).font(Fonts.label(11)).foregroundStyle(Day.coralDeep)
                    }
                }
                Text(trf("夜：%@", "Night: %@", recipe.night))
                    .font(Fonts.body(12))
                    .foregroundStyle(Day.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if !maxed && !locked { CostRow(cost: cost) }
            }
            Spacer(minLength: 0)
            Button {
                model.build(recipe)
            } label: {
                Text(locked ? tr("Pro", "Pro") : maxed ? tr("最大", "Max") : level == 0 ? tr("作る", "Build") : tr("強く", "Upgrade"))
                    .font(Fonts.head(13))
                    .foregroundStyle(ready || locked ? .white : Day.inkSoft)
                    .frame(width: 70, height: 40)
                    .background(Capsule().fill(locked ? Night.mistDeep : ready ? Day.coralDeep : Day.sand))
            }
            .buttonStyle(SquishStyle())
            .disabled(maxed)
            // 流れのテストで押す 1 つだけ main. の印（一覧の下の方は画面の外にあるため）
            .accessibilityIdentifier(recipe.kind == .lighthouse ? "main.build_lighthouse" : "build_" + recipe.id)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(.white.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Day.line, lineWidth: 1))
    }
}

// MARK: - 住人

struct ResidentsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SheetFrame(title: tr("住人", "Islanders"), subtitle: tr("頼みごとをかなえると、夜の仲間になる", "Grant their wishes and they'll join you at night")) {
            LazyVStack(spacing: 10) {
                ForEach(Content.residents) { r in
                    ResidentRow(resident: r)
                }
            }
        }
    }
}

struct ResidentRow: View {
    @Environment(AppModel.self) private var model
    let resident: Resident

    var body: some View {
        let save = model.save
        let steps = save.steps(resident)
        let locked = resident.pro && !model.isPro
        let req = save.currentRequest(resident)
        let ready = !locked && req.map { save.canAfford($0.need) } == true
        HStack(alignment: .top, spacing: 12) {
            ResidentIcon(resident: resident, size: 56)
                .background(Circle().fill(steps > 0 ? Day.coralSoft : Day.sand))
                .opacity(locked ? 0.55 : 1)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(resident.name).font(Fonts.head(15)).foregroundStyle(Day.ink)
                    Text(resident.species).font(Fonts.label(11)).foregroundStyle(Day.inkSoft)
                    if resident.pro {
                        Text("Pro").font(Fonts.label(10)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Night.mistDeep))
                    }
                }
                HStack(spacing: 4) {
                    ForEach(0..<resident.requests.count, id: \.self) { k in
                        Circle().fill(k < steps ? Day.coralDeep : Day.sandDeep).frame(width: 7, height: 7)
                    }
                    Text(trf("夜：%@", "Night: %@", resident.helperText))
                        .font(Fonts.body(12)).foregroundStyle(Day.inkSoft)
                }
                if let req, !locked {
                    Text(trf("「%@」", "“%@”", req.line)).font(Fonts.body(13)).foregroundStyle(Day.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    CostRow(cost: req.need)
                } else if req == nil {
                    Text(tr("頼みごとはぜんぶかなえた", "All wishes granted")).font(Fonts.body(13)).foregroundStyle(Day.grassDeep)
                }
            }
            Spacer(minLength: 0)
            if req != nil {
                Button {
                    model.deliver(resident)
                } label: {
                    Text(locked ? "Pro" : tr("届ける", "Give"))
                        .font(Fonts.head(13))
                        .foregroundStyle(ready || locked ? .white : Day.inkSoft)
                        .frame(width: 70, height: 40)
                        .background(Capsule().fill(locked ? Night.mistDeep : ready ? Day.coralDeep : Day.sand))
                }
                .buttonStyle(SquishStyle())
                .accessibilityIdentifier("give_" + resident.id)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(.white.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Day.line, lineWidth: 1))
    }
}

// MARK: - 夜の記録

struct RecordsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let save = model.save
        SheetFrame(title: tr("夜の記録", "Night Log"), subtitle: tr("生きのびた時間が、毎晩ここにたまる", "Every night you survive adds up here"), dark: true) {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(value: "\(save.nightsCleared)", label: tr("夜明けを見た", "Dawns reached"))
                    StatTile(value: Clock.text(save.bestSeconds), label: tr("いちばん長い夜", "Longest night"))
                    StatTile(value: "\(save.streak)", label: trf("連続の日（最高 %d）", "Day streak (best %d)", save.bestStreak))
                    StatTile(value: "\(save.totalKills)", label: tr("払ったもや", "Mist cleared"))
                }
                NightBars(records: Array(save.nights.suffix(14)))
                    .frame(height: 150)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Night.panel))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(tr("終わらない夜", "Endless Night")).font(Fonts.head(17)).foregroundStyle(Night.text)
                        Text("Pro").font(Fonts.label(10)).foregroundStyle(Night.sky)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Night.amber))
                        Spacer()
                        Text(trf("最長 %@", "Best %@", Clock.text(save.bestEndless))).font(Fonts.number(14)).foregroundStyle(Night.amber)
                    }
                    Text(tr("3 分で終わらない夜。150 秒ごとに大もやが来る", "No dawn. A Great Mist rises every 150 seconds."))
                        .font(Fonts.body(13)).foregroundStyle(Night.textSoft)
                    Button(model.isPro ? tr("終わらない夜へ", "Enter the Endless Night") : tr("Pro で遊べる", "Unlock with Pro")) {
                        model.startNight(endless: true)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Night.amberDeep, edge: Color(hex: 0xB8692A), height: 50))
                    .accessibilityIdentifier("endless")
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Night.panel))
            }
        }
    }
}

enum Clock {
    static func text(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Fonts.number(30)).foregroundStyle(Night.amber).kerning(-1)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(Fonts.label(12)).foregroundStyle(Night.textSoft).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Night.panel))
        .accessibilityElement(children: .combine)
    }
}

/// 夜ごとの生きのびた時間（夜明けまで行けた夜は琥珀色、途中で終わった夜は紫）
struct NightBars: View {
    let records: [NightRecord]

    var body: some View {
        if records.isEmpty {
            VStack(spacing: 6) {
                MoonGlyph().frame(width: 28, height: 28)
                Text(tr("まだ夜を越えていない。昼に灯りを作って、夜へ", "No nights yet. Build a light, then face the night."))
                    .font(Fonts.body(13)).foregroundStyle(Night.textSoft).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Canvas { ctx, size in
                let n = 14
                let w = size.width / Double(n)
                let top = max(NightSim.duration, records.map(\.seconds).max() ?? 0)
                for k in 0...3 {
                    let y = size.height - 16 - (size.height - 24) * Double(k) / 3
                    Paint.line(ctx, CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y), Night.rim.opacity(0.5), 0.6)
                }
                for (i, r) in records.enumerated() {
                    let h = (size.height - 24) * r.seconds / top
                    let x = Double(i) * w + w * 0.18
                    let rect = CGRect(x: x, y: size.height - 16 - h, width: w * 0.64, height: max(2, h))
                    Paint.rect(ctx, rect, r.endless ? Night.glow : r.survived ? Night.amber : Night.mistDeep, corner: 4)
                    ctx.draw(Text("\(r.night)").font(Fonts.label(9)).foregroundColor(Night.textSoft), at: CGPoint(x: x + w * 0.32, y: size.height - 6))
                }
            }
            .accessibilityElement()
            .accessibilityLabel(trf("最近 %d 回の夜。夜明けまで %d 回", "Last %d nights. %d reached dawn", records.count, records.filter(\.survived).count))
        }
    }
}

// MARK: - 設定

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SheetFrame(title: tr("設定", "Settings"), subtitle: tr("島の音と、手ざわり", "Sound and feel")) {
            VStack(spacing: 12) {
                SettingsGroup {
                    Toggle(tr("効果音", "Sound effects"), isOn: Binding(get: { model.soundOn }, set: { model.setSound($0) }))
                    Divider()
                    Toggle(tr("振動", "Haptics"), isOn: Binding(get: { model.hapticsOn }, set: { model.setHaptics($0) }))
                }
                SettingsGroup {
                    Button(tr("遊び方をもう一度見る", "Show the tutorial again")) {
                        model.activeSheet = nil
                        model.onboarded = false
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                SettingsGroup {
                    HStack {
                        Text(model.isPro ? tr("Pro：ありがとう！", "Pro: thank you!") : tr("灯り島 Pro", "Lantern Isle Pro"))
                        Spacer()
                        if !model.isPro {
                            Button(tr("見る", "See")) { model.activeSheet = .paywall }
                        }
                    }
                    Divider()
                    Button(tr("購入を復元", "Restore purchases")) {
                        Task { await model.purchases.restore() }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                SettingsGroup {
                    Text(tr("島のデータはこの端末の中だけにあり、外へ送りません。ログイン・広告・解析はありません。", "Your island lives only on this device. Nothing is sent anywhere — no login, ads or analytics."))
                        .font(Fonts.body(13))
                        .foregroundStyle(Day.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(Fonts.body(15))
            .tint(Day.coralDeep)
            .foregroundStyle(Day.ink)
        }
    }
}

struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 10) { content() }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Day.sand))
    }
}

// MARK: - Pro

struct PaywallSheet: View {
    @Environment(AppModel.self) private var model
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        let store = model.purchases
        let product = store.products.first
        SheetFrame(title: tr("灯り島 Pro", "Lantern Isle Pro"), subtitle: tr("一度買えば、ずっと。家族でも使える", "Buy once, keep forever. Family Sharing included."), dark: true) {
            VStack(alignment: .leading, spacing: 14) {
                ProFeature(title: tr("作り物が 6 つ増える", "6 more things to build"),
                           detail: tr("星の望遠鏡・ほら貝の大砲・ホタルのびん・灯りの小舟・雪あかり・祭りのやぐら。どれも夜の新しい戦い方になる", "Star Scope, Conch Cannon, Firefly Jar, Lantern Boat, Frost Lamp and Festival Tower — each a new way to fight the night")) {
                    HStack(spacing: 0) {
                        ForEach(Content.recipes.filter(\.pro)) { r in StructureIcon(kind: r.kind, phase: .night, size: 44) }
                    }
                }
                ProFeature(title: tr("住人が 3 人増える", "3 more islanders"),
                           detail: tr("火の玉を放つ砂ギツネ、遠くを射るメンフクロウ、守ってくれるヤドカリ", "A fox that throws fireballs, an owl that snipes from afar, a hermit crab that shields you")) {
                    HStack(spacing: 4) {
                        ForEach(Content.residents.filter(\.pro)) { r in ResidentIcon(resident: r, size: 48) }
                    }
                }
                ProFeature(title: tr("終わらない夜", "Endless Night"),
                           detail: tr("夜明けの来ない夜で、最長記録に挑む。150 秒ごとに大もや", "No dawn — chase your longest run. A Great Mist every 150 seconds")) {
                    EmptyView()
                }
                VStack(spacing: 8) {
                    Button {
                        guard let product else { return }
                        busy = true
                        Task {
                            let outcome = await store.purchase(product)
                            busy = false
                            switch outcome {
                            case .purchased: model.activeSheet = nil
                            case .pending: message = tr("承認を待っています", "Waiting for approval")
                            case .failed: message = tr("購入できませんでした。時間をおいてもう一度", "Purchase failed. Please try again later.")
                            case .cancelled: break
                            }
                        }
                    } label: {
                        Text(product.map { trf("%@ で Pro にする", "Get Pro for %@", $0.displayPrice) } ?? tr("いまは購入できません", "Not available right now"))
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Night.amberDeep, edge: Color(hex: 0xB8692A)))
                    .disabled(product == nil || busy || model.isPro)
                    .accessibilityIdentifier("main.buy")
                    if store.loadState == .unavailable {
                        Text(tr("App Store につながりません。通信を確かめて、あとでもう一度開いてください", "Can't reach the App Store. Check your connection and try again later."))
                            .font(Fonts.body(12)).foregroundStyle(Night.textSoft)
                    }
                    if let message { Text(message).font(Fonts.body(12)).foregroundStyle(Night.amber) }
                    Button(tr("購入を復元", "Restore purchases")) {
                        Task { await store.restore() }
                    }
                    .font(Fonts.head(14))
                    .foregroundStyle(Night.text)
                    .frame(minHeight: 44)
                    Text(tr("無料のままでも、12 の作り物・5 人の住人・毎日の潮と夜はずっと遊べます", "Free forever: 12 builds, 5 islanders, daily tides and nights."))
                        .font(Fonts.body(12)).foregroundStyle(Night.textSoft)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct ProFeature<Art: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let art: () -> Art

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Fonts.head(17)).foregroundStyle(Night.amber)
            Text(detail).font(Fonts.body(13)).foregroundStyle(Night.text).fixedSize(horizontal: false, vertical: true)
            art()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Night.panel))
    }
}
