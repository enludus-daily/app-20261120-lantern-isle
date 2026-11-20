import SwiftUI

@main
struct LanternIsleApp: App {
    /// アプリ全体で 1 つだけ（App の init は何度も呼ばれることがあるので、ここで作り直さない）
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if !model.onboarded {
                OnboardingView()
                    .transition(.opacity)
            } else {
                switch model.screen {
                case .day:
                    DayView().transition(.opacity)
                case .night:
                    NightView().transition(.opacity)
                case .result:
                    ResultView().transition(.opacity)
                }
            }
            if let b = model.banner {
                VStack {
                    BannerView(banner: b, night: model.screen == .night)
                        .padding(.top, model.screen == .night ? 56 : 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .allowsHitTesting(false)
                .zIndex(10)
                .id(b.id)
            }
        }
        .environment(model)
        // 昼の島は明るい砂浜、夜は自前の暗い色で描くので、画面はライトに固定する（色は Theme で昼と夜を分けている）
        .preferredColorScheme(.light)
        .sheet(item: $model.activeSheet) { sheet in
            SheetContent(sheet: sheet)
                .environment(model)
                .environment(\.locale, Lang.locale)
                .presentationCornerRadius(Radius.sheet)
        }
        // 手応えの表（README）：押す・拾う・作る・届ける・足りない・痛い・レベルアップ・大もや・夜明け・のまれる
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.pickTick) { _, _ in model.hapticsOn ? .impact(weight: .light, intensity: 0.7) : nil }
        .sensoryFeedback(trigger: model.buildTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: model.deliverTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.shortTick) { _, _ in model.hapticsOn ? .warning : nil }
        .sensoryFeedback(trigger: model.hurtTick) { _, _ in model.hapticsOn ? .impact(weight: .medium, intensity: 0.8) : nil }
        .sensoryFeedback(trigger: model.levelTick) { _, _ in model.hapticsOn ? .impact(flexibility: .rigid) : nil }
        .sensoryFeedback(trigger: model.shadeTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: model.dawnTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.fallTick) { _, _ in model.hapticsOn ? .error : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            model.active = phase == .active
            if phase == .active && !model.still { model.now = Date() }
            // 夜の途中でアプリを離れたら、止めておく（戻ると続きから）
            if phase != .active { model.engine?.resume() }
        }
        .environment(\.locale, Lang.locale)
    }
}

struct SheetContent: View {
    let sheet: ActiveSheet

    var body: some View {
        switch sheet {
        case .craft: CraftSheet()
        case .residents: ResidentsSheet()
        case .records: RecordsSheet()
        case .settings: SettingsSheet()
        case .paywall: PaywallSheet()
        }
    }
}

struct BannerView: View {
    let banner: Banner
    let night: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(banner.title).font(Fonts.head(16)).foregroundStyle(night ? Night.amber : Day.ink)
            Text(banner.detail).font(Fonts.body(12)).foregroundStyle(night ? Night.text : Day.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(night ? Night.panel.opacity(0.95) : Day.paper))
        .overlay(Capsule().stroke(night ? Night.rim : Day.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

/// 見本の島（撮影・デモ）：遊んで 5 日目くらい
enum Samples {
    static func save(now: Date, calendar: Calendar) -> SaveData {
        var s = SaveData()
        s.materials = [Material.shell.rawValue: 7, Material.wood.rawValue: 9, Material.flower.rawValue: 5, Material.stone.rawValue: 6, Material.glow.rawValue: 11]
        s.levels = ["bonfire": 2, "lighthouse": 1, "chimes": 2, "fence": 1, "lantern": 1, "hammock": 1, "path": 1, "windmill": 1]
        s.residentSteps = ["tako": 2, "puffin": 1, "turtle": 1]
        s.pickedDay = Days.key(now, calendar: calendar)
        s.picked = [1, 4, 7]
        let secs: [Double] = [64, 118, 180, 180, 151, 180, 180]
        for (i, sec) in secs.enumerated() {
            let day = Days.key(calendar.date(byAdding: .day, value: i - secs.count, to: now) ?? now, calendar: calendar)
            let survived = sec >= 180
            s.nights.append(NightRecord(day: day, night: s.nightsCleared + 1, seconds: sec, kills: Int(sec * 1.4), glow: Int(sec / 14), survived: survived, endless: false))
            if survived { s.nightsCleared += 1 }
        }
        s.totalKills = 1186
        s.bestSeconds = 180
        s.lastNightDay = Days.yesterday(now, calendar: calendar)
        s.streak = 4
        s.bestStreak = 4
        s.builtCount = 11
        return s
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、潮や連続日数が毎回同じになるように）
    static func stageDate() -> Date {
        var c = DateComponents()
        c.year = 2026
        c.month = 11
        c.day = 20
        c.hour = 21
        c.minute = 30
        return Calendar.current.date(from: c) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["save", "onboarded", "sound", "haptics", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel()
            model.setSound(false)
            model.calm = true
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let now = stageDate()
        let model = AppModel(persists: false, now: now)
        model.still = scene != nil
        model.onboarded = scene != "onboarding"
        if scene != "fresh" && scene != "onboarding" {
            model.save = Samples.save(now: now, calendar: model.calendar)
        }
        return model
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(200))
        switch scene {
        case "craft": model.activeSheet = .craft
        case "residents": model.activeSheet = .residents
        case "records": model.activeSheet = .records
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        case "built":
            model.save.add(.stone, 6)
            model.build(Content.recipe(.tower))
        case "night":
            model.startNight()
            model.engine?.sim.simulate(seconds: 70, autopilot: true)
        case "levelup":
            model.startNight()
            guard let engine = model.engine else { return }
            engine.sim.simulate(seconds: 40, autopilot: true)
            while engine.sim.pendingUpgrades == nil && engine.sim.outcome == nil {
                engine.sim.input = engine.sim.autoInput()
                engine.sim.step(1.0 / 60)
            }
            model.upgradeChoices = engine.sim.pendingUpgrades
        case "shade":
            model.startNight()
            model.engine?.sim.simulate(seconds: 152, autopilot: true)
        case "pro":
            model.proOverride = true
            model.save.levels["scope"] = 1
            model.save.levels["boat"] = 2
            model.save.levels["festival"] = 1
            model.save.residentSteps["fox"] = 1
            model.startNight()
            model.engine?.sim.simulate(seconds: 95, autopilot: true)
        case "result":
            model.lastOutcome = NightOutcome(night: 5, seconds: 180, kills: 262, sand: 96, survived: true, endless: false, retreated: false)
            model.lastGlow = 20
            model.lastWasBest = true
            model.screen = .result
        case "fail":
            model.lastOutcome = NightOutcome(night: 5, seconds: 132, kills: 171, sand: 58, survived: false, endless: false, retreated: false)
            model.lastGlow = 9
            model.screen = .result
        case "empty":
            model.save = SaveData()
            model.activeSheet = .records
        default: break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 昼の島 → 浜で拾う → 見張り台を作る → 夜へ（自動で逃げる）→ 夜明け
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }
        await wait(1.6)
        for p in model.pickups.filter({ !model.pickedToday.contains($0.id) }).prefix(3) {
            model.pick(p)
            await wait(0.45)
        }
        model.save.add(.stone, 4)
        model.activeSheet = .craft
        await wait(1.4)
        model.build(Content.recipe(.tower))
        await wait(1.4)
        model.activeSheet = nil
        await wait(1.0)
        model.autopilot = true
        model.startNight()
        // 録画を短くするため、夜の残りを 12 秒から始める
        model.engine?.sim.simulate(seconds: 20, autopilot: true)
        model.engine?.sim.time = NightSim.duration - 12
        model.engine?.resume()
    }
}
