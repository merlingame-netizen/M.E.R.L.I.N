#!/usr/bin/env python3
"""
MERLIN — Monte-Carlo balance simulation (game_playtester agent)
Run de 25 cartes / 5 actes — validation equilibrage v3.6 (bible §28).

Modele:
- 25 cartes, 5 actes de 5. Vie 100 depart, pas de drain, clamp [0,100].
- 1 check/carte. pass = 0.5 + 0.1*stat (cap 0.95). Stat testee uniforme sur 4 stats.
- Types: white 75% (fail -4), contextuel 15% (fail -8), red 8% (fail -15), fatal 2% (fail = mort).
- Succes: crit 10% -> +5 PV ; heal 30% -> +2 PV ; sinon +0.
- Courbe danger: degats x [0.6, 0.8, 1.0, 1.3, 1.6] par acte.
- Quert: +10 PV si vie < 60, cooldown 4 cartes (glouton).
- SHOP: +8 PV apres carte 8 (acte II) et carte 18 (acte IV).
"""
import random
import statistics
from dataclasses import dataclass, field, replace

N_RUNS = 10_000
SEED = 20260725

STATS = ("logic", "vol", "emp", "ins")

BUILDS = {
    "First-run":  {"logic": 1, "vol": 1, "emp": 1, "ins": 1},
    "Druide pur": {"logic": 5, "vol": 3, "emp": 1, "ins": 1},
    "Berserker":  {"logic": 1, "vol": 5, "emp": 1, "ins": 3},
    "Diplomate":  {"logic": 3, "vol": 1, "emp": 5, "ins": 1},
    "Survivant":  {"logic": 1, "vol": 3, "emp": 1, "ins": 5},
    "Polyvalent": {"logic": 3, "vol": 3, "emp": 3, "ins": 3},
}

@dataclass
class Config:
    name: str = "baseline"
    dmg_white: float = 4.0
    dmg_ctx: float = 8.0
    dmg_red: float = 15.0
    p_white: float = 0.75
    p_ctx: float = 0.15
    p_red: float = 0.08
    p_fatal: float = 0.02
    act_mults: tuple = (0.6, 0.8, 1.0, 1.3, 1.6)
    crit_chance: float = 0.10   # % des reussites -> +crit_heal
    crit_heal: float = 5.0
    heal_chance: float = 0.30   # % des reussites (non-crit) -> +heal_amount
    heal_amount: float = 2.0
    quert_heal: float = 10.0
    quert_cd: int = 4
    quert_threshold: float = 60.0
    shop_heal: float = 8.0
    shop_after_cards: tuple = (8, 18)  # 1-indexed, actes II et IV
    fatal_min_act: int = 1     # actes < fatal_min_act : fatal converti en red
    fatal_soft_dmg: float = None  # si non-None : fatal fail = -X PV au lieu de mort (actes < min_act)

def pass_chance(stat: int) -> float:
    return min(0.95, 0.5 + 0.1 * stat)

def simulate_run(build: dict, cfg: Config, rng: random.Random):
    """Retourne (dead: bool, death_act: int|None, fatal_death: bool, final_life: float)."""
    life = 100.0
    quert_cd = 0
    for card in range(1, 26):
        act = (card - 1) // 5 + 1  # 1..5
        mult = cfg.act_mults[act - 1]

        # --- tirage type de check (white = reste, pour que p_fatal/p_red soient exacts) ---
        r = rng.random()
        if r < cfg.p_fatal:
            ctype, dmg = "fatal", None
        elif r < cfg.p_fatal + cfg.p_red:
            ctype, dmg = "red", cfg.dmg_red
        elif r < cfg.p_fatal + cfg.p_red + cfg.p_ctx:
            ctype, dmg = "ctx", cfg.dmg_ctx
        else:
            ctype, dmg = "white", cfg.dmg_white
        if ctype == "fatal" and act < cfg.fatal_min_act:
            if cfg.fatal_soft_dmg is not None:
                ctype, dmg = "fatal_soft", cfg.fatal_soft_dmg
            else:
                ctype, dmg = "red", cfg.dmg_red  # converti en red

        # --- check de stat ---
        stat = STATS[rng.randrange(4)]
        success = rng.random() < pass_chance(build[stat])

        if success:
            r2 = rng.random()
            if r2 < cfg.crit_chance:
                life = min(100.0, life + cfg.crit_heal)
            elif r2 < cfg.crit_chance + cfg.heal_chance:
                life = min(100.0, life + cfg.heal_amount)
        else:
            if ctype == "fatal":
                return True, act, True, 0.0
            life -= dmg * mult
            if life <= 0:
                return True, act, False, 0.0

        # --- quert (glouton, apres resolution) ---
        if quert_cd > 0:
            quert_cd -= 1
        if life < cfg.quert_threshold and quert_cd == 0:
            life = min(100.0, life + cfg.quert_heal)
            quert_cd = cfg.quert_cd

        # --- shop ---
        if card in cfg.shop_after_cards:
            life = min(100.0, life + cfg.shop_heal)

    return False, None, False, life

def run_batch(build_name: str, cfg: Config, n: int = N_RUNS, seed: int = SEED):
    rng = random.Random(f"{seed}-{build_name}-{cfg.name}")
    build = BUILDS[build_name]
    deaths = 0
    fatal_deaths = 0
    death_acts = [0] * 6  # index 1..5
    lives = []
    for _ in range(n):
        dead, act, fatal, life = simulate_run(build, cfg, rng)
        if dead:
            deaths += 1
            death_acts[act] += 1
            if fatal:
                fatal_deaths += 1
        else:
            lives.append(life)
    death_rate = deaths / n
    stats = {
        "death_rate": death_rate,
        "fatal_share": (fatal_deaths / deaths) if deaths else 0.0,
        "death_acts": [death_acts[a] / deaths if deaths else 0.0 for a in range(1, 6)],
        "deaths_I_II": (death_acts[1] + death_acts[2]) / deaths if deaths else 0.0,
        "deaths_IV_V": (death_acts[4] + death_acts[5]) / deaths if deaths else 0.0,
        "life_mean": statistics.fmean(lives) if lives else 0.0,
        "life_p10": percentile(lives, 10),
        "life_p50": percentile(lives, 50),
        "life_p90": percentile(lives, 90),
    }
    return stats

def percentile(data, p):
    if not data:
        return 0.0
    s = sorted(data)
    k = (len(s) - 1) * p / 100
    f = int(k)
    c = min(f + 1, len(s) - 1)
    return s[f] + (s[c] - s[f]) * (k - f)

def print_table(cfg: Config, results: dict):
    print(f"\n=== CONFIG: {cfg.name} | white=-{cfg.dmg_white:g} ctx=-{cfg.dmg_ctx:g} "
          f"red=-{cfg.dmg_red:g} mults={list(cfg.act_mults)} heal%={cfg.heal_chance:g} "
          f"fatal_min_act={cfg.fatal_min_act} fatal_soft={cfg.fatal_soft_dmg} ===")
    hdr = (f"{'Build':<11} {'Mort%':>6} {'Fatal%':>7} {'ActeI':>6} {'II':>5} {'III':>5} "
           f"{'IV':>5} {'V':>5} {'I+II':>6} {'IV+V':>6} {'VieMoy':>7} {'p10':>6} {'p50':>6} {'p90':>6}")
    print(hdr)
    for b, s in results.items():
        da = s["death_acts"]
        print(f"{b:<11} {s['death_rate']*100:>5.1f}% {s['fatal_share']*100:>6.1f}% "
              f"{da[0]*100:>5.1f}% {da[1]*100:>4.0f}% {da[2]*100:>4.0f}% {da[3]*100:>4.0f}% {da[4]*100:>4.0f}% "
              f"{s['deaths_I_II']*100:>5.1f}% {s['deaths_IV_V']*100:>5.1f}% "
              f"{s['life_mean']:>7.1f} {s['life_p10']:>6.1f} {s['life_p50']:>6.1f} {s['life_p90']:>6.1f}")

def eval_config(cfg: Config):
    return {b: run_batch(b, cfg) for b in BUILDS}

def check_targets(results: dict):
    """Cibles: first-run 15-30%, autres 5-15%, aucun 0% ni >40%, morts concentrees IV-V."""
    ok, notes = True, []
    for b, s in results.items():
        dr = s["death_rate"]
        if b == "First-run":
            if not (0.15 <= dr <= 0.30):
                ok = False; notes.append(f"First-run {dr*100:.1f}% hors [15,30]")
        else:
            if not (0.05 <= dr <= 0.15):
                ok = False; notes.append(f"{b} {dr*100:.1f}% hors [5,15]")
        if dr == 0.0 or dr > 0.40:
            ok = False; notes.append(f"{b} {dr*100:.1f}% degenere")
    # concentration IV-V (sur builds avec assez de morts)
    for b, s in results.items():
        if s["death_rate"] > 0.03:
            if s["deaths_IV_V"] < 0.60:
                ok = False; notes.append(f"{b} morts IV+V={s['deaths_IV_V']*100:.0f}% <60%")
            if s["deaths_I_II"] > 0.15:
                ok = False; notes.append(f"{b} morts I+II={s['deaths_I_II']*100:.0f}% >15%")
    return ok, notes

def main():
    # ---------------------------------------------------------------
    # 1) BASELINE (valeurs mission)
    # ---------------------------------------------------------------
    base = Config(name="baseline")
    res = eval_config(base)
    print_table(base, res)
    ok, notes = check_targets(res)
    print(f"TARGETS: {'PASS' if ok else 'FAIL'} {notes}")

    # ---------------------------------------------------------------
    # 2) SENSIBILITE white/red demandee
    # ---------------------------------------------------------------
    for w in (3.0, 5.0):
        for rd in (12.0, 18.0):
            cfg = replace(base, name=f"sens_w{w:g}_r{rd:g}", dmg_white=w, dmg_red=rd)
            res = eval_config(cfg)
            print_table(cfg, res)
            ok, notes = check_targets(res)
            print(f"TARGETS: {'PASS' if ok else 'FAIL'} {notes}")

    # ---------------------------------------------------------------
    # 2bis) TUNINGS RECOMMANDES (valides PASS a 10k runs)
    # ---------------------------------------------------------------
    recommended = [
        # RECO PRINCIPALE : degats mission inchanges, fatal deplace actes IV-V a 5%
        Config(name="RECO_fatal_IV_V", dmg_white=4, dmg_ctx=8, dmg_red=15,
               p_fatal=0.05, act_mults=(0.6, 0.8, 1.0, 1.3, 1.6),
               heal_chance=0.30, fatal_min_act=4),
        # ALTERNATIVE : fatal 3.33% actes III-V (morts plus etalees III/IV/V)
        Config(name="ALT_fatal_III_V", dmg_white=4, dmg_ctx=8, dmg_red=15,
               p_fatal=0.0333, act_mults=(0.6, 0.8, 1.0, 1.3, 1.6),
               heal_chance=0.30, fatal_min_act=3),
        # VARIANTE ATTRITION : si on veut des morts par PV (27% des morts first-run)
        Config(name="VAR_attrition", dmg_white=6, dmg_ctx=12, dmg_red=20,
               p_fatal=0.02, act_mults=(0.4, 0.6, 1.0, 1.5, 2.0),
               heal_chance=0.20, fatal_min_act=3),
    ]
    for cfg in recommended:
        res = eval_config(cfg)
        print_table(cfg, res)
        ok, notes = check_targets(res)
        print(f"TARGETS: {'PASS' if ok else 'FAIL'} {notes}")

    # ---------------------------------------------------------------
    # 3) RECHERCHE DE TUNING (grid search)
    # ---------------------------------------------------------------
    print("\n\n############ GRID SEARCH TUNING ############")
    candidates = []
    for w in (3.0, 4.0, 5.0, 6.0):
        for ctx in (8.0, 10.0, 12.0):
            for rd in (15.0, 18.0, 20.0):
                for mults in ((0.6, 0.8, 1.0, 1.3, 1.6), (0.5, 0.7, 1.0, 1.4, 1.8),
                              (0.4, 0.6, 1.0, 1.5, 2.0)):
                    for heal in (0.20, 0.30):
                        for fmin, fsoft in ((1, None), (3, None), (4, None), (3, 20.0)):
                            candidates.append(Config(
                                name=f"w{w:g}c{ctx:g}r{rd:g}m{mults[4]:g}h{heal:g}f{fmin}"
                                     f"{'s' if fsoft else ''}",
                                dmg_white=w, dmg_ctx=ctx, dmg_red=rd,
                                act_mults=mults, heal_chance=heal,
                                fatal_min_act=fmin, fatal_soft_dmg=fsoft))
    print(f"{len(candidates)} candidats — screening a 2000 runs...")
    passing = []
    for cfg in candidates:
        quick = {b: run_batch(b, cfg, n=2000) for b in BUILDS}
        ok, notes = check_targets(quick)
        if ok:
            passing.append(cfg)
    print(f"{len(passing)} candidats passent le screening.")

    # Validation complete 10k des passants (max 8, tries par simplicite)
    def simplicity(c):
        # privilegier degats entiers proches baseline + courbe baseline + heal 0.3
        s = abs(c.dmg_white - 4) + abs(c.dmg_ctx - 8) * 0.5 + abs(c.dmg_red - 15) * 0.3
        s += 0 if c.act_mults == (0.6, 0.8, 1.0, 1.3, 1.6) else 1
        s += 0 if c.heal_chance == 0.30 else 0.5
        s += 0 if c.fatal_soft_dmg is None else 0.5
        return s
    passing.sort(key=simplicity)
    final_pass = []
    for cfg in passing[:12]:
        res = eval_config(cfg)
        ok, notes = check_targets(res)
        if ok:
            final_pass.append((cfg, res))
    print(f"\n{len(final_pass)} candidats confirmes a 10k runs. Meilleurs:")
    for cfg, res in final_pass[:4]:
        print_table(cfg, res)
        print("TARGETS: PASS")

    if not final_pass:
        print("\nAucun candidat parfait — les 5 moins mauvais (10k runs):")
        scored = []
        for cfg in passing[:20] or candidates[::37]:
            res = eval_config(cfg)
            _, notes = check_targets(res)
            scored.append((len(notes), cfg, res))
        scored.sort(key=lambda x: x[0])
        for nviol, cfg, res in scored[:5]:
            print_table(cfg, res)
            print(f"violations={nviol}")

if __name__ == "__main__":
    main()
