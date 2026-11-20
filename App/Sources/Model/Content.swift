import CoreGraphics
import Foundation

// 島の中身（手で用意したデータ）：素材・作り物・住人・レベルアップの札。
// 昼に作った物が、夜の武器・明かり・仲間になる（因果の表は README）。

/// 決まった種から同じ並びを出す乱数（SplitMix64）。潮の拾い物・夜の湧き方・効果音を毎回同じにする
struct SeededRandom: Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 以上 1 未満
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    /// 0 以上 n 未満
    mutating func int(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt64(n)) }

    /// 文字列から種を作る（Hasher は起動ごとに変わるので使わない。FNV-1a）
    static func seed(_ text: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in text.utf8 {
            h ^= UInt64(b)
            h = h &* 0x0000_0100_0000_01B3
        }
        return h
    }
}

enum Material: String, Codable, CaseIterable, Sendable, Identifiable {
    case shell, wood, flower, stone, glow

    var id: String { rawValue }

    var name: String {
        switch self {
        case .shell: tr("貝がら", "Shells")
        case .wood: tr("流木", "Driftwood")
        case .flower: tr("浜の花", "Beach flowers")
        case .stone: tr("丸い石", "Pebbles")
        case .glow: tr("光る砂", "Glowsand")
        }
    }

    /// 浜で拾えるもの（光る砂は夜にだけ手に入る）
    static let beach: [Material] = [.shell, .wood, .flower, .stone]
}

/// 素材の束（並びは Material.allCases の順で見せる）
extension Dictionary where Key == Material, Value == Int {
    var total: Int { values.reduce(0, +) }
    var ordered: [(Material, Int)] { Material.allCases.compactMap { m in self[m].flatMap { $0 > 0 ? (m, $0) : nil } } }
}

/// 島の形。真上から少し斜めに見た小さな島。座標は 0〜1（昼の地図と夜の世界で同じ形を使う）
enum IslandShape {
    static let center = CGPoint(x: 0.5, y: 0.5)

    static func radius(_ angle: Double) -> Double {
        0.37 * (1 + 0.08 * sin(3 * angle + 0.5) + 0.05 * cos(5 * angle + 1.1))
    }

    static func point(_ angle: Double, scale: Double = 1) -> CGPoint {
        let r = radius(angle) * scale
        return CGPoint(x: 0.5 + cos(angle) * r, y: 0.5 + sin(angle) * r)
    }

    /// その点が島の中にあるか（margin は 0〜1 の割合。0.9 なら縁から 1 割内側まで）
    static func contains(_ p: CGPoint, margin: Double = 1) -> Bool {
        let dx = p.x - 0.5, dy = p.y - 0.5
        let angle = atan2(dy, dx)
        return (dx * dx + dy * dy).squareRoot() <= radius(angle) * margin
    }

    /// 島の中に押し戻す
    static func clamp(_ p: CGPoint, margin: Double) -> CGPoint {
        let dx = p.x - 0.5, dy = p.y - 0.5
        let d = (dx * dx + dy * dy).squareRoot()
        let angle = atan2(dy, dx)
        let r = radius(angle) * margin
        guard d > r, d > 0 else { return p }
        return CGPoint(x: 0.5 + dx / d * r, y: 0.5 + dy / d * r)
    }
}

/// 作り物。昼に島へ置くと、夜の力になる。レベル 1〜3
struct Recipe: Identifiable, Sendable {
    enum Kind: String, Sendable, CaseIterable {
        case bonfire, lighthouse, chimes, fence, lantern, hammock, path, pool, tower, windmill, bell, flowerbed
        case scope, cannon, fireflies, boat, frostlamp, festival
    }

    let kind: Kind
    let ja: String
    let en: String
    let nightJa: String
    let nightEn: String
    /// レベル 1 の材料
    let base: [Material: Int]
    /// 島の上の場所（0〜1）
    let plot: CGPoint
    let pro: Bool

    var id: String { kind.rawValue }
    var name: String { tr(ja, en) }
    var night: String { tr(nightJa, nightEn) }

    static let maxLevel = 3

    /// そのレベルに上げるのに要る材料（レベル 2 からは夜の光る砂も要る）
    func cost(toLevel level: Int) -> [Material: Int] {
        var out: [Material: Int] = [:]
        for (m, n) in base { out[m] = n * level }
        if level == 2 { out[.glow, default: 0] += 6 }
        if level >= 3 { out[.glow, default: 0] += 14 }
        return out
    }
}

/// 住人のできること（夜の仲間）
enum HelperKind: String, Sendable {
    case pinch, toss, guardian, healer, magnet, spark
}

struct ResidentRequest: Sendable {
    let need: [Material: Int]
    let lineJa: String
    let lineEn: String
    let gift: Material
    let giftAmount: Int
    var line: String { tr(lineJa, lineEn) }
}

/// 島の住人（オリジナルの小さな生き物）。頼みごとを 1 つかなえると引っ越してきて、夜は仲間になる
struct Resident: Identifiable, Sendable {
    let id: String
    let ja: String
    let en: String
    let speciesJa: String
    let speciesEn: String
    let color: UInt32
    let accent: UInt32
    let helper: HelperKind
    let helperJa: String
    let helperEn: String
    let home: CGPoint
    let pro: Bool
    let requests: [ResidentRequest]

    var name: String { tr(ja, en) }
    var species: String { tr(speciesJa, speciesEn) }
    var helperText: String { tr(helperJa, helperEn) }
}

/// 夜のレベルアップの札
enum Upgrade: String, CaseIterable, Sendable {
    case sparkPower, sparkRate, sparkCount, speed, magnet, vigor, light, allPower, rest

    var title: String {
        switch self {
        case .sparkPower: tr("火花を強く", "Hotter sparks")
        case .sparkRate: tr("火花を速く", "Faster sparks")
        case .sparkCount: tr("火花を一つ増やす", "One more spark")
        case .speed: tr("足を軽く", "Lighter steps")
        case .magnet: tr("砂を引き寄せる", "Sand magnet")
        case .vigor: tr("体力を上げる", "More stamina")
        case .light: tr("明かりを広げる", "Wider light")
        case .allPower: tr("島の力を上げる", "Island power")
        case .rest: tr("ひと休み", "Catch a breath")
        }
    }

    var detail: String {
        switch self {
        case .sparkPower: tr("火花の強さ +2", "Spark damage +2")
        case .sparkRate: tr("火花の間が 15% 短く", "Spark delay −15%")
        case .sparkCount: tr("一度に飛ぶ火花 +1", "+1 spark per volley")
        case .speed: tr("歩く速さ +10%", "Move speed +10%")
        case .magnet: tr("拾える距離 +40", "Pickup range +40")
        case .vigor: tr("最大の体力 +20、20 回復", "Max HP +20, heal 20")
        case .light: tr("見える範囲 +40", "Light radius +40")
        case .allPower: tr("すべての攻撃 +10%", "All damage +10%")
        case .rest: tr("体力を 50 回復", "Heal 50 HP")
        }
    }
}

/// 手で用意したデータ
enum Content {
    static let recipes: [Recipe] = [
        Recipe(kind: .bonfire, ja: "たき火", en: "Bonfire",
               nightJa: "近くのもやを焼き、そばにいると体力が戻る", nightEn: "Burns nearby mist and heals you while you stay close",
               base: [.wood: 3, .stone: 2], plot: CGPoint(x: 0.50, y: 0.53), pro: false),
        Recipe(kind: .lighthouse, ja: "灯台", en: "Lighthouse",
               nightJa: "見える範囲が広がり、回る光がもやを払う", nightEn: "Widens your light; its turning beam sears the mist",
               base: [.stone: 4, .wood: 2], plot: CGPoint(x: 0.62, y: 0.22), pro: false),
        Recipe(kind: .chimes, ja: "貝の風鈴", en: "Shell Chimes",
               nightJa: "近いもやへ貝のつぶてを投げる", nightEn: "Flings shell shards at the nearest mist",
               base: [.shell: 4, .wood: 1], plot: CGPoint(x: 0.40, y: 0.29), pro: false),
        Recipe(kind: .fence, ja: "流木の柵", en: "Driftwood Fence",
               nightJa: "たき火のまわりに柵。ふれたもやを押し返す", nightEn: "A ring of stakes that pushes mist back",
               base: [.wood: 5], plot: CGPoint(x: 0.27, y: 0.45), pro: false),
        Recipe(kind: .lantern, ja: "花のランタン", en: "Flower Lantern",
               nightJa: "光の玉が自分のまわりを回る", nightEn: "Orbs of light circle around you",
               base: [.flower: 3, .shell: 1], plot: CGPoint(x: 0.50, y: 0.37), pro: false),
        Recipe(kind: .hammock, ja: "ハンモック", en: "Hammock",
               nightJa: "最大の体力 +25", nightEn: "Max HP +25",
               base: [.wood: 2, .flower: 2], plot: CGPoint(x: 0.69, y: 0.36), pro: false),
        Recipe(kind: .path, ja: "石の小道", en: "Pebble Path",
               nightJa: "歩く速さ +12%", nightEn: "Move speed +12%",
               base: [.stone: 3], plot: CGPoint(x: 0.42, y: 0.63), pro: false),
        Recipe(kind: .pool, ja: "潮だまり", en: "Tide Pool",
               nightJa: "水に入ったもやが遅くなる", nightEn: "Mist slows down in the pools",
               base: [.stone: 2, .shell: 2], plot: CGPoint(x: 0.25, y: 0.60), pro: false),
        Recipe(kind: .tower, ja: "見張り台", en: "Lookout",
               nightJa: "遠くのもやを矢で射る", nightEn: "Shoots arrows at far-off mist",
               base: [.wood: 4, .stone: 1], plot: CGPoint(x: 0.76, y: 0.50), pro: false),
        Recipe(kind: .windmill, ja: "風車", en: "Windmill",
               nightJa: "光る砂を遠くから引き寄せる", nightEn: "Pulls glowsand in from farther away",
               base: [.wood: 2, .flower: 1, .shell: 1], plot: CGPoint(x: 0.33, y: 0.35), pro: false),
        Recipe(kind: .bell, ja: "浜の鐘", en: "Shore Bell",
               nightJa: "ときどき鳴って、まわりのもやを吹き飛ばす", nightEn: "Rings now and then, blasting mist away",
               base: [.stone: 2, .shell: 3], plot: CGPoint(x: 0.60, y: 0.67), pro: false),
        Recipe(kind: .flowerbed, ja: "花だん", en: "Flower Bed",
               nightJa: "体力が少しずつ戻る", nightEn: "Slowly restores HP",
               base: [.flower: 4], plot: CGPoint(x: 0.71, y: 0.62), pro: false),
        // Pro
        Recipe(kind: .scope, ja: "星の望遠鏡", en: "Star Scope",
               nightJa: "明かりの中のもやに星を落とす", nightEn: "Drops starfall on mist inside your light",
               base: [.stone: 3, .shell: 3], plot: CGPoint(x: 0.80, y: 0.40), pro: true),
        Recipe(kind: .cannon, ja: "ほら貝の大砲", en: "Conch Cannon",
               nightJa: "もやを貫く大きな貝を撃つ", nightEn: "Fires a huge shell that pierces the mist",
               base: [.shell: 4, .wood: 3], plot: CGPoint(x: 0.21, y: 0.52), pro: true),
        Recipe(kind: .fireflies, ja: "ホタルのびん", en: "Firefly Jar",
               nightJa: "ホタルがもやを追いかける", nightEn: "Fireflies chase down the mist",
               base: [.flower: 3, .shell: 2], plot: CGPoint(x: 0.46, y: 0.75), pro: true),
        Recipe(kind: .boat, ja: "灯りの小舟", en: "Lantern Boat",
               nightJa: "島のまわりを舟が回り、もやを散らす", nightEn: "A boat circles the coast, scattering mist",
               base: [.wood: 5, .flower: 1], plot: CGPoint(x: 0.78, y: 0.66), pro: true),
        Recipe(kind: .frostlamp, ja: "雪あかり", en: "Frost Lamp",
               nightJa: "まわりのもやを凍えさせて遅くする", nightEn: "Chills nearby mist to a crawl",
               base: [.stone: 2, .flower: 3], plot: CGPoint(x: 0.32, y: 0.73), pro: true),
        Recipe(kind: .festival, ja: "祭りのやぐら", en: "Festival Tower",
               nightJa: "すべての攻撃と砂の集まりが上がる", nightEn: "Boosts all damage and sand you gather",
               base: [.wood: 4, .flower: 3], plot: CGPoint(x: 0.59, y: 0.45), pro: true),
    ]

    static let residents: [Resident] = [
        Resident(id: "tako", ja: "ハサミ", en: "Snip", speciesJa: "ヤシガニ", speciesEn: "Coconut crab",
                 color: 0xF08A6A, accent: 0xC9573F, helper: .pinch,
                 helperJa: "近くのもやをはさむ", helperEn: "Pinches nearby mist",
                 home: CGPoint(x: 0.36, y: 0.53), pro: false, requests: [
                    ResidentRequest(need: [.shell: 3], lineJa: "貝がらを 3 つ、ちょうだい。家のかべにするの", lineEn: "Three shells, please? They'll be my walls.", gift: .wood, giftAmount: 3),
                    ResidentRequest(need: [.wood: 4, .stone: 2], lineJa: "はさみをとぐ台がほしいな", lineEn: "I'd love a bench to sharpen my claws.", gift: .flower, giftAmount: 3),
                    ResidentRequest(need: [.glow: 8, .shell: 4], lineJa: "光る砂で、はさみをぴかぴかに", lineEn: "Glowsand to make my claws shine!", gift: .stone, giftAmount: 5),
                 ]),
        Resident(id: "puffin", ja: "ポポ", en: "Popo", speciesJa: "ツノメドリ", speciesEn: "Puffin",
                 color: 0x3E3A4F, accent: 0xF7A23E, helper: .toss,
                 helperJa: "空から小石を落とす", helperEn: "Drops pebbles from above",
                 home: CGPoint(x: 0.63, y: 0.29), pro: false, requests: [
                    ResidentRequest(need: [.flower: 2, .wood: 1], lineJa: "巣に花をしきたいの", lineEn: "I want flowers for my nest.", gift: .shell, giftAmount: 3),
                    ResidentRequest(need: [.stone: 4], lineJa: "投げる小石を集めてる", lineEn: "I'm collecting pebbles to throw.", gift: .wood, giftAmount: 4),
                    ResidentRequest(need: [.glow: 8, .flower: 3], lineJa: "夜でも光る巣にしたい", lineEn: "A nest that glows at night, please!", gift: .shell, giftAmount: 5),
                 ]),
        Resident(id: "turtle", ja: "ゴロ", en: "Goro", speciesJa: "ウミガメ", speciesEn: "Sea turtle",
                 color: 0x7DB88A, accent: 0x4E8A5E, helper: .guardian,
                 helperJa: "受けるダメージ -15%", helperEn: "You take 15% less damage",
                 home: CGPoint(x: 0.30, y: 0.66), pro: false, requests: [
                    ResidentRequest(need: [.stone: 3, .wood: 2], lineJa: "ひなたぼっこの岩がほしい", lineEn: "I need a warm rock to bask on.", gift: .flower, giftAmount: 3),
                    ResidentRequest(need: [.shell: 5], lineJa: "こうらを貝でかざりたい", lineEn: "Shells to decorate my shell!", gift: .stone, giftAmount: 4),
                    ResidentRequest(need: [.glow: 10, .stone: 4], lineJa: "光る砂の寝床で、ぐっすり", lineEn: "A glowsand bed for a deep sleep.", gift: .wood, giftAmount: 6),
                 ]),
        Resident(id: "seal", ja: "モチ", en: "Mochi", speciesJa: "アザラシ", speciesEn: "Seal",
                 color: 0xC9CCD6, accent: 0x8E93A6, helper: .healer,
                 helperJa: "体力を少しずつ戻す", helperEn: "Slowly heals you",
                 home: CGPoint(x: 0.56, y: 0.76), pro: false, requests: [
                    ResidentRequest(need: [.wood: 3, .flower: 1], lineJa: "浜にすわる台をつくって", lineEn: "Build me a seat on the beach?", gift: .shell, giftAmount: 4),
                    ResidentRequest(need: [.flower: 4, .shell: 2], lineJa: "花のかんむりをかぶりたい", lineEn: "I want a flower crown!", gift: .stone, giftAmount: 4),
                    ResidentRequest(need: [.glow: 10, .wood: 4], lineJa: "夜の海を照らす灯りがほしい", lineEn: "A light for the night sea, please.", gift: .flower, giftAmount: 6),
                 ]),
        Resident(id: "gull", ja: "ソラ", en: "Sora", speciesJa: "カモメ", speciesEn: "Gull",
                 color: 0xF4F1EA, accent: 0xF2B544, helper: .magnet,
                 helperJa: "光る砂を運んでくる", helperEn: "Brings glowsand to you",
                 home: CGPoint(x: 0.74, y: 0.45), pro: false, requests: [
                    ResidentRequest(need: [.wood: 2, .shell: 2], lineJa: "止まり木がほしいな", lineEn: "I'd like a perch.", gift: .flower, giftAmount: 3),
                    ResidentRequest(need: [.stone: 3, .flower: 2], lineJa: "風よけの石垣をおねがい", lineEn: "A little stone windbreak?", gift: .wood, giftAmount: 4),
                    ResidentRequest(need: [.glow: 12, .shell: 3], lineJa: "光る砂で道しるべをつくろう", lineEn: "Let's make glowsand trail markers.", gift: .stone, giftAmount: 6),
                 ]),
        // Pro
        Resident(id: "fox", ja: "コン", en: "Kon", speciesJa: "砂ギツネ", speciesEn: "Sand fox",
                 color: 0xF2B86B, accent: 0xD98B3A, helper: .spark,
                 helperJa: "火の玉を放つ", helperEn: "Throws little fireballs",
                 home: CGPoint(x: 0.44, y: 0.44), pro: true, requests: [
                    ResidentRequest(need: [.wood: 4, .flower: 2], lineJa: "たき火のそばに住みたい", lineEn: "I want to live by the fire.", gift: .shell, giftAmount: 4),
                    ResidentRequest(need: [.stone: 5], lineJa: "かまどを作ってみたい", lineEn: "Help me build a little oven?", gift: .flower, giftAmount: 4),
                    ResidentRequest(need: [.glow: 12, .wood: 5], lineJa: "しっぽに光る砂をつけたい", lineEn: "Glowsand for my tail!", gift: .stone, giftAmount: 6),
                 ]),
        Resident(id: "owl", ja: "ホウ", en: "Hoo", speciesJa: "メンフクロウ", speciesEn: "Barn owl",
                 color: 0xE9D2B0, accent: 0x9C7A55, helper: .toss,
                 helperJa: "遠くのもやに羽を飛ばす", helperEn: "Darts feathers at far mist",
                 home: CGPoint(x: 0.53, y: 0.21), pro: true, requests: [
                    ResidentRequest(need: [.wood: 5], lineJa: "高い止まり木で見張りたい", lineEn: "A tall perch to keep watch from.", gift: .stone, giftAmount: 4),
                    ResidentRequest(need: [.shell: 3, .stone: 3], lineJa: "月を見る台がほしい", lineEn: "A stand for moon-watching.", gift: .flower, giftAmount: 4),
                    ResidentRequest(need: [.glow: 14, .flower: 3], lineJa: "夜でも読める本棚を", lineEn: "A bookshelf I can read at night.", gift: .wood, giftAmount: 6),
                 ]),
        Resident(id: "hermit", ja: "ヤド", en: "Yado", speciesJa: "ヤドカリ", speciesEn: "Hermit crab",
                 color: 0xF4C7B8, accent: 0xE07C6A, helper: .guardian,
                 helperJa: "受けるダメージ -15%", helperEn: "You take 15% less damage",
                 home: CGPoint(x: 0.22, y: 0.40), pro: true, requests: [
                    ResidentRequest(need: [.shell: 6], lineJa: "新しいおうち（貝）を探してる", lineEn: "I'm looking for a new shell home.", gift: .wood, giftAmount: 4),
                    ResidentRequest(need: [.flower: 3, .stone: 2], lineJa: "おうちの前に花を", lineEn: "Flowers by my front door?", gift: .shell, giftAmount: 4),
                    ResidentRequest(need: [.glow: 14, .shell: 5], lineJa: "光るおうちに住みたい", lineEn: "I dream of a glowing home.", gift: .stone, giftAmount: 6),
                 ]),
    ]

    static func recipe(_ kind: Recipe.Kind) -> Recipe {
        recipes.first { $0.kind == kind } ?? recipes[0]
    }

    /// 最初から島にあるもの（たき火のレベル 1）と、最初の材料（2 つ作れる量）
    static let startingLevels: [String: Int] = [Recipe.Kind.bonfire.rawValue: 1]
    static let startingMaterials: [Material: Int] = [.shell: 6, .wood: 6, .flower: 4, .stone: 4]
}

/// 浜の拾い物（毎日の潮で変わる）
struct Pickup: Equatable, Sendable, Identifiable {
    let id: Int
    let pos: CGPoint
    let material: Material
    let amount: Int
}

enum Tide {
    static let count = 10

    /// 今日の潮の恵み（その素材は 1 つ多く拾える）
    static func bonus(day: String) -> Material {
        var rng = SeededRandom(seed: SeededRandom.seed("bonus-" + day))
        return Material.beach[rng.int(Material.beach.count)]
    }

    static func pickups(day: String) -> [Pickup] {
        var rng = SeededRandom(seed: SeededRandom.seed("tide-" + day))
        let bonus = bonus(day: day)
        var out: [Pickup] = []
        for i in 0..<count {
            let angle = Double(i) / Double(count) * 2 * .pi + rng.unit() * 0.45
            let p = IslandShape.point(angle, scale: 0.84 + rng.unit() * 0.08)
            let roll = rng.unit()
            let material: Material = roll < 0.32 ? .shell : roll < 0.6 ? .wood : roll < 0.82 ? .flower : .stone
            var amount = 1 + rng.int(3)
            if material == bonus { amount += 1 }
            out.append(Pickup(id: i, pos: p, material: material, amount: amount))
        }
        return out
    }
}
