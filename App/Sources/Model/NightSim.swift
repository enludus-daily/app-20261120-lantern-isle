import CoreGraphics
import Foundation

// 夜の 3 分（自動で戦うサバイバー）。画面から切り離した値の型で、決まった時間ずつ進める（テストできる形）。
// 昼に作った物（Loadout）が、そのまま夜の武器・明かり・仲間になる。

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: Double) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
    var length: Double { (x * x + y * y).squareRoot() }
    var normalized: CGPoint {
        let l = length
        return l > 0.0001 ? CGPoint(x: x / l, y: y / l) : .zero
    }
    static func polar(_ angle: Double, _ r: Double) -> CGPoint { CGPoint(x: cos(angle) * r, y: sin(angle) * r) }
}

/// 夜に持っていくもの（昼の島から作る）
struct Loadout: Equatable, Sendable {
    struct Helper: Equatable, Sendable {
        var id: String
        var kind: HelperKind
        var level: Int
        var color: UInt32
        var accent: UInt32
    }

    var levels: [String: Int]
    var helpers: [Helper]
    var night: Int
    var endless: Bool

    func lv(_ k: Recipe.Kind) -> Int { levels[k.rawValue] ?? 0 }

    static func from(_ save: SaveData, endless: Bool, pro: Bool) -> Loadout {
        var levels: [String: Int] = [:]
        for r in Content.recipes where !r.pro || pro {
            let l = save.level(r.kind)
            if l > 0 { levels[r.kind.rawValue] = l }
        }
        let helpers = Content.residents.filter { (!$0.pro || pro) && save.movedIn($0) }.map {
            Helper(id: $0.id, kind: $0.helper, level: save.steps($0), color: $0.color, accent: $0.accent)
        }
        return Loadout(levels: levels, helpers: helpers, night: save.nextNight, endless: endless)
    }
}

struct NightSim {
    enum EnemyKind: Sendable { case wisp, dart, lump, shade }
    enum ShotKind: Sendable { case spark, shell, arrow, conch, firefly, pebble, fireball }
    enum RingKind: Sendable { case pop, bell, star, levelUp, hurt }

    struct Enemy {
        var id: Int
        var kind: EnemyKind
        var pos: CGPoint
        var hp: Double
        var maxHP: Double
        var speed: Double
        var radius: Double
        var touch: Double
        var xp: Int
        var orbCooldown: Double = 0
        var flash: Double = 0
        var wobble: Double
    }

    struct Shot {
        var pos: CGPoint
        var vel: CGPoint
        var damage: Double
        var radius: Double
        var pierce: Int
        var life: Double
        var kind: ShotKind
        var hits: [Int] = []
    }

    struct Gem {
        var pos: CGPoint
        var value: Int
        var pulled = false
    }

    struct Ring {
        var pos: CGPoint
        var radius: Double
        var life: Double
        var maxLife: Double
        var kind: RingKind
    }

    struct Buddy {
        var helper: Loadout.Helper
        var pos: CGPoint
        var cooldown: Double
        var swing: Double = 0
    }

    static let world = 1400.0
    static let duration = 180.0
    static let shadeTime = 150.0
    static let maxEnemies = 170

    let loadout: Loadout
    private(set) var rng: SeededRandom

    // 自分
    var player: CGPoint
    var input: CGPoint = .zero
    var hp: Double
    var maxHP: Double
    var speed: Double
    var magnet: Double
    var light: Double
    var sparkDamage = 3.0
    var sparkInterval = 0.75
    var sparkCount = 1
    var power = 1.0
    var facing: Double = -.pi / 2

    // 進み具合
    var time = 0.0
    var xp = 0
    var level = 1
    var sand = 0
    var kills = 0
    var pendingUpgrades: [Upgrade]? = nil
    var outcome: NightOutcome? = nil

    // 画面と手応えのための数（増えたら鳴らす・揺らす）
    var hurtCount = 0
    var levelUpCount = 0
    var shadeCount = 0
    var bellCount = 0
    var shake = 0.0

    var enemies: [Enemy] = []
    var shots: [Shot] = []
    var gems: [Gem] = []
    var rings: [Ring] = []
    var buddies: [Buddy] = []

    // 島の物の位置（世界の座標）
    let bonfire: CGPoint
    let lighthouse: CGPoint
    let tower: CGPoint
    let fencePosts: [CGPoint]
    let pools: [CGPoint]
    var beamAngle = 0.0
    var boatAngle = 0.0
    var orbAngle = 0.0

    private var nextID = 0
    private var spawnCarry = 0.0
    private var sparkTimer = 0.4
    private var chimeTimer = 0.8
    private var towerTimer = 1.0
    private var cannonTimer = 1.5
    private var fireflyTimer = 0.5
    private var scopeTimer = 2.0
    private var bellTimer = 4.0
    private var shadesSpawned = 0

    static func toWorld(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * world, y: p.y * world) }

    init(loadout: Loadout, seed: UInt64 = 7) {
        self.loadout = loadout
        rng = SeededRandom(seed: seed &+ UInt64(loadout.night))
        bonfire = Self.toWorld(Content.recipe(.bonfire).plot)
        lighthouse = Self.toWorld(Content.recipe(.lighthouse).plot)
        tower = Self.toWorld(Content.recipe(.tower).plot)
        player = bonfire + CGPoint(x: 0, y: 40)
        maxHP = 100 + Double(loadout.lv(.hammock)) * 25
        hp = maxHP
        speed = 125 * (1 + 0.12 * Double(loadout.lv(.path)))
        let gullBonus = loadout.helpers.filter { $0.kind == .magnet }.reduce(0.0) { $0 + 45 * Double($1.level) }
        magnet = 110 + 45 * Double(loadout.lv(.windmill)) + gullBonus
        light = 170 + 55 * Double(loadout.lv(.lighthouse))
        power = 1 + 0.1 * Double(loadout.lv(.festival))
        // 柵：たき火のまわりの輪（ところどころ切れ目）
        let fence = loadout.lv(.fence)
        var posts: [CGPoint] = []
        if fence > 0 {
            let r = 190.0 + 20 * Double(fence)
            for k in 0..<16 where k % 4 != 3 {
                posts.append(bonfire + CGPoint.polar(Double(k) / 16 * 2 * .pi, r))
            }
        }
        fencePosts = posts
        let pool = Content.recipe(.pool).plot
        pools = loadout.lv(.pool) > 0
            ? [pool, CGPoint(x: pool.x + 0.12, y: pool.y + 0.1), CGPoint(x: 0.66, y: 0.3)].map(Self.toWorld)
            : []
        buddies = loadout.helpers.enumerated().map { i, h in
            Buddy(helper: h, pos: player + CGPoint.polar(Double(i) * 1.3, 40), cooldown: 0.5 + Double(i) * 0.2)
        }
    }

    var isEndless: Bool { loadout.endless }
    var remaining: Double { isEndless ? time : max(0, Self.duration - time) }
    var xpNeeded: Int { 4 + level * 3 }
    var paused: Bool { pendingUpgrades != nil || outcome != nil }
    var bonfireRadius: Double { 110 + 30 * Double(loadout.lv(.bonfire)) }
    var poolRadius: Double { 70 + 12 * Double(loadout.lv(.pool)) }
    var frostRadius: Double { loadout.lv(.frostlamp) > 0 ? 110 + 20 * Double(loadout.lv(.frostlamp)) : 0 }
    var orbCount: Int { loadout.lv(.lantern) }
    var orbRadius: Double { 74 }
    var guardRate: Double {
        min(0.4, loadout.helpers.filter { $0.kind == .guardian }.reduce(0.0) { $0 + 0.1 + 0.05 * Double($1.level - 1) })
    }

    func orbPositions() -> [CGPoint] {
        guard orbCount > 0 else { return [] }
        return (0..<orbCount).map { player + CGPoint.polar(orbAngle + Double($0) / Double(orbCount) * 2 * .pi, orbRadius) }
    }

    var boatPos: CGPoint? {
        guard loadout.lv(.boat) > 0 else { return nil }
        let p = IslandShape.point(boatAngle, scale: 1.12)
        return Self.toWorld(p)
    }

    // MARK: - 進める

    mutating func step(_ dt: Double) {
        guard !paused else { return }
        time += dt
        if !isEndless && time >= Self.duration {
            finish(survived: true, retreated: false)
            return
        }
        shake = max(0, shake - dt * 3)
        movePlayer(dt)
        spawn(dt)
        heal(dt)
        fire(dt)
        auras(dt)
        moveShots(dt)
        moveEnemies(dt)
        collectDead()
        moveGems(dt)
        ageRings(dt)
        if hp <= 0 {
            hp = 0
            finish(survived: false, retreated: false)
        }
    }

    /// 決まった刻みで、まとめて進める（撮影・テスト）。札は最初のものを選ぶ。autopilot なら自分で逃げる
    mutating func simulate(seconds: Double, autopilot: Bool) {
        var t = 0.0
        while t < seconds && outcome == nil {
            if pendingUpgrades != nil { choose(0) }
            if autopilot { input = autoInput() }
            step(1.0 / 60)
            t += 1.0 / 60
        }
    }

    mutating func retreat() {
        guard outcome == nil else { return }
        finish(survived: false, retreated: true)
    }

    mutating func choose(_ index: Int) {
        guard let options = pendingUpgrades, options.indices.contains(index) else { return }
        apply(options[index])
        pendingUpgrades = nil
    }

    mutating func apply(_ u: Upgrade) {
        switch u {
        case .sparkPower: sparkDamage += 2
        case .sparkRate: sparkInterval *= 0.85
        case .sparkCount: sparkCount = min(5, sparkCount + 1)
        case .speed: speed *= 1.1
        case .magnet: magnet += 40
        case .vigor:
            maxHP += 20
            hp = min(maxHP, hp + 20)
        case .light: light += 40
        case .allPower: power += 0.1
        case .rest: hp = min(maxHP, hp + 50)
        }
    }

    /// 逃げ回る自動の操作（デモと撮影）：近いもやの反対へ。たき火から離れすぎない
    func autoInput() -> CGPoint {
        var away = CGPoint.zero
        for e in enemies {
            let d = player - e.pos
            let l = d.length
            if l < 260 && l > 0.1 { away = away + d.normalized * ((260 - l) / 260) }
        }
        let home = bonfire - player
        if home.length > 260 { away = away + home.normalized * 0.8 }
        // 止まらないよう、ゆっくり円を描く
        away = away + CGPoint.polar(time * 0.7, 0.35)
        return away.length > 1 ? away.normalized : away
    }

    private mutating func finish(survived: Bool, retreated: Bool) {
        outcome = NightOutcome(night: loadout.night, seconds: min(time, isEndless ? time : Self.duration), kills: kills, sand: sand,
                               survived: survived, endless: isEndless, retreated: retreated, festivalLevel: loadout.lv(.festival))
    }

    private mutating func movePlayer(_ dt: Double) {
        let l = min(1, input.length)
        if l > 0.05 {
            let dir = input.normalized
            facing = atan2(dir.y, dir.x)
            player = player + dir * (speed * l * dt)
            let n = IslandShape.clamp(CGPoint(x: player.x / Self.world, y: player.y / Self.world), margin: 0.97)
            player = Self.toWorld(n)
        }
        // 仲間はうしろについてくる
        for i in buddies.indices {
            let slot = player + CGPoint.polar(facing + .pi + (Double(i) - Double(buddies.count - 1) / 2) * 0.7, 46)
            buddies[i].pos = buddies[i].pos + (slot - buddies[i].pos) * min(1, dt * 6)
            buddies[i].swing = max(0, buddies[i].swing - dt * 4)
        }
    }

    private mutating func spawn(_ dt: Double) {
        let n = Double(loadout.night - 1)
        let rate = (1.4 + time * 0.034) * (1 + 0.06 * n)
        spawnCarry += rate * dt
        let hpScale = 1 + 0.07 * n
        while spawnCarry >= 1 {
            spawnCarry -= 1
            guard enemies.count < Self.maxEnemies else { continue }
            let roll = rng.unit()
            let kind: EnemyKind = time > 60 && roll < 0.14 ? .lump : time > 25 && roll < 0.42 ? .dart : .wisp
            spawnEnemy(kind, hpScale: hpScale)
        }
        // 大もや：2 分 30 秒（終わらない夜は 150 秒ごと）
        let due = isEndless ? Int(time / Self.shadeTime) : (time >= Self.shadeTime ? 1 : 0)
        while shadesSpawned < due {
            shadesSpawned += 1
            spawnEnemy(.shade, hpScale: hpScale * Double(shadesSpawned))
            shadeCount += 1
            shake = 1
        }
    }

    private mutating func spawnEnemy(_ kind: EnemyKind, hpScale: Double) {
        let angle = rng.unit() * 2 * .pi
        let pos = player + CGPoint.polar(angle, 400 + rng.unit() * 100)
        let (hp, speed, radius, touch, xp): (Double, Double, Double, Double, Int) = switch kind {
        case .wisp: (5, 52, 12, 9, 1)
        case .dart: (3, 100, 9, 7, 1)
        case .lump: (24, 34, 19, 15, 3)
        case .shade: (280, 40, 42, 26, 24)
        }
        nextID += 1
        enemies.append(Enemy(id: nextID, kind: kind, pos: pos, hp: hp * hpScale, maxHP: hp * hpScale, speed: speed * (0.9 + rng.unit() * 0.2),
                             radius: radius, touch: touch, xp: xp, wobble: rng.unit() * 6))
    }

    private mutating func heal(_ dt: Double) {
        var regen = 0.6 * Double(loadout.lv(.flowerbed))
        regen += loadout.helpers.filter { $0.kind == .healer }.reduce(0.0) { $0 + 0.7 * Double($1.level) }
        let bon = loadout.lv(.bonfire)
        if bon > 0 && (player - bonfire).length < bonfireRadius { regen += 2.5 * Double(bon) }
        hp = min(maxHP, hp + regen * dt)
    }

    private func nearest(to p: CGPoint, within r: Double) -> Int? {
        var best: Int?
        var bestD = r
        for (i, e) in enemies.enumerated() {
            let d = (e.pos - p).length
            if d < bestD {
                bestD = d
                best = i
            }
        }
        return best
    }

    private mutating func shoot(from p: CGPoint, at target: CGPoint, speed: Double, damage: Double, radius: Double, pierce: Int, life: Double, kind: ShotKind, spread: Double = 0) {
        let d = target - p
        let a = atan2(d.y, d.x) + spread
        shots.append(Shot(pos: p, vel: CGPoint.polar(a, speed), damage: damage * power, radius: radius, pierce: pierce, life: life, kind: kind))
    }

    private mutating func fire(_ dt: Double) {
        // 火花（いつもの武器）
        sparkTimer -= dt
        if sparkTimer <= 0, let i = nearest(to: player, within: light + 60) {
            sparkTimer = sparkInterval
            let target = enemies[i].pos
            for k in 0..<sparkCount {
                let spread = (Double(k) - Double(sparkCount - 1) / 2) * 0.16
                shoot(from: player, at: target, speed: 430, damage: sparkDamage, radius: 6, pierce: 0, life: 1.2, kind: .spark, spread: spread)
            }
        }
        // 貝の風鈴
        let chimes = loadout.lv(.chimes)
        if chimes > 0 {
            chimeTimer -= dt
            if chimeTimer <= 0, let i = nearest(to: player, within: 380) {
                chimeTimer = 1.4 - 0.25 * Double(chimes)
                for k in 0..<chimes {
                    shoot(from: player, at: enemies[i].pos, speed: 360, damage: 3 + 2 * Double(chimes), radius: 7, pierce: 0, life: 1.3, kind: .shell, spread: (Double(k) - Double(chimes - 1) / 2) * 0.3)
                }
            }
        }
        // 見張り台
        let towerLv = loadout.lv(.tower)
        if towerLv > 0 {
            towerTimer -= dt
            if towerTimer <= 0, let i = nearest(to: tower, within: 620) {
                towerTimer = 2.2 - 0.4 * Double(towerLv)
                shoot(from: tower, at: enemies[i].pos, speed: 640, damage: 8 + 5 * Double(towerLv), radius: 5, pierce: 1, life: 1.2, kind: .arrow)
            }
        }
        // ほら貝の大砲
        let cannon = loadout.lv(.cannon)
        if cannon > 0 {
            cannonTimer -= dt
            if cannonTimer <= 0, let i = nearest(to: player, within: 500) {
                cannonTimer = 2.8 - 0.3 * Double(cannon)
                shoot(from: player, at: enemies[i].pos, speed: 300, damage: 10 + 6 * Double(cannon), radius: 17, pierce: 99, life: 2.2, kind: .conch)
            }
        }
        // ホタル
        let flies = loadout.lv(.fireflies)
        if flies > 0 {
            fireflyTimer -= dt
            let alive = shots.filter { $0.kind == .firefly }.count
            if fireflyTimer <= 0 && alive < flies * 2 {
                fireflyTimer = 0.6
                let a = rng.unit() * 2 * .pi
                shots.append(Shot(pos: player, vel: CGPoint.polar(a, 160), damage: 3 * power, radius: 5, pierce: 2, life: 5, kind: .firefly))
            }
        }
        // 星の望遠鏡
        let scope = loadout.lv(.scope)
        if scope > 0 {
            scopeTimer -= dt
            if scopeTimer <= 0 {
                scopeTimer = 3.2 - 0.5 * Double(scope)
                let inLight = enemies.indices.filter { (enemies[$0].pos - player).length < light }
                if !inLight.isEmpty {
                    let i = inLight[rng.int(inLight.count)]
                    hit(i, 15 * Double(scope) * power)
                    rings.append(Ring(pos: enemies[i].pos, radius: 46, life: 0.45, maxLife: 0.45, kind: .star))
                }
            }
        }
        // 浜の鐘
        let bell = loadout.lv(.bell)
        if bell > 0 {
            bellTimer -= dt
            if bellTimer <= 0 {
                bellTimer = 8 - 1.5 * Double(bell)
                let r = 170 + 30 * Double(bell)
                for i in enemies.indices {
                    let d = enemies[i].pos - player
                    if d.length < r {
                        enemies[i].pos = enemies[i].pos + d.normalized * (enemies[i].kind == .shade ? 20 : 95)
                        hit(i, 4 * Double(bell) * power)
                    }
                }
                rings.append(Ring(pos: player, radius: r, life: 0.6, maxLife: 0.6, kind: .bell))
                bellCount += 1
            }
        }
        // 住人の仲間
        for b in buddies.indices {
            let h = buddies[b].helper
            let l = Double(h.level)
            buddies[b].cooldown -= dt
            guard buddies[b].cooldown <= 0 else { continue }
            switch h.kind {
            case .pinch:
                if let i = nearest(to: buddies[b].pos, within: 70) {
                    hit(i, (5 + 2 * l) * power)
                    buddies[b].cooldown = 0.9
                    buddies[b].swing = 1
                }
            case .toss:
                if let i = nearest(to: buddies[b].pos, within: 420) {
                    shoot(from: buddies[b].pos, at: enemies[i].pos, speed: 380, damage: 4 + 2 * l, radius: 5, pierce: 0, life: 1.3, kind: .pebble)
                    buddies[b].cooldown = 1.3
                    buddies[b].swing = 1
                }
            case .spark:
                if let i = nearest(to: buddies[b].pos, within: 360) {
                    shoot(from: buddies[b].pos, at: enemies[i].pos, speed: 340, damage: 6 + 2 * l, radius: 8, pierce: 1, life: 1.3, kind: .fireball)
                    buddies[b].cooldown = 1.1
                    buddies[b].swing = 1
                }
            case .guardian, .healer, .magnet:
                buddies[b].cooldown = 1
            }
        }
    }

    /// 回る光・たき火・灯台の光・小舟・潮だまり・雪あかり・柵
    private mutating func auras(_ dt: Double) {
        orbAngle += dt * 3.1
        beamAngle += dt * 0.9
        boatAngle += dt * 0.5
        let orbs = orbPositions()
        let bon = loadout.lv(.bonfire)
        let beam = loadout.lv(.lighthouse)
        let boat = boatPos
        let boatLv = loadout.lv(.boat)
        let fenceLv = loadout.lv(.fence)
        for i in enemies.indices {
            enemies[i].orbCooldown = max(0, enemies[i].orbCooldown - dt)
            enemies[i].flash = max(0, enemies[i].flash - dt * 5)
            let p = enemies[i].pos
            if enemies[i].orbCooldown == 0 {
                for o in orbs where (o - p).length < enemies[i].radius + 12 {
                    hit(i, (4 + Double(orbCount)) * power)
                    enemies[i].orbCooldown = 0.5
                    break
                }
            }
            if bon > 0 && (p - bonfire).length < bonfireRadius { hit(i, 3 * Double(bon) * power * dt, flash: false) }
            if beam > 0 {
                let d = p - lighthouse
                var diff = atan2(d.y, d.x) - beamAngle
                diff = atan2(sin(diff), cos(diff))
                if abs(diff) < 0.11 && d.length < 620 { hit(i, 8 * Double(beam) * power * dt, flash: false) }
            }
            if let boat, (p - boat).length < 36 + enemies[i].radius { hit(i, 12 * Double(boatLv) * power * dt, flash: false) }
            if fenceLv > 0 {
                for post in fencePosts {
                    let d = p - post
                    let reach = 16 + enemies[i].radius
                    if d.length < reach {
                        enemies[i].pos = post + d.normalized * reach
                        hit(i, 2.5 * Double(fenceLv) * power * dt, flash: false)
                    }
                }
            }
        }
    }

    private func slowFactor(at p: CGPoint) -> Double {
        var f = 1.0
        if !pools.isEmpty && pools.contains(where: { (p - $0).length < poolRadius }) {
            f *= 0.55 - 0.08 * Double(loadout.lv(.pool))
        }
        if frostRadius > 0 && (p - player).length < frostRadius { f *= 0.6 }
        return f
    }

    private mutating func moveShots(_ dt: Double) {
        var kept: [Shot] = []
        kept.reserveCapacity(shots.count)
        for var s in shots {
            s.life -= dt
            if s.kind == .firefly, let i = nearest(to: s.pos, within: 400) {
                let want = (enemies[i].pos - s.pos).normalized * 260
                s.vel = s.vel + (want - s.vel) * min(1, dt * 4)
            }
            s.pos = s.pos + s.vel * dt
            var alive = s.life > 0
            if alive {
                for i in enemies.indices where enemies[i].hp > 0 && !s.hits.contains(enemies[i].id) {
                    if (enemies[i].pos - s.pos).length < enemies[i].radius + s.radius {
                        hit(i, s.damage)
                        s.hits.append(enemies[i].id)
                        if s.hits.count > s.pierce {
                            alive = false
                            break
                        }
                    }
                }
            }
            if alive { kept.append(s) }
        }
        shots = kept
    }

    private mutating func hit(_ i: Int, _ damage: Double, flash: Bool = true) {
        enemies[i].hp -= damage
        if flash { enemies[i].flash = 1 }
    }

    private mutating func moveEnemies(_ dt: Double) {
        var hurt = 0.0
        for i in enemies.indices {
            let d = player - enemies[i].pos
            let l = d.length
            let f = slowFactor(at: enemies[i].pos)
            if l > 1 { enemies[i].pos = enemies[i].pos + d.normalized * (enemies[i].speed * f * dt) }
            if l < enemies[i].radius + 14 { hurt += enemies[i].touch }
        }
        if hurt > 0 {
            let before = Int(hp / 10)
            hp -= hurt * (1 - guardRate) * dt
            if Int(hp / 10) < before {
                hurtCount += 1
                shake = max(shake, 0.35)
            }
        }
    }

    private mutating func collectDead() {
        guard enemies.contains(where: { $0.hp <= 0 }) else { return }
        var kept: [Enemy] = []
        kept.reserveCapacity(enemies.count)
        for e in enemies {
            if e.hp <= 0 {
                kills += 1
                gems.append(Gem(pos: e.pos, value: e.xp))
                rings.append(Ring(pos: e.pos, radius: e.radius * 1.8, life: 0.3, maxLife: 0.3, kind: .pop))
            } else {
                kept.append(e)
            }
        }
        enemies = kept
    }

    private mutating func moveGems(_ dt: Double) {
        var kept: [Gem] = []
        for var g in gems {
            let d = player - g.pos
            let l = d.length
            if l < magnet || g.pulled {
                g.pulled = true
                g.pos = g.pos + d.normalized * min(l, 480 * dt)
            }
            if l < 18 {
                xp += g.value
                sand += g.value
            } else {
                kept.append(g)
            }
        }
        gems = kept
        if xp >= xpNeeded && pendingUpgrades == nil {
            xp -= xpNeeded
            level += 1
            levelUpCount += 1
            pendingUpgrades = drawUpgrades()
            rings.append(Ring(pos: player, radius: 90, life: 0.5, maxLife: 0.5, kind: .levelUp))
        }
    }

    private mutating func drawUpgrades() -> [Upgrade] {
        var pool = Upgrade.allCases.filter { $0 != .rest || hp < maxHP * 0.6 }
        if sparkCount >= 5 { pool.removeAll { $0 == .sparkCount } }
        var out: [Upgrade] = []
        while out.count < 3 && !pool.isEmpty {
            out.append(pool.remove(at: rng.int(pool.count)))
        }
        return out
    }

    private mutating func ageRings(_ dt: Double) {
        for i in rings.indices { rings[i].life -= dt }
        rings.removeAll { $0.life <= 0 }
    }
}
