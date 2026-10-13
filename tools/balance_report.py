#!/usr/bin/env python3
"""Resume bench_out/*.jsonl y (con --md) escribe BALANCE.md con todas las tablas de criterios."""
import json, sys, glob, os, statistics, datetime, re
from collections import Counter

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "bench_out")
MATS = ["carbon", "madera", "metal", "nucleos", "comida"]
MAT_NAMES = {"carbon": "Carbón", "madera": "Madera", "metal": "Metal", "nucleos": "Núcleos", "comida": "Comida"}
CHEATS = {
    "t01_demoler": "1. Demoler y reconstruir (reintegro ≤ 50%)",
    "t02_reasignar": "2. Reasignar al final del turno (producción por hora, el viaje cuenta)",
    "t03_sobrecarga": "3. Prender/apagar sobrecarga para resetear el estrés",
    "t04_recargar": "4. Recargar la partida (el azar va en el guardado)",
    "t05_velocidad": "5. Pausar/acelerar (simulación determinista)",
    "t06_esperanza": "6. Spam de edificios de esperanza y leyes",
    "t07_acumular": "7. Acumular sin límite (almacenes con capacidad)",
    "t08_pilas": "8. Explotar pilas/bosques/caza/ubicaciones infinitas",
    "t09_generador_noche": "9. Apagar el generador de noche",
    "t10_enfermos": "10. Mover enfermos para curarlos más rápido",
    "t11_repetir": "11. Repetir eventos o expediciones",
    "t12_automatas": "12. Autómatas sin costo",
    "t13_desbordes": "13. Desbordes, negativos, clics rápidos",
    "t14_plataforma": "14. Diferencias PC/celular (mismo seed y cuadros de 33 ms)",
}
DETERMINISM = {"t04_recargar", "t05_velocidad", "t14_plataforma"}

def load(bot):
    p = os.path.join(OUT, f"{bot}.jsonl")
    if not os.path.exists(p):
        return []
    return [json.loads(l) for l in open(p) if l.strip()]

def perc(vals, q):
    if not vals:
        return 0
    v = sorted(vals)
    k = (len(v) - 1) * q / 100
    f = int(k); c = min(f + 1, len(v) - 1)
    return v[f] + (v[c] - v[f]) * (k - f)

def winrate(rows):
    return 100.0 * sum(1 for r in rows if r["status"] == "won") / len(rows) if rows else 0.0

def res_total(rows, k):
    return statistics.mean(r["obtained"][k] for r in rows) if rows else 0

def same_hash(bot, base):
    a = {r["seed"]: r["hash"] for r in base}
    b = {r["seed"]: r["hash"] for r in load(bot)}
    common = [s for s in b if s in a]
    return 100.0 * sum(1 for s in common if a[s] == b[s]) / len(common) if common else 0.0

def ok(c):
    return "✅" if c else "❌"

def console():
    bots = sorted(set(os.path.basename(p)[:-6] for p in glob.glob(os.path.join(OUT, "*.jsonl"))))
    comp = load("competente")
    for b in bots:
        rows = load(b)
        won = [r for r in rows if r["status"] == "won"]
        line = f"{b:22s} n={len(rows):4d} victorias={winrate(rows):5.1f}%"
        if won:
            line += f" ★{statistics.mean(r['stars'] for r in won):.2f} muertos={statistics.mean(r['dead'] for r in won):.1f}"
        if b in CHEATS and comp:
            line += f" igual={same_hash(b, comp):.0f}%"
        print(line)
        reasons = Counter(r["reason"] for r in rows if r["status"] != "won")
        if reasons:
            print("    derrotas:", dict(reasons))
        if b == "competente" and won:
            print("    sobrantes:", {m: (round(statistics.median([r['left'][m] for r in won]), 1), round(perc([r['left'][m] for r in won], 90), 1)) for m in MATS})

def markdown():
    comp = load("competente")
    pas = load("pasivo")
    rnd = load("aleatorio")
    n = len(comp)
    won = [r for r in comp if r["status"] == "won"]
    wc = winrate(comp)
    L = []
    L.append("# BALANCE — Última Brasa\n")
    L.append(f"Banco de balance headless (`tools/balance.sh`). Generado el {datetime.date.today().isoformat()} con **{n} semillas por bot** (semillas 1000–{999 + n}).")
    L.append("Cada partida dura 60 días (1440 pasos de 1 hora). Mismo código de simulación que el juego.\n")
    L.append("## 1. Dificultad (criterio: competente 65–85 %, pasivo pierde ≥ 95 %, aleatorio pierde ≥ 90 %)\n")
    L.append("| Bot | Partidas | Victorias | Derrotas | Criterio | Cumple |")
    L.append("|---|---:|---:|---:|---|:---:|")
    L.append(f"| Competente | {n} | {wc:.1f} % | {100 - wc:.1f} % | gana 65–85 % | {ok(65 <= wc <= 85)} |")
    wp = winrate(pas); wr = winrate(rnd)
    L.append(f"| Pasivo | {len(pas)} | {wp:.1f} % | {100 - wp:.1f} % | pierde ≥ 95 % | {ok(100 - wp >= 95)} |")
    L.append(f"| Aleatorio | {len(rnd)} | {wr:.1f} % | {100 - wr:.1f} % | pierde ≥ 90 % | {ok(100 - wr >= 90)} |")
    reasons = Counter(r["reason"] for r in comp if r["status"] != "won")
    names = {"esperanza": "esperanza en 0", "expulsion": "descontento 100 (expulsión)", "extincion": "sin población", "explosion": "explosión del generador", "frio_final": "generador apagado al final"}
    if reasons:
        L.append("\nCausas de derrota del bot competente: " + ", ".join(f"{names.get(k, k)} {v}" for k, v in reasons.most_common()) + ".")
        days = Counter((r["day"] - 1) // 10 * 10 + 1 for r in comp if r["status"] != "won")
        L.append("Día de la derrota (tramos de 10 días): " + ", ".join(f"{d}–{d + 9}: {c}" for d, c in sorted(days.items())) + ".")
    if won:
        L.append(f"\nPartidas ganadas: {statistics.mean(r['stars'] for r in won):.2f} estrellas en promedio, {statistics.mean(r['dead'] for r in won):.1f} muertes, población final {statistics.mean(r['pop'] for r in won):.0f}.\n")
    L.append("## 2. Sobrantes al final (partidas ganadas por el bot competente)\n")
    L.append("Sobrante = stock final / total obtenido en la partida (stock inicial + todo lo que entró a los depósitos). Criterio: p90 ≤ 30 % y mediana entre 10 % y 25 %.\n")
    L.append("| Material | Mediana | Percentil 90 | Cumple |")
    L.append("|---|---:|---:|:---:|")
    for m in MATS:
        vals = [r["left"][m] for r in won]
        if not vals:
            continue
        med = statistics.median(vals); p90 = perc(vals, 90)
        L.append(f"| {MAT_NAMES[m]} | {med:.1f} % | {p90:.1f} % | {ok(p90 <= 30 and 10 <= med <= 25)} |")
    L.append("\n## 3. Antiexploits (un bot tramposo por exploit)\n")
    L.append("Cada tramposo juega igual que el competente y además intenta el exploit. Criterio: no mejora la tasa de victoria ni los recursos obtenidos en más de 5 % respecto del competente (mismas semillas). Para los exploits de determinismo se compara además el hash SHA-256 del estado final.\n")
    L.append("| Exploit | Victorias | Δ vs competente | Recursos obtenidos Δ | Estado final idéntico | Cumple |")
    L.append("|---|---:|---:|---:|---:|:---:|")
    base_res = {k: res_total(comp, k) for k in ["carbon", "madera", "metal", "crudo"]}
    for b, label in CHEATS.items():
        rows = load(b)
        if not rows:
            continue
        w = winrate(rows)
        dres = max((res_total(rows, k) - base_res[k]) / max(1, base_res[k]) * 100 for k in base_res)
        sh = same_hash(b, comp)
        cond = (w - wc) <= 5.0 and dres <= 5.0
        if b in DETERMINISM:
            cond = cond and sh >= 99.9
        L.append(f"| {label} | {w:.1f} % | {w - wc:+.1f} pp | {dres:+.1f} % (máx.) | {sh:.0f} % | {ok(cond)} |")
    L.append("\nNotas: «Recursos obtenidos Δ» es la mayor diferencia porcentual entre carbón, madera, metal y comida cruda obtenidos en promedio. "
             "El bot de recargas guarda al empezar cada día y, si hubo muertes, recarga y vuelve a jugarlo: el resultado es idéntico porque el estado del azar está dentro del guardado. "
             "El de plataforma avanza con cuadros de 33 ms a x3 (como un celular) y el de velocidad alterna pausas y velocidades al azar: ambos terminan con el mismo hash que el competente.\n")
    L.append("## 4. Ninguna oleada se puede ignorar\n")
    L.append("Variante del competente que *ignora* una oleada: no junta carbón ni comida extra para ella y durante la oleada deja el generador en potencia 1, sin sobrecarga ni calefactores.\n")
    L.append("| Oleada ignorada | Victorias | Δ vs competente | Muertes (ganadas) | Cumple |")
    L.append("|---|---:|---:|---:|:---:|")
    dead_c = statistics.mean(r["dead"] for r in won) if won else 0
    for k in range(1, 6):
        rows = load(f"ola_{k}")
        if not rows:
            continue
        w = winrate(rows)
        ww = [r for r in rows if r["status"] == "won"]
        d = statistics.mean(r["dead"] for r in ww) if ww else float("nan")
        L.append(f"| Oleada {k} | {w:.1f} % | {w - wc:+.1f} pp | {d:.1f} (competente {dead_c:.1f}) | {ok(w < wc - 5)} |")
    est = load("estancado")
    if est:
        L.append("\n## 5. Sobrevivir sin desarrollarse no alcanza\n")
        L.append("| Variante | Victorias | Cumple |")
        L.append("|---|---:|:---:|")
        L.append(f"| Deja de construir, investigar y legislar desde el día 15 | {winrate(est):.1f} % | {ok(winrate(est) <= 5)} |")
    L.append("\n## 6. Recolección a mano = 50 % del edificio básico\n")
    try:
        bd = {b["id"]: b for b in json.load(open(os.path.join(ROOT, "data", "buildings.json")))["list"]}
        post = bd["puesto_rec"]["rates_m"]
        L.append("| Recurso | Puesto (por trabajador-hora) | Edificio básico | Proporción | Cumple |")
        L.append("|---|---:|---:|---:|:---:|")
        for r, b in [("carbon", "extractor"), ("madera", "aserradero"), ("metal", "mina_hierro")]:
            pr = post[r] / 1000; br = bd[b]["rate_m"] / 1000
            L.append(f"| {MAT_NAMES[r]} | {pr:g} | {br:g} ({bd[b]['name']}) | {100 * pr / br:.0f} % | {ok(abs(pr * 2 - br) < 1e-9)} |")
        L.append("\nLos puestos y los tres edificios básicos son de exterior y usan la misma curva de frío; las mejoras de investigación solo afectan a los edificios. El test `test_recoleccion_mitad_que_edificio` lo verifica en marcha.\n")
    except Exception as e:
        L.append(f"(no se pudo leer data/buildings.json: {e})")
    L.append("## Cómo reproducir\n")
    L.append("```\ntools/setup_env.sh\ntools/balance.sh 500 \"competente pasivo aleatorio t01_demoler ... ola_1 ... estancado\" 4 1000\npython3 tools/balance_report.py --md\n```")
    open(os.path.join(ROOT, "BALANCE.md"), "w").write("\n".join(L) + "\n")
    print("BALANCE.md escrito")

if __name__ == "__main__":
    console()
    if "--md" in sys.argv:
        markdown()
