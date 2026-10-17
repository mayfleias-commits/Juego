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
DETERMINISM = {"t05_velocidad", "t14_plataforma"}
# Recursos que entran en el criterio «no mejora los recursos más de 5 %».
RES_KEYS = ["carbon", "madera", "metal", "nucleos", "crudo", "raciones"]
RES_NAMES = {"carbon": "carbón", "madera": "madera", "metal": "metal", "nucleos": "núcleos", "crudo": "comida cruda", "raciones": "raciones"}
# Los 23 bots que pide el banco completo (los mismos que corre tools/balance.sh por defecto).
ALL_BOTS = ["competente", "pasivo", "aleatorio"] + list(CHEATS) + [f"ola_{k}" for k in range(1, 6)] + ["estancado"]

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
    L.append(f"| Competente | {n} | {wc:.1f} % | {100 - wc:.1f} % | gana 65–85 % | {ok(n > 0 and 65 <= wc <= 85)} |")
    wp = winrate(pas); wr = winrate(rnd)
    L.append(f"| Pasivo | {len(pas)} | {wp:.1f} % | {100 - wp:.1f} % | pierde ≥ 95 % | {ok(len(pas) > 0 and 100 - wp >= 95)} |")
    L.append(f"| Aleatorio | {len(rnd)} | {wr:.1f} % | {100 - wr:.1f} % | pierde ≥ 90 % | {ok(len(rnd) > 0 and 100 - wr >= 90)} |")
    missing = [b for b in ALL_BOTS if not load(b)]
    if missing:
        L.append("\n**Faltan datos** de " + ", ".join(missing) + ": sus criterios figuran como no cumplidos. Correr `tools/balance.sh` sin segundo argumento (los 23 bots).")
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
    L.append("Cada tramposo juega igual que el competente y además intenta el exploit. Criterio: no mejora la tasa de victoria ni los recursos obtenidos en más de 5 % respecto del competente (mismas semillas). Para pausar/acelerar y PC/celular se compara además el hash SHA-256 del estado final; para recargar, cuántas recargas cambiaron el desenlace del azar.\n")
    L.append("| Exploit | Victorias | Δ vs competente | Recursos obtenidos Δ | Estado final idéntico | Cumple |")
    L.append("|---|---:|---:|---:|---:|:---:|")
    base_res = {k: res_total(comp, k) for k in RES_KEYS}
    for b, label in CHEATS.items():
        rows = load(b)
        if not rows:
            L.append(f"| {label} | — | — | — | — | ❌ sin datos |")
            continue
        w = winrate(rows)
        dk = {k: (res_total(rows, k) - base_res[k]) / max(1, base_res[k]) * 100 for k in base_res}
        worst = max(dk, key=dk.get)
        dres = dk[worst]
        sh = same_hash(b, comp)
        cond = (w - wc) <= 5.0 and dres <= 5.0
        det = f"{sh:.0f} %"
        if b in DETERMINISM:
            cond = cond and sh >= 99.9
        if b == "t04_recargar":
            ex = [r.get("extra", {}) for r in rows]
            rel = sum(int(e.get("recargas", 0)) for e in ex)
            dist = sum(int(e.get("resultados_distintos", 0)) for e in ex)
            det = f"{dist} de {rel} recargas cambian el azar"
            cond = cond and dist == 0
        L.append(f"| {label} | {w:.1f} % | {w - wc:+.1f} pp | {dres:+.1f} % (máx., {RES_NAMES[worst]}) | {det} | {ok(cond)} |")
    L.append("\nNotas: «Recursos obtenidos Δ» es la mayor diferencia porcentual entre carbón, madera, metal, núcleos, comida cruda y raciones obtenidos en promedio. "
             "El de reasignar, terminado el turno de día, manda a la gente de producción a los lugares libres de los edificios con turno largo y a cubrir de noche los médicos y sociales (24 h), y a las 7 la devuelve; el viaje cuenta en todos los edificios. "
             "El de recargas, ante cada evento con azar, guarda, lo resuelve, recarga y prueba resolverlo una hora más tarde, después de contestar el pedido pendiente o eligiendo otra opción, y se queda con el mejor: "
             "la columna cuenta las recargas en las que esperar o cambiar el orden dio otro desenlace (el azar de cada evento se fija al aparecer y va en el guardado), y elegir otra opción sabiendo el desenlace entra en el criterio del 5 %. "
             "El de velocidad avanza con el reloj del juego (hasta 3 pasos por cuadro) alternando al azar cuadros en pausa —en los que da sus órdenes— con x1, x2 y x3 y cuadros de 16 a 250 ms; "
             "el de plataforma avanza como un celular (cuadros de 33 ms a x3, pausas por segundo plano y cuadros largos al volver): ambos terminan con el mismo hash que el competente. "
             "El de acumular se desarrolla como el competente, amplía almacenes en cuanto un recurso pasa del 60 % y no gasta excedentes hasta la tormenta final.\n")
    L.append("## 4. Ninguna oleada se puede ignorar\n")
    L.append("Variante del competente que *ignora* una oleada: no junta carbón ni comida extra para ella y durante la oleada deja el generador en potencia 1, sin sobrecarga ni calefactores.\n")
    L.append("| Oleada ignorada | Victorias | Δ vs competente | Muertes (ganadas) | Cumple |")
    L.append("|---|---:|---:|---:|:---:|")
    dead_c = statistics.mean(r["dead"] for r in won) if won else 0
    for k in range(1, 6):
        rows = load(f"ola_{k}")
        if not rows:
            L.append(f"| Oleada {k} | — | — | — | ❌ sin datos |")
            continue
        w = winrate(rows)
        ww = [r for r in rows if r["status"] == "won"]
        d = statistics.mean(r["dead"] for r in ww) if ww else float("nan")
        ds = f"{d:.1f}" if ww else "— (no gana ninguna)"
        L.append(f"| Oleada {k} | {w:.1f} % | {w - wc:+.1f} pp | {ds} (competente {dead_c:.1f}) | {ok(w < wc - 5)} |")
    est = load("estancado")
    L.append("\n## 5. Sobrevivir sin desarrollarse no alcanza\n")
    L.append("| Variante | Victorias | Cumple |")
    L.append("|---|---:|:---:|")
    if est:
        L.append(f"| Deja de construir, investigar y legislar desde el día 15 | {winrate(est):.1f} % | {ok(winrate(est) <= 5)} |")
    else:
        L.append("| Deja de construir, investigar y legislar desde el día 15 | — | ❌ sin datos |")
    L.append("\n## 6. Recolección a mano = 50 % del edificio básico\n")
    try:
        bd = {b["id"]: b for b in json.load(open(os.path.join(ROOT, "data", "buildings.json")))["list"]}
        post = bd["puesto_rec"]["rates_m"]
        L.append("| Recurso | Cuadrilla de acopio (por trabajador-hora) | Edificio básico | Proporción | Cumple |")
        L.append("|---|---:|---:|---:|:---:|")
        for r, b in [("carbon", "extractor"), ("madera", "aserradero"), ("metal", "mina_hierro")]:
            pr = post[r] / 1000; br = bd[b]["rate_m"] / 1000
            L.append(f"| {MAT_NAMES[r]} | {pr:g} | {br:g} ({bd[b]['name']}) | {100 * pr / br:.0f} % | {ok(abs(pr * 2 - br) < 1e-9)} |")
        L.append("\nLas cuadrillas de acopio y los tres edificios básicos son de exterior y usan la misma curva de frío; las mejoras de investigación solo afectan a los edificios. El test `test_recoleccion_mitad_que_edificio` lo verifica en marcha.\n")
    except Exception as e:
        L.append(f"(no se pudo leer data/buildings.json: {e})")
    L.append("## Cómo reproducir\n")
    L.append("```\ntools/setup_env.sh\ntools/balance.sh 500   # los 23 bots, semillas 1000–1499\npython3 tools/balance_report.py --md\n```")
    L.append("\n`tools/balance.sh` sin segundo argumento corre los 23 bots: " + " ".join(ALL_BOTS) + ".")
    open(os.path.join(ROOT, "BALANCE.md"), "w").write("\n".join(L) + "\n")
    print("BALANCE.md escrito")

if __name__ == "__main__":
    console()
    if "--md" in sys.argv:
        markdown()
