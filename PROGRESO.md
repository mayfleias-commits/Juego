# PROGRESO — Última Brasa

> Si la sesión se corta: leé este archivo y seguí desde la primera fase no terminada.
> El entorno del contenedor es efímero: primero corré `tools/setup_env.sh` (instala Godot 4.7.2,
> export templates, build-tools de Android por apt, Xvfb/Mesa).

## Estado por fases

| Fase | Descripción | Estado |
|---|---|---|
| 0 | Instalación, esqueleto, datos, PROGRESO.md | ✅ Terminada |
| 1 | Núcleo de simulación + tests headless (`tools/run_tests.sh`) | 🔄 En curso |
| 2 | Banco de balance con bots (`tools/balance.sh`) + BALANCE.md | ⏳ Pendiente |
| 3 | Mundo 3D, render y presets | ⏳ Pendiente |
| 4 | Interfaz mouse + táctil | ⏳ Pendiente |
| 5 | Exploración, eventos, sendas, finales (UI y contenido) | ⏳ Pendiente |
| 6 | Audio, tutorial y pulido | ⏳ Pendiente |
| 7 | Rendimiento/memoria, exports Windows + Android, Release | ⏳ Pendiente |

## Notas de la fase en curso
- Simulación en `sim/` (cadena de herencia SimBase → SimMap → SimHeat → SimPeople → SimEconomy → SimSociety → SimWorld → Simulation).
- Contenido en `data/*.json` (solo enteros; `_m` = milésimas).
- Correr un script headless: `timeout 120 godot --headless --path . --script res://tests/smoke.gd --quit-after 5`
  (el `--quit-after` evita cuelgues si hay un error de script).
