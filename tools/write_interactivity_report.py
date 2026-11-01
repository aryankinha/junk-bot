#!/usr/bin/env python3
"""Builds reports/INTERACTIVITY_REPORT.md from the measurement JSON in results/ (no numbers are typed by hand)."""
import json, os

R = "results/"
def load(name):
    with open(R + name) as f:
        return json.load(f)

def rows_by_bot(d):
    return {(r["bot"], int(r["delay_ms"])): r for r in d["rows"]}

def pct(x):
    return "%.0f%%" % (x * 100)

base = load("interactivity_baseline.json")
full = load("interactivity_all.json")
b_rows, f_rows = rows_by_bot(base), rows_by_bot(full)

def l1_table():
    out = ["| Bot | delay ms | win % base -> all | first gate s | payoff s base -> all | payoff <= 2 s base -> all | gap pre-boss median / p90 s, base | gap median / p90 s, all | runs with gap <= 4 s, base -> all | evolved |",
           "|---|---|---|---|---|---|---|---|---|---|"]
    for key in b_rows:
        b, f = b_rows[key], f_rows[key]
        out.append("| %s | %d | %s -> %s | %.1f | %.1f -> %.1f | %s -> %s | %.1f / %.1f | %.1f / %.1f | %s -> %s | %s |" % (
            key[0], key[1], pct(b["win_rate"]), pct(f["win_rate"]), f["first_gate_median"],
            b["payoff_median"], f["payoff_median"], pct(b["payoff_within_2s"]), pct(f["payoff_within_2s"]),
            b["gap_pre_boss_median"], b["gap_pre_boss_p90"], f["gap_pre_boss_median"], f["gap_pre_boss_p90"],
            pct(b["gap_le_4s_share"]), pct(f["gap_le_4s_share"]), pct(f.get("evolved_share", 0))))
    return "\n".join(out)

def level_table():
    out = ["| Level | Bot | win % flags off | win % all flags on |", "|---|---|---|---|"]
    for level, bf, ff in [(1, "interactivity_baseline.json", "interactivity_all.json"), (3, "interactivity_baseline_l3.json", "interactivity_all_l3.json"), (5, "interactivity_baseline_l5.json", "interactivity_all_l5.json")]:
        if not (os.path.exists(R + bf) and os.path.exists(R + ff)):
            continue
        b, f = rows_by_bot(load(bf)), rows_by_bot(load(ff))
        for key in [("perfect", 0), ("aim", 150), ("aim", 400), ("random", 250), ("no_dodge", 0)]:
            out.append("| %d | %s (%d ms) | %s | %s |" % (level, key[0], key[1], pct(b[key]["win_rate"]), pct(f[key]["win_rate"])))
    return "\n".join(out)

def pair_table(name):
    d = load(name)
    out = ["| Gate z | A vs B | A picked, paired seeds | A picked, noise-aware | score gap A-B | A payoff s | B payoff s |", "|---|---|---|---|---|---|---|"]
    for r in d["rows"]:
        first = r["gate_z"] == 80
        out.append("| %d | %s vs %s | %s | %s | %.1f%% | %s | %s |" % (r["gate_z"], r["a"], r["b"], pct(r["a_share"]), pct(r["a_share_noise_aware"]), r["score_gap_pct"],
                   ("%.1f" % r["a_payoff"]) if first and r["a_payoff"] >= 0 else "-", ("%.1f" % r["b_payoff"]) if first and r["b_payoff"] >= 0 else ("none" if first else "-")))
    return "\n".join(out)

def perf_table():
    names = [("Flags off", "interactivity_perf_baseline_full_desktop.json"), ("All flags on", "interactivity_perf_all_flags_desktop.json")]
    out = ["| Run (95 s, desktop M3, vsync) | samples | p50 ms | p95 ms | p99 ms | frames > 20 ms | draw calls median / max | primitives max | engine static memory MB |", "|---|---|---|---|---|---|---|---|---|"]
    for label, f in names:
        d = load(f)
        out.append("| %s | %d | %.2f | %.2f | %.2f | %.2f%% | %d / %d | %d | %.1f |" % (label, d["samples"], d["p50_ms"], d["p95_ms"], d["p99_ms"], d["share_over_20.0_ms"] * 100, d["draw_calls_median"], d["draw_calls_max"], d["primitives_max"], d["static_memory_bytes"] / 1048576.0))
    return "\n".join(out)

def fairness_table():
    d = load("interactivity_moving_fairness.json")
    out = ["| Bot reaction delay ms | moving gates | intended panel taken |", "|---|---|---|"]
    for r in d:
        out.append("| %d | %d | %d (%.0f%%) |" % (r["delay_ms"], r["moving_gates"], r["intended"], 100.0 * r["intended"] / max(1, r["moving_gates"])))
    return "\n".join(out)

def focus_table():
    d = load("interactivity_focus_check.json")
    out = ["| Bot | focus_fire | win % | median boss s | kills | scrap |", "|---|---|---|---|---|---|"]
    for r in d:
        out.append("| %s | %s | %s | %.1f | %.1f | %.0f |" % (r["bot"], "on" if r["focus_fire"] else "off", pct(r["win_rate"]), r["boss_median_s"], r["kills"], r["scrap"]))
    return "\n".join(out)

template = open("tools/interactivity_report_template.md").read()
text = template
for key, value in {"L1_TABLE": l1_table(), "LEVEL_TABLE": level_table(), "PAIRS_BASE": pair_table("interactivity_pairs_baseline_random.json"), "PAIRS_E2": pair_table("interactivity_pairs_e2_random.json"),
                   "PERF_TABLE": perf_table(), "FAIRNESS_TABLE": fairness_table(), "FOCUS_TABLE": focus_table()}.items():
    text = text.replace("{{%s}}" % key, value)
open("reports/INTERACTIVITY_REPORT.md", "w").write(text)
print("written reports/INTERACTIVITY_REPORT.md,", len(text), "chars")
