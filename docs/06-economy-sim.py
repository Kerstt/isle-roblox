"""
Fossil Coins progression simulation for docs/06-economy.md.

Monte Carlo, 1-minute ticks. Models one player per run who plays a fixed number of
minutes per day, grows dinosaurs (doc 01 growth times), dies at a per-stage hazard,
earns coins from every source in doc 06 section 2, and buys species cheapest-first.

Run:  python -I docs/06-economy-sim.py            (prints the tables used in doc 06)
      python -I docs/06-economy-sim.py --rule reset (doc 02/05 death rule instead of checkpoints)

Every number here mirrors the tuning table in doc 06 section 9. Change both together.
"""

from __future__ import annotations

import argparse
import random
import statistics

# ---------------------------------------------------------------- tuning (doc 06 s.9)
SURVIVAL_PER_MIN = {"H": 2, "J": 3, "S": 4, "A": 5, "E": 6}  # E = Elder (60+ min alive as Adult)
SIZE_FACTOR = {"S": 1.0, "M": 1.3, "L": 1.7}
STAGEUP_REPEAT = {"J": 5, "S": 10, "A": 25}  # x size factor, once per slot life high-water mark
MILESTONE_FIRST = {"J": 25, "S": 50, "A": 150, "E": 200}  # x size factor, once per species per account
MEAL_COINS, MEAL_EVERY_MIN = 5, 8  # one full meal about every 8 earning minutes (cooldown 5 min)
KILL_BASE = {"J": 20, "S": 35, "A": 60}  # by victim stage, x victim size factor x mass-ratio factor x share
KILL_DAILY_CAP = 400  # base coins, before pass multiplier
INSTINCT_COINS, INSTINCT_WEEKLY_BONUS = 25, 150
JOURNAL_DAY1, JOURNAL_DAY2 = 85, 65  # 8 goals, 150 total, onboarding
FORAGE = [50, 75, 0, 100, 150, 200, 0]  # 7 login-day calendar; days 3 and 7 are cosmetics
VIP_FORAGE_BONUS = 0.25

GROWTH_MIN = {"S": 35, "M": 45, "L": 60}
KEYS = [("H", 0.0), ("J", 0.15), ("S", 0.45), ("A", 1.0)]
CHECKPOINTS = [0.0, 0.075, 0.15, 0.30, 0.45, 0.725, 1.0]
BEGINNER_SHIELD_MIN = 30
ELDER_MIN = 60

SPECIES = {  # name: (size class, diet, coin price; 0 = free starter)
    "Velociraptor": ("S", "carn", 0),
    "Gallimimus": ("S", "omni", 0),
    "Pachycephalosaurus": ("S", "herb", 0),
    "Parasaurolophus": ("M", "herb", 750),
    "Ceratosaurus": ("M", "carn", 1000),
    "Baryonyx": ("M", "carn", 1500),
    "Triceratops": ("L", "herb", 2750),
    "Tyrannosaurus": ("L", "carn", 4000),
}
MID_COSMETIC = 800

# ---------------------------------------------------------------- behaviour assumptions
EARNING_EFFICIENCY = 0.85  # share of minutes in "earning state" (needs >= 25 %, not AFK, alive)
RESPAWN_MIN = 1  # death screen + respawn + walk, no earning
DEATH_HAZARD = {"H": 1 / 30, "J": 1 / 40, "S": 1 / 50, "A": 1 / 70}  # deaths per earning minute
KILLS_PER_HOUR = {"H": 0.0, "J": 0.4, "S": 0.8, "A": 1.2}  # eligible kills, carnivore
DIET_KILL_FACTOR = {"carn": 1.0, "omni": 0.25, "herb": 0.35}
VICTIM_STAGE = (["J", "S", "A"], [0.3, 0.4, 0.3])
VICTIM_SIZE = (["S", "M", "L"], [0.5, 0.3, 0.2])
INSTINCTS_PER_DAY = {30: 2, 60: 3, 120: 3}


def stage_of(g: float) -> str:
    s = "H"
    for name, start in KEYS:
        if g >= start - 1e-9:
            s = name
    return s


def simulate(minutes_per_day: int, mult: float, days: int, rule: str, rng: random.Random, vip=False,
             eff=EARNING_EFFICIENCY, hazard_mult=1.0, growth_mult=1.0):
    owned = [n for n, v in SPECIES.items() if v[2] == 0]
    to_buy = sorted([n for n, v in SPECIES.items() if v[2] > 0], key=lambda n: SPECIES[n][2])
    growth = {n: 0.0 for n in SPECIES}
    highwater = {n: 0.0 for n in SPECIES}  # slot-life high-water mark for repeatable stage-ups
    milestones: set[tuple[str, str]] = set()
    adult_life_min = {n: 0.0 for n in SPECIES}
    current = "Velociraptor"
    coins = 0.0
    earned_total = 0.0
    gameplay_total = 0.0
    playtime = 0
    all_plus_cosmetic_day = None
    unlock_day: dict[str, int] = {}
    cosmetic_day = None
    weekly_instincts = 0
    meal_timer = 0.0
    hourly_samples = []
    earning_min = 0
    adult_min = 0

    def add(amount: float, gameplay: bool):
        nonlocal coins, earned_total, gameplay_total
        a = amount * (mult if gameplay else 1.0)
        coins += a
        earned_total += a
        if gameplay:
            gameplay_total += a

    def pick_species():
        # play a newly bought species first, else the first owned species without an Adult milestone
        for n in reversed(owned):
            if (n, "A") not in milestones:
                return n
        return owned[-1]

    for day in range(1, days + 1):
        day_start = earned_total
        gp_start = gameplay_total
        # login reward (calendar advances per login day)
        fv = FORAGE[(day - 1) % 7]
        add(fv * (1 + VIP_FORAGE_BONUS if vip else 1), gameplay=False)
        if day == 1:
            add(JOURNAL_DAY1, False)
        if day == 2:
            add(JOURNAL_DAY2, False)
        n_inst = INSTINCTS_PER_DAY[minutes_per_day]
        add(n_inst * INSTINCT_COINS, False)
        weekly_instincts += n_inst
        if day % 7 == 0:
            if weekly_instincts >= 15:
                add(INSTINCT_WEEKLY_BONUS, False)
            weekly_instincts = 0

        kill_base_today = 0.0
        respawn_wait = 0
        for _ in range(minutes_per_day):
            playtime += 1
            if respawn_wait > 0:
                respawn_wait -= 1
                continue
            if rng.random() > eff:
                continue  # needs low / walking to water / menus: no growth, no coins
            sp = current
            size, diet, _ = SPECIES[sp]
            g = growth[sp]
            st = stage_of(g)
            earning_min += 1
            if st == "A":
                adult_min += 1
            # survival coins
            key = "E" if st == "A" and adult_life_min[sp] >= ELDER_MIN else st
            add(SURVIVAL_PER_MIN[key], True)
            # meals
            meal_timer += 1
            if meal_timer >= MEAL_EVERY_MIN:
                meal_timer = 0
                add(MEAL_COINS, True)
            # kills
            if rng.random() < KILLS_PER_HOUR[st] * DIET_KILL_FACTOR[diet] / 60:
                vs = rng.choices(*VICTIM_STAGE)[0]
                vz = rng.choices(*VICTIM_SIZE)[0]
                ratio_factor = rng.uniform(0.4, 1.3)
                share = rng.uniform(0.5, 1.0)
                base = KILL_BASE[vs] * SIZE_FACTOR[vz] * ratio_factor * share
                base = min(base, KILL_DAILY_CAP - kill_base_today)
                if base > 0:
                    kill_base_today += base
                    add(base, True)
            # growth
            if st == "A":
                adult_life_min[sp] += 1
                if adult_life_min[sp] >= ELDER_MIN and (sp, "E") not in milestones:
                    milestones.add((sp, "E"))
                    add(MILESTONE_FIRST["E"] * SIZE_FACTOR[size], False)
            else:
                ng = min(1.0, g + growth_mult / GROWTH_MIN[size])
                for name, start in KEYS[1:]:
                    if g < start <= ng + 1e-9:
                        if start > highwater[sp] + 1e-9:
                            add(STAGEUP_REPEAT[name] * SIZE_FACTOR[size], True)
                        if (sp, name) not in milestones:
                            milestones.add((sp, name))
                            add(MILESTONE_FIRST[name] * SIZE_FACTOR[size], False)
                growth[sp] = ng
                highwater[sp] = max(highwater[sp], ng)
            # death
            if rng.random() < DEATH_HAZARD[st] * hazard_mult:
                adult_life_min[sp] = 0
                respawn_wait = RESPAWN_MIN
                if playtime > BEGINNER_SHIELD_MIN:
                    if rule == "checkpoint":
                        growth[sp] = max(c for c in CHECKPOINTS if c <= growth[sp] + 1e-9)
                        if growth[sp] >= 1.0:
                            growth[sp] = 0.725
                    else:  # reset: slot goes back to hatchling, new slot life
                        growth[sp] = 0.0
                        highwater[sp] = 0.0
            # purchases: species cheapest-first, as soon as affordable
            while to_buy and coins >= SPECIES[to_buy[0]][2]:
                n = to_buy.pop(0)
                coins -= SPECIES[n][2]
                owned.append(n)
                unlock_day[n] = day
            current = pick_species()
        if cosmetic_day is None and earned_total >= MID_COSMETIC:
            cosmetic_day = day
        if all_plus_cosmetic_day is None and not to_buy and coins >= MID_COSMETIC:
            all_plus_cosmetic_day = day
        hourly_samples.append(((earned_total - day_start) / (minutes_per_day / 60),
                               (gameplay_total - gp_start) / (minutes_per_day / 60)))
    total_price = sum(v[2] for v in SPECIES.values())
    return {
        "unlock": unlock_day,
        "cosmetic_first": cosmetic_day,
        "earned": earned_total,
        "hourly_d1_7": statistics.mean(h[0] for h in hourly_samples[:7]),
        "hourly_d15_30": statistics.mean(h[0] for h in hourly_samples[14:30]),
        "gameplay_h_d15_30": statistics.mean(h[1] for h in hourly_samples[14:30]),
        "daily_d15_30": statistics.mean(h[0] for h in hourly_samples[14:30]) * minutes_per_day / 60,
        "all_species_plus_cosmetic": all_plus_cosmetic_day,
        "total_price": total_price,
        "adult_share": adult_min / max(1, earning_min),
    }


def run(profile, runs, days, rule, seed=1, **kw):
    rng = random.Random(seed)
    results = [simulate(profile[1], profile[2], days, rule, rng, **kw) for _ in range(runs)]
    return results


def median_day(results, key_fn):
    vals = [key_fn(r) for r in results]
    vals = [v if v is not None else 999 for v in vals]
    return statistics.median(vals), sorted(vals)[int(len(vals) * 0.9) - 1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rule", default="checkpoint", choices=["checkpoint", "reset"])
    ap.add_argument("--runs", type=int, default=300)
    ap.add_argument("--days", type=int, default=60)
    ap.add_argument("--eff", type=float, default=EARNING_EFFICIENCY, help="share of minutes in earning state")
    ap.add_argument("--hazard", type=float, default=1.0, help="multiplier on death hazards")
    ap.add_argument("--growth", type=float, default=1.0, help="growth speed multiplier (paid boost test)")
    ap.add_argument("--only", default="", help="substring filter on profile names")
    args = ap.parse_args()
    kw = dict(eff=args.eff, hazard_mult=args.hazard, growth_mult=args.growth)
    profiles = [
        ("Free 30 min/day", 30, 1.0),
        ("Free 60 min/day", 60, 1.0),
        ("Free 120 min/day", 120, 1.0),
        ("2x pass 30 min/day", 30, 2.0),
        ("2x pass 60 min/day", 60, 2.0),
        ("2x pass 120 min/day", 120, 2.0),
    ]
    buy_order = sorted([n for n, v in SPECIES.items() if v[2] > 0], key=lambda n: SPECIES[n][2])
    print(f"death rule: {args.rule}; runs per profile: {args.runs}; median day (P90 day)")
    print(f"earning efficiency {args.eff}, hazard x{args.hazard}, growth x{args.growth}")
    header = ["Profile"] + [f"{n[:6]} ({SPECIES[n][2]})" for n in buy_order] + [
        f"1st cosmetic ({MID_COSMETIC})",
        "all species + cosmetic",
        "coins/h wk1 (all)",
        "coins/h d15-30 (all / gameplay)",
        "coins/day d15-30",
        "time as Adult",
    ]
    print("| " + " | ".join(header) + " |")
    print("|" + "---|" * len(header))
    for p in profiles:
        if args.only and args.only not in p[0]:
            continue
        res = run(p, args.runs, args.days, args.rule, **kw)
        row = [p[0]]
        for n in buy_order:
            m, p90 = median_day(res, lambda r, n=n: r["unlock"].get(n))
            row.append(f"{m:g} ({p90:g})" if m < 999 else ">60")
        m, p90 = median_day(res, lambda r: r["cosmetic_first"])
        row.append(f"{m:g} ({p90:g})")
        m, p90 = median_day(res, lambda r: r["all_species_plus_cosmetic"])
        row.append(f"{m:g} ({p90:g})" if m < 999 else ">60")
        row.append(f"{statistics.median(r['hourly_d1_7'] for r in res):.0f}")
        row.append(f"{statistics.median(r['hourly_d15_30'] for r in res):.0f} / "
                   f"{statistics.median(r['gameplay_h_d15_30'] for r in res):.0f}")
        row.append(f"{statistics.median(r['daily_d15_30'] for r in res):.0f}")
        row.append(f"{statistics.median(r['adult_share'] for r in res):.0%}")
        print("| " + " | ".join(row) + " |")


if __name__ == "__main__":
    main()
