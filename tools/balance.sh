#!/usr/bin/env bash
# Banco de balance headless.
# Uso: tools/balance.sh [semillas=500] [bots=los 23] [procesos=nproc] [desde=1000]
# Sin lista de bots (o con "") corre los 23 que pide BALANCE.md: competente, pasivo,
# aleatorio, los 14 tramposos, las 5 variantes que ignoran una oleada y estancado.
# Resultados: bench_out/<bot>.jsonl ; resumen: python3 tools/balance_report.py [--md]
set -u
cd "$(dirname "$0")/.."
ALL_BOTS="competente pasivo aleatorio t01_demoler t02_reasignar t03_sobrecarga t04_recargar t05_velocidad t06_esperanza t07_acumular t08_pilas t09_generador_noche t10_enfermos t11_repetir t12_automatas t13_desbordes t14_plataforma ola_1 ola_2 ola_3 ola_4 ola_5 estancado"
N="${1:-500}"
BOTS="${2:-$ALL_BOTS}"
J="${3:-$(nproc)}"
FROM="${4:-1000}"
mkdir -p bench_out
timeout 120 godot --headless --path . --import >/dev/null 2>&1 || true
for bot in $BOTS; do
  start=$(date +%s)
  per=$(( (N + J - 1) / J ))
  pids=()
  for ((j=0; j<J; j++)); do
    a=$(( FROM + j * per ))
    b=$(( a + per ))
    lim=$(( FROM + N ))
    (( b > lim )) && b=$lim
    (( a >= b )) && continue
    timeout 7200 godot --headless --path . --script res://bench/bench.gd --quit-after 5 -- \
      --bot="$bot" --from=$a --to=$b --out="bench_out/${bot}.part$j.jsonl" >/dev/null 2>&1 &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p"; done
  cat bench_out/${bot}.part*.jsonl > "bench_out/${bot}.jsonl" 2>/dev/null
  rm -f bench_out/${bot}.part*.jsonl
  echo "$bot: $(wc -l < bench_out/${bot}.jsonl) partidas en $(( $(date +%s) - start )) s"
done
