import Foundation
import Observation
import SwiftUI

enum Screen: Equatable {
    case day, night, result
}

enum ActiveSheet: String, Identifiable {
    case craft, residents, records, settings, paywall
    var id: String { rawValue }
}

struct Banner: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

/// アプリの状態。保存は区切り（拾う・作る・届ける・夜の終わり・設定）でだけ行う（毎秒は保存しない）
@MainActor
@Observable
final class AppModel {
    var save: SaveData
    var screen: Screen = .day
    var activeSheet: ActiveSheet?
    var banner: Banner?
    var onboarded: Bool
    var soundOn: Bool
    var hapticsOn: Bool
    var paywallOffered: Bool
    var now: Date
    var calendar = Calendar.current
    /// 撮影（静止画）のとき true。動きと時計を止める
    var still = false
    var reduceMotion = false
    /// UI テストのとき true。昼の飾りの動きを止めて、待ちを短くする
    var calm = false
    var active = true
    var proOverride = false
    var lastOutcome: NightOutcome?
    var lastGlow = 0
    var lastWasBest = false
    var autopilot = false
    /// 作ったばかりの物（島の上で弾ませる）
    var justBuilt: Recipe.Kind?
    var justPicked: Int?

    // 手応え（増えたら鳴らす・震わせる）
    var pressTick = 0
    var pickTick = 0
    var buildTick = 0
    var deliverTick = 0
    var shortTick = 0
    var hurtTick = 0
    var levelTick = 0
    var shadeTick = 0
    var dawnTick = 0
    var fallTick = 0

    /// 夜の世界（毎フレーム変わるので観測しない。画面は TimelineView で描き直す）
    @ObservationIgnored var engine: NightEngine?
    /// レベルアップの札（出ている間は夜が止まる）
    var upgradeChoices: [Upgrade]?
    var nightRunning = false

    let purchases: PurchaseStore
    private let persists: Bool
    private let defaults = UserDefaults.standard
    private static let saveKey = "save"

    init(persists: Bool = true, now: Date = Date()) {
        self.persists = persists
        self.now = now
        let bundleID = Foundation.Bundle.main.bundleIdentifier ?? "com.enludus.daily.015"
        let pro = ProductID.pro(bundleID: bundleID)
        purchases = PurchaseStore(productIDs: [pro], proProductIDs: [pro])
        if persists, let data = defaults.data(forKey: Self.saveKey), let decoded = try? JSONDecoder().decode(SaveData.self, from: data) {
            save = decoded
        } else {
            save = SaveData()
        }
        onboarded = persists ? defaults.bool(forKey: "onboarded") : true
        soundOn = persists ? (defaults.object(forKey: "sound") as? Bool ?? true) : true
        hapticsOn = persists ? (defaults.object(forKey: "haptics") as? Bool ?? true) : true
        paywallOffered = persists ? defaults.bool(forKey: "paywallOffered") : false
    }

    var isPro: Bool { proOverride || purchases.entitlements.isPro }
    var todayKey: String { Days.key(now, calendar: calendar) }
    var yesterdayKey: String { Days.yesterday(now, calendar: calendar) }
    var pickups: [Pickup] { Tide.pickups(day: todayKey) }
    var tideBonus: Material { Tide.bonus(day: todayKey) }
    var pickedToday: [Int] { save.pickedDay == todayKey ? save.picked : [] }
    var pickupsLeft: Int { pickups.filter { !pickedToday.contains($0.id) }.count }
    var recipes: [Recipe] { Content.recipes }
    var residents: [Resident] { Content.residents }

    /// 頼みごとがかなえられる住人（昼の画面の吹き出し）
    var featuredResident: Resident? {
        let open = residents.filter { (!$0.pro || isPro) && save.currentRequest($0) != nil }
        return open.first { save.canAfford(save.currentRequest($0)?.need ?? [:]) } ?? open.first
    }

    func persist() {
        guard persists else { return }
        if let data = try? JSONEncoder().encode(save) { defaults.set(data, forKey: Self.saveKey) }
    }

    func setOnboarded() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { onboarded = true }
        if persists { defaults.set(true, forKey: "onboarded") }
    }

    func setSound(_ on: Bool) {
        soundOn = on
        if persists { defaults.set(on, forKey: "sound") }
    }

    func setHaptics(_ on: Bool) {
        hapticsOn = on
        if persists { defaults.set(on, forKey: "haptics") }
    }

    func play(_ cue: SoundBox.Cue) {
        guard soundOn, !still else { return }
        SoundBox.shared.play(cue)
    }

    func press() {
        pressTick += 1
        play(.tap)
    }

    func show(_ title: String, _ detail: String) {
        let b = Banner(title: title, detail: detail)
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) { banner = b }
        guard !still else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard let self, self.banner?.id == b.id else { return }
            withAnimation(self.reduceMotion ? nil : .easeOut(duration: 0.3)) { self.banner = nil }
        }
    }

    // MARK: - 昼

    func pick(_ p: Pickup) {
        guard save.pick(p, day: todayKey) else { return }
        pickTick += 1
        justPicked = p.id
        play(p.material == tideBonus ? .bonus : .pick)
        persist()
    }

    func build(_ recipe: Recipe) {
        switch save.build(recipe, pro: isPro) {
        case .built(let level):
            buildTick += 1
            justBuilt = recipe.kind
            play(.build)
            show(level == 1 ? trf("%@ ができた", "%@ built", recipe.name) : trf("%@ がレベル %d に", "%@ is now level %d", recipe.name, level),
                 trf("夜：%@", "Night: %@", recipe.night))
            persist()
        case .locked:
            press()
            activeSheet = .paywall
        case .short:
            shortTick += 1
            play(.short)
        case .maxed:
            break
        }
    }

    func deliver(_ r: Resident) {
        switch save.deliver(r, pro: isPro) {
        case .done(let step):
            deliverTick += 1
            play(.deliver)
            let req = r.requests[step - 1]
            if step == 1 {
                show(trf("%@ が引っ越してきた", "%@ moved in!", r.name), trf("夜の仲間：%@", "Night buddy: %@", r.helperText))
            } else {
                show(trf("%@ がよろこんだ", "%@ is delighted", r.name), trf("お礼：%@ ×%d", "Thanks: %@ ×%d", req.gift.name, req.giftAmount))
            }
            persist()
        case .locked:
            press()
            activeSheet = .paywall
        case .short:
            shortTick += 1
            play(.short)
        case .finished:
            break
        }
    }

    // MARK: - 夜

    func startNight(endless: Bool = false) {
        if endless && !isPro {
            press()
            activeSheet = .paywall
            return
        }
        activeSheet = nil
        let loadout = Loadout.from(save, endless: endless, pro: isPro)
        engine = NightEngine(sim: NightSim(loadout: loadout, seed: SeededRandom.seed(todayKey) &+ UInt64(save.nights.count)))
        upgradeChoices = nil
        nightRunning = true
        play(.dusk)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { screen = .night }
    }

    /// 夜の世界の変化を受け取る（NightEngine から 1 フレームに 1 回まで）
    func nightChanged(_ e: NightEngine.Events) {
        if e.hurt {
            hurtTick += 1
            play(.hurt)
        }
        if e.kills > 0 { play(.pop) }
        if e.bell { play(.bell) }
        if e.shade {
            shadeTick += 1
            play(.shade)
            show(tr("大もやが来た", "The Great Mist rises"), tr("灯りから離れないで", "Stay near the light"))
        }
        if let choices = e.levelUp {
            levelTick += 1
            play(.levelUp)
            upgradeChoices = choices
            if autopilot {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(900))
                    self?.chooseUpgrade(0)
                }
            }
        }
        if let outcome = e.outcome { endNight(outcome) }
    }

    func chooseUpgrade(_ i: Int) {
        guard let engine else { return }
        engine.sim.choose(i)
        engine.resume()
        upgradeChoices = nil
        press()
    }

    func retreat() {
        guard let engine, engine.sim.outcome == nil else { return }
        press()
        engine.sim.retreat()
        if let o = engine.sim.outcome { endNight(o) }
    }

    func endNight(_ outcome: NightOutcome) {
        guard nightRunning else { return }
        nightRunning = false
        upgradeChoices = nil
        let before = outcome.endless ? save.bestEndless : save.bestSeconds
        lastWasBest = outcome.seconds > before && outcome.seconds > 0
        lastGlow = save.record(outcome, day: todayKey, yesterday: yesterdayKey)
        lastOutcome = outcome
        persist()
        if outcome.survived {
            dawnTick += 1
            play(.dawn)
        } else if !outcome.retreated {
            fallTick += 1
            play(.fall)
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) { screen = .result }
    }

    func backToDay() {
        press()
        engine = nil
        let offer = lastOutcome?.survived == true && !isPro && !paywallOffered
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { screen = .day }
        if offer {
            // 最初の夜明けのあと、一度だけ課金の画面を出す（価値を感じた直後）
            paywallOffered = true
            if persists { defaults.set(true, forKey: "paywallOffered") }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                self?.activeSheet = .paywall
            }
        }
    }
}

/// 夜の世界を進める（毎フレーム。SwiftUI の観測には乗せない）
@MainActor
final class NightEngine {
    struct Events {
        var hurt = false
        var kills = 0
        var bell = false
        var shade = false
        var levelUp: [Upgrade]?
        var outcome: NightOutcome?
        var any: Bool { hurt || kills > 0 || bell || shade || levelUp != nil || outcome != nil }
    }

    var sim: NightSim
    var stickOrigin: CGPoint?
    var stickPoint: CGPoint?
    private var last: Date?
    private var reported = (hurt: 0, kills: 0, bell: 0, shade: 0, level: 0)
    private var popBudget = 0.0

    init(sim: NightSim) { self.sim = sim }

    func resume() { last = nil }

    func setStick(origin: CGPoint, point: CGPoint) {
        stickOrigin = origin
        stickPoint = point
        let d = point - origin
        let l = d.length
        sim.input = l < 6 ? .zero : d.normalized * min(1, l / 56)
    }

    func releaseStick() {
        stickOrigin = nil
        stickPoint = nil
        sim.input = .zero
    }

    /// 画面の時計に合わせて進める。変化があれば返す
    func advance(to date: Date, autopilot: Bool) -> Events? {
        defer { last = date }
        guard let last, !sim.paused else { return nil }
        var dt = date.timeIntervalSince(last)
        if dt <= 0 { return nil }
        dt = min(dt, 1.0 / 20)
        if autopilot { sim.input = sim.autoInput() }
        while dt > 0.0001 && !sim.paused {
            let h = min(dt, 1.0 / 60)
            sim.step(h)
            dt -= h
        }
        popBudget = min(1, popBudget + 0.12)
        var e = Events()
        e.hurt = sim.hurtCount != reported.hurt
        if sim.kills != reported.kills && popBudget >= 1 {
            e.kills = sim.kills - reported.kills
            reported.kills = sim.kills
            popBudget = 0
        }
        e.bell = sim.bellCount != reported.bell
        e.shade = sim.shadeCount != reported.shade
        if sim.levelUpCount != reported.level { e.levelUp = sim.pendingUpgrades }
        e.outcome = sim.outcome
        reported.hurt = sim.hurtCount
        reported.bell = sim.bellCount
        reported.shade = sim.shadeCount
        reported.level = sim.levelUpCount
        return e.any ? e : nil
    }
}
