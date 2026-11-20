import Foundation

/// 夜の記録 1 回ぶん
struct NightRecord: Codable, Equatable, Sendable {
    var day: String
    var night: Int
    var seconds: Double
    var kills: Int
    var glow: Int
    var survived: Bool
    var endless: Bool
    var retreated: Bool = false
}

/// 端末に残すもの（UserDefaults に JSON で 1 つ）。保存は区切り（拾う・作る・届ける・夜の終わり）でだけ行う
struct SaveData: Codable, Equatable, Sendable {
    var materials: [String: Int] = Dictionary(uniqueKeysWithValues: Content.startingMaterials.map { ($0.key.rawValue, $0.value) })
    var levels: [String: Int] = Content.startingLevels
    /// 住人ごとの、かなえた頼みごとの数（0〜3。1 以上で引っ越し済み）
    var residentSteps: [String: Int] = [:]
    var pickedDay: String = ""
    var picked: [Int] = []
    var nights: [NightRecord] = []
    var nightsCleared: Int = 0
    var totalKills: Int = 0
    var bestSeconds: Double = 0
    var bestEndless: Double = 0
    var lastNightDay: String = ""
    var streak: Int = 0
    var bestStreak: Int = 0
    var builtCount: Int = 0

    // MARK: 素材

    func amount(_ m: Material) -> Int { materials[m.rawValue] ?? 0 }

    mutating func add(_ m: Material, _ n: Int) { materials[m.rawValue] = max(0, amount(m) + n) }

    func canAfford(_ cost: [Material: Int]) -> Bool { cost.allSatisfy { amount($0.key) >= $0.value } }

    /// 足りない数（見せる用）
    func shortfall(_ cost: [Material: Int]) -> [Material: Int] {
        var out: [Material: Int] = [:]
        for (m, n) in cost where amount(m) < n { out[m] = n - amount(m) }
        return out
    }

    mutating func pay(_ cost: [Material: Int]) {
        for (m, n) in cost { add(m, -n) }
    }

    // MARK: 作り物

    func level(_ kind: Recipe.Kind) -> Int { levels[kind.rawValue] ?? 0 }

    enum BuildResult: Equatable { case built(level: Int), maxed, locked, short }

    func check(_ recipe: Recipe, pro: Bool) -> BuildResult {
        let now = level(recipe.kind)
        if now >= Recipe.maxLevel { return .maxed }
        if recipe.pro && !pro { return .locked }
        return canAfford(recipe.cost(toLevel: now + 1)) ? .built(level: now + 1) : .short
    }

    @discardableResult
    mutating func build(_ recipe: Recipe, pro: Bool) -> BuildResult {
        let result = check(recipe, pro: pro)
        guard case .built(let next) = result else { return result }
        pay(recipe.cost(toLevel: next))
        levels[recipe.kind.rawValue] = next
        builtCount += 1
        return result
    }

    // MARK: 住人

    func steps(_ r: Resident) -> Int { residentSteps[r.id] ?? 0 }
    func movedIn(_ r: Resident) -> Bool { steps(r) > 0 }

    func currentRequest(_ r: Resident) -> ResidentRequest? {
        let s = steps(r)
        return s < r.requests.count ? r.requests[s] : nil
    }

    enum DeliverResult: Equatable { case done(step: Int), finished, locked, short }

    @discardableResult
    mutating func deliver(_ r: Resident, pro: Bool) -> DeliverResult {
        if r.pro && !pro { return .locked }
        guard let req = currentRequest(r) else { return .finished }
        guard canAfford(req.need) else { return .short }
        pay(req.need)
        add(req.gift, req.giftAmount)
        let next = steps(r) + 1
        residentSteps[r.id] = next
        return .done(step: next)
    }

    // MARK: 浜

    /// 日が変わったら、拾った印を消す
    mutating func rollTide(to day: String) {
        if pickedDay != day {
            pickedDay = day
            picked = []
        }
    }

    @discardableResult
    mutating func pick(_ p: Pickup, day: String) -> Bool {
        rollTide(to: day)
        guard !picked.contains(p.id) else { return false }
        picked.append(p.id)
        add(p.material, p.amount)
        return true
    }

    // MARK: 夜

    /// 夜の結果を記録する。もらえる光る砂を返す
    @discardableResult
    mutating func record(_ outcome: NightOutcome, day: String, yesterday: String) -> Int {
        let glow = outcome.glowEarned
        add(.glow, glow)
        totalKills += outcome.kills
        if outcome.endless {
            bestEndless = max(bestEndless, outcome.seconds)
        } else {
            if outcome.survived { nightsCleared += 1 }
            bestSeconds = max(bestSeconds, outcome.seconds)
        }
        if lastNightDay != day {
            streak = lastNightDay == yesterday ? streak + 1 : 1
            lastNightDay = day
            bestStreak = max(bestStreak, streak)
        }
        nights.append(NightRecord(day: day, night: outcome.night, seconds: outcome.seconds, kills: outcome.kills, glow: glow, survived: outcome.survived, endless: outcome.endless, retreated: outcome.retreated))
        if nights.count > 120 { nights.removeFirst(nights.count - 120) }
        return glow
    }

    /// 次の夜の番号（越えた夜 + 1）
    var nextNight: Int { nightsCleared + 1 }

    /// 島の素敵さ（作り物のレベルと住人の数）。昼の見出しに出す
    var charm: Int {
        levels.values.reduce(0, +) * 10 + residentSteps.values.reduce(0, +) * 15
    }
}

/// 夜の終わりの結果（NightSim が返す）
struct NightOutcome: Equatable, Sendable {
    var night: Int
    var seconds: Double
    var kills: Int
    var sand: Int
    var survived: Bool
    var endless: Bool
    var retreated: Bool
    var festivalLevel: Int = 0

    /// 拾った砂 6 つで光る砂 1。夜明けまで生きのびたら +4、祭りのやぐらで 1 割ずつ増える
    var glowEarned: Int {
        let base = sand / 6 + (survived ? 4 : 0)
        return base + base * festivalLevel / 10
    }
}

enum Days {
    static func key(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func yesterday(_ date: Date, calendar: Calendar) -> String {
        key(calendar.date(byAdding: .day, value: -1, to: date) ?? date, calendar: calendar)
    }
}
