#!/usr/bin/env python3
"""Resume bench_out/*.jsonl. Uso: python3 tools/balance_report.py [--md BALANCE_tablas.md]"""
import json, sys, glob, os, statistics
from collections import Counter

def load(bot):
    p = f"bench_out/{bot}.jsonl"
    if not os.path.exists(p):
        return []
    return [json.loads(l) for l in open(p) if l.strip()]

def pct(a, b):
    return 100.0 * a / b if b else 0.0

def perc(vals, q):
    if not vals:
        return 0
    v = sorted(vals)
    k = (len(v) - 1) * q / 100
    f = int(k); c = min(f + 1, len(v) - 1)
    return v[f] + (v[c] - v[f]) * (k - f)

def summary(bot, rows):
    n = len(rows)
    won = [r for r in rows if r["status"] == "won"]
    reasons = Counter(r["reason"] for r in rows if r["status"] != "won")
    days = Counter(r["day"] for r in rows if r["status"] != "won")
    out = {"bot": bot, "n": n, "win": pct(len(won), n), "reasons": dict(reasons),
           "loss_day_median": statistics.median([r["day"] for r in rows if r["status"] != "won"]) if n > len(won) else 0}
    if won:
        out["stars"] = statistics.mean(r["stars"] for r in won)
        out["dead"] = statistics.mean(r["dead"] for r in won)
        out["pop"] = statistics.mean(r["pop"] for r in won)
        for m in ["carbon", "madera", "metal", "nucleos", "comida"]:
            vals = [r["left"][m] for r in won]
            out["left_" + m] = (statistics.median(vals), perc(vals, 90))
    out["obtained"] = {k: statistics.mean(r["obtained"][k] for r in rows) for k in rows[0]["obtained"]} if rows else {}
    out["ms"] = statistics.mean(r["ms"] for r in rows) if rows else 0
    return out

def main():
    bots = sorted(set(os.path.basename(p)[:-6] for p in glob.glob("bench_out/*.jsonl")))
    res = {b: summary(b, load(b)) for b in bots}
    for b, s in res.items():
        line = f"{b:28s} n={s['n']:4d} victorias={s['win']:5.1f}%"
        if "stars" in s:
            line += f" ★{s['stars']:.2f} muertos={s['dead']:.1f} pob={s['pop']:.0f}"
        line += f" ms={s['ms']:.0f}"
        print(line)
        if s["reasons"]:
            print("    derrotas:", s["reasons"], "día mediano:", s["loss_day_median"])
        if "left_carbon" in s:
            print("    sobrantes (mediana/p90 %):", {m: (round(s['left_' + m][0], 1), round(s['left_' + m][1], 1)) for m in ['carbon', 'madera', 'metal', 'nucleos', 'comida']})
    if "--json" in sys.argv:
        json.dump(res, open("bench_out/summary.json", "w"), indent=1)

if __name__ == "__main__":
    main()
