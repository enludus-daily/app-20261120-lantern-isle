import CoreGraphics
import Foundation
import Testing
@testable import LanternIsle

struct TideTests {
    @Test func sameDaySamePickups() {
        #expect(Tide.pickups(day: "2026-11-20") == Tide.pickups(day: "2026-11-20"))
        #expect(Tide.pickups(day: "2026-11-20").count == Tide.count)
    }

    @Test func tideChangesWithTheDay() {
        #expect(Tide.pickups(day: "2026-11-20") != Tide.pickups(day: "2026-11-21"))
    }

    @Test func pickupsLieOnTheBeach() {
        for p in Tide.pickups(day: "2026-12-01") {
            #expect(IslandShape.contains(p.pos, margin: 1.0))
            #expect(!IslandShape.contains(p.pos, margin: 0.78))
            #expect(p.material != .glow)
        }
    }

    @Test func pickingTwiceGivesOnce() {
        var save = SaveData()
        let p = Tide.pickups(day: "d1")[0]
        let before = save.amount(p.material)
        #expect(save.pick(p, day: "d1"))
        #expect(!save.pick(p, day: "d1"))
        #expect(save.amount(p.material) == before + p.amount)
    }

    @Test func newDayRefillsTheBeach() {
        var save = SaveData()
        let p = Tide.pickups(day: "d1")[0]
        save.pick(p, day: "d1")
        save.rollTide(to: "d2")
        #expect(save.picked.isEmpty)
    }
}

struct BuildTests {
    @Test func startingMaterialsBuildTwoThings() {
        var save = SaveData()
        #expect(save.build(Content.recipe(.lighthouse), pro: false) == .built(level: 1))
        #expect(save.build(Content.recipe(.chimes), pro: false) == .built(level: 1))
        #expect(save.level(.lighthouse) == 1)
    }

    @Test func buildingPaysTheCost() {
        var save = SaveData()
        let r = Content.recipe(.fence)
        let wood = save.amount(.wood)
        save.build(r, pro: false)
        #expect(save.amount(.wood) == wood - 5)
    }

    @Test func notEnoughDoesNothing() {
        var save = SaveData()
        save.materials = [:]
        #expect(save.build(Content.recipe(.tower), pro: false) == .short)
        #expect(save.level(.tower) == 0)
    }

    @Test func upgradesNeedGlowsandFromTheNight() {
        let r = Content.recipe(.lantern)
        #expect(r.cost(toLevel: 1)[.glow] == nil)
        #expect((r.cost(toLevel: 2)[.glow] ?? 0) > 0)
        #expect((r.cost(toLevel: 3)[.glow] ?? 0) > (r.cost(toLevel: 2)[.glow] ?? 0))
    }

    @Test func levelStopsAtThree() {
        var save = SaveData()
        for m in Material.allCases { save.add(m, 999) }
        let r = Content.recipe(.path)
        for _ in 0..<3 { save.build(r, pro: false) }
        #expect(save.level(.path) == 3)
        #expect(save.build(r, pro: false) == .maxed)
    }

    @Test func proBuildsAreLockedWithoutPro() {
        var save = SaveData()
        for m in Material.allCases { save.add(m, 99) }
        #expect(save.build(Content.recipe(.cannon), pro: false) == .locked)
        #expect(save.build(Content.recipe(.cannon), pro: true) == .built(level: 1))
    }

    @Test func everyPlotIsOnTheIslandAndApart() {
        let plots = Content.recipes.map(\.plot)
        for p in plots { #expect(IslandShape.contains(p, margin: 0.95)) }
        for i in plots.indices {
            for j in plots.indices where j > i {
                #expect((plots[i] - plots[j]).length > 0.05, "\(Content.recipes[i].id) と \(Content.recipes[j].id) が重なる")
            }
        }
    }

    @Test func contentHasDepth() {
        #expect(Content.recipes.count == 18)
        #expect(Content.recipes.filter { !$0.pro }.count == 12)
        #expect(Content.residents.count == 8)
        #expect(Content.residents.allSatisfy { $0.requests.count == 3 })
        #expect(Set(Content.recipes.map(\.id)).count == Content.recipes.count)
    }
}

struct ResidentTests {
    let snip = Content.residents[0]

    @Test func firstWishMovesThemIn() {
        var save = SaveData()
        #expect(!save.movedIn(snip))
        #expect(save.deliver(snip, pro: false) == .done(step: 1))
        #expect(save.movedIn(snip))
    }

    @Test func wishGivesAGift() {
        var save = SaveData()
        let gift = snip.requests[0].gift
        let before = save.amount(gift)
        save.deliver(snip, pro: false)
        #expect(save.amount(gift) == before + snip.requests[0].giftAmount)
    }

    @Test func wishesEnd() {
        var save = SaveData()
        for m in Material.allCases { save.add(m, 99) }
        for _ in 0..<3 { save.deliver(snip, pro: false) }
        #expect(save.deliver(snip, pro: false) == .finished)
        #expect(save.currentRequest(snip) == nil)
    }

    @Test func proIslandersNeedPro() {
        var save = SaveData()
        for m in Material.allCases { save.add(m, 99) }
        let fox = Content.residents.first { $0.pro }!
        #expect(save.deliver(fox, pro: false) == .locked)
    }

    @Test func movedInIslanderJoinsTheNight() {
        var save = SaveData()
        save.deliver(snip, pro: false)
        let loadout = Loadout.from(save, endless: false, pro: false)
        #expect(loadout.helpers.map(\.id) == [snip.id])
    }
}

struct NightTests {
    func loadout(_ levels: [String: Int] = ["bonfire": 1], night: Int = 1) -> Loadout {
        Loadout(levels: levels, helpers: [], night: night, endless: false)
    }

    @Test func standingStillWithNothingEventuallyFalls() {
        var sim = NightSim(loadout: loadout([:]))
        sim.simulate(seconds: 180, autopilot: false)
        #expect(sim.outcome != nil)
    }

    @Test func dawnComesAtThreeMinutes() {
        var sim = NightSim(loadout: loadout())
        sim.hp = 1_000_000
        sim.maxHP = 1_000_000
        sim.simulate(seconds: 200, autopilot: true)
        #expect(sim.outcome?.survived == true)
        #expect(sim.outcome?.seconds == NightSim.duration)
    }

    @Test func sameSeedSameNight() {
        var a = NightSim(loadout: loadout(), seed: 9)
        var b = NightSim(loadout: loadout(), seed: 9)
        a.simulate(seconds: 30, autopilot: true)
        b.simulate(seconds: 30, autopilot: true)
        #expect(a.kills == b.kills)
        #expect(a.enemies.count == b.enemies.count)
        #expect(a.player == b.player)
    }

    @Test func islandBuildsMakeTheNightEasier() {
        var bare = NightSim(loadout: loadout(["bonfire": 1]), seed: 4)
        var built = NightSim(loadout: loadout(["bonfire": 2, "lighthouse": 2, "chimes": 2, "lantern": 2, "hammock": 1, "tower": 1]), seed: 4)
        bare.simulate(seconds: 60, autopilot: true)
        built.simulate(seconds: 60, autopilot: true)
        #expect(built.kills > bare.kills)
        #expect(built.maxHP > bare.maxHP)
        #expect(built.light > bare.light)
    }

    @Test func killsDropSandAndLevelUpOffersThreeCards() {
        var sim = NightSim(loadout: loadout(["bonfire": 2, "chimes": 2, "lantern": 2]), seed: 2)
        sim.hp = 10_000
        sim.maxHP = 10_000
        var t = 0.0
        while sim.pendingUpgrades == nil && t < 120 {
            sim.input = sim.autoInput()
            sim.step(1.0 / 60)
            t += 1.0 / 60
        }
        #expect(sim.pendingUpgrades?.count == 3)
        #expect(sim.paused)
        let level = sim.level
        sim.choose(0)
        #expect(!sim.paused)
        #expect(level == 2)
    }

    @Test func upgradesChangeStats() {
        var sim = NightSim(loadout: loadout())
        let speed = sim.speed
        sim.apply(.speed)
        #expect(sim.speed > speed)
        let count = sim.sparkCount
        sim.apply(.sparkCount)
        #expect(sim.sparkCount == count + 1)
        sim.hp = 10
        sim.apply(.rest)
        #expect(sim.hp == 60)
    }

    @Test func retreatKeepsTheSand() {
        var sim = NightSim(loadout: loadout())
        sim.sand = 30
        sim.retreat()
        #expect(sim.outcome?.retreated == true)
        #expect(sim.outcome?.survived == false)
        #expect(sim.outcome?.glowEarned == 5)
    }

    @Test func playerStaysOnTheIsland() {
        var sim = NightSim(loadout: loadout())
        sim.input = CGPoint(x: 1, y: 0)
        sim.hp = 10_000
        for _ in 0..<(60 * 20) { sim.step(1.0 / 60) }
        let n = CGPoint(x: sim.player.x / NightSim.world, y: sim.player.y / NightSim.world)
        #expect(IslandShape.contains(n, margin: 1.0))
    }

    @Test func laterNightsAreHarder() {
        var early = NightSim(loadout: loadout(night: 1), seed: 1)
        var late = NightSim(loadout: loadout(night: 20), seed: 1)
        early.hp = 10_000
        late.hp = 10_000
        early.simulate(seconds: 40, autopilot: true)
        late.simulate(seconds: 40, autopilot: true)
        #expect(late.enemies.count + late.kills > early.enemies.count + early.kills)
    }

    @Test func endlessNightHasNoDawn() {
        var sim = NightSim(loadout: Loadout(levels: ["bonfire": 1], helpers: [], night: 1, endless: true))
        sim.hp = 1_000_000
        sim.maxHP = 1_000_000
        sim.simulate(seconds: 200, autopilot: true)
        #expect(sim.outcome == nil)
        #expect(sim.shadeCount == 1)
    }
}

struct RecordTests {
    let outcome = NightOutcome(night: 1, seconds: 180, kills: 100, sand: 60, survived: true, endless: false, retreated: false)

    @Test func dawnCountsAndGivesGlowsand() {
        var save = SaveData()
        let glow = save.record(outcome, day: "2026-11-20", yesterday: "2026-11-19")
        #expect(glow == 14)
        #expect(save.amount(.glow) == 14)
        #expect(save.nightsCleared == 1)
        #expect(save.nextNight == 2)
    }

    @Test func streakGrowsOnConsecutiveDays() {
        var save = SaveData()
        save.record(outcome, day: "2026-11-19", yesterday: "2026-11-18")
        save.record(outcome, day: "2026-11-20", yesterday: "2026-11-19")
        save.record(outcome, day: "2026-11-20", yesterday: "2026-11-19")
        #expect(save.streak == 2)
        save.record(outcome, day: "2026-11-23", yesterday: "2026-11-22")
        #expect(save.streak == 1)
        #expect(save.bestStreak == 2)
    }

    @Test func festivalAddsGlowsand() {
        var o = outcome
        o.festivalLevel = 2
        #expect(o.glowEarned > outcome.glowEarned)
    }

    @Test func saveRoundTrips() throws {
        var save = SaveData()
        save.build(Content.recipe(.lighthouse), pro: false)
        save.record(outcome, day: "2026-11-20", yesterday: "2026-11-19")
        let data = try JSONEncoder().encode(save)
        #expect(try JSONDecoder().decode(SaveData.self, from: data) == save)
    }
}
