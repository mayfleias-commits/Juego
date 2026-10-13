# PROGRESO — Última Brasa

> Si la sesión se corta: leé este archivo y seguí desde la primera fase no terminada.
> El entorno del contenedor es efímero: primero corré `tools/setup_env.sh` (instala Godot 4.7.2,
> export templates, build-tools de Android por apt, Xvfb/Mesa).
> La clave de firma de Android **no** está en el repositorio: si hace falta volver a exportar,
> copiá `ultimabrasa-release.keystore` y `clave_android.env` a `secrets/` (ver README).
> Si no están, `tools/export.sh` genera una clave nueva (el APK resultante no se instala encima del anterior).

## Estado por fases

| Fase | Descripción | Estado |
|---|---|---|
| 0 | Instalación, esqueleto, datos, PROGRESO.md | ✅ Terminada |
| 1 | Núcleo de simulación + tests headless (`tools/run_tests.sh`) | ✅ Terminada (19 grupos, 1250 comprobaciones) |
| 2 | Banco de balance con bots (`tools/balance.sh`) + BALANCE.md | ✅ Terminada: 500 semillas × 23 bots, todos los criterios cumplidos |
| 3 | Mundo 3D, render y presets | ✅ Terminada |
| 4 | Interfaz mouse + táctil | ✅ Terminada |
| 5 | Exploración, eventos, sendas, finales (UI y contenido) | ✅ Terminada (18 ubicaciones, 63 eventos, 15 pedidos, sendas Orden/Fe, epílogo y estrellas) |
| 6 | Audio, tutorial y pulido | ✅ Terminada |
| 7 | Rendimiento/memoria, exports Windows + Android, Release | ✅ Terminada: RENDIMIENTO.md, `tools/export.sh`, Release `v1.0.0` publicada con `tools/publish_release.sh` |

## Resultados clave
- Balance (BALANCE.md, 500 semillas): competente 71,0 % de victorias; pasivo y aleatorio 0 %; sobrantes con mediana 11–20 % y p90 ≤ 25 %; 14 exploits sin ventaja; ignorar cualquier oleada baja las victorias entre 6,6 y 71 puntos; estancarse desde el día 15 = 0 %.
- Rendimiento (RENDIMIENTO.md): 46 llamadas de dibujo / 13–18 k triángulos en presets de celular, 137 / 71–95 k en PC; RSS 303–412 MB; APK 53 MB, zip de Windows 38 MB.

## Pendiente / no verificable en este entorno
- FPS en hardware real (PC con Intel HD 620 y celular Helio G25/G35): el contenedor no tiene GPU. Se mide con *Ajustes → Ejecutar benchmark*.
- Ícono del `.exe` de Windows: necesita rcedit (Windows/Wine), no disponible en Linux.

## Cómo publicar una versión nueva
1. `tools/run_tests.sh` y, si se tocó la simulación, `tools/balance.sh 500 "<bots>" 4 1000` + `python3 tools/balance_report.py --md`.
2. `tools/publish_release.sh vX.Y.Z` (exporta, sube binarios a la rama `release-assets` y un workflow de Actions crea la Release).

## Notas técnicas
- Simulación en `sim/` (cadena de herencia SimBase → SimMap → SimHeat → SimPeople → SimEconomy → SimSociety → SimWorld → Simulation).
- Contenido en `data/*.json` (solo enteros; `_m` = milésimas).
- Correr un script headless: `tools/gd.sh 120 res://tests/smoke.gd` (usa `--quit-after` para evitar cuelgues si hay un error de script).
- Capturas: `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/scenes/ui_shot.tscn -- --out=<carpeta> --day=30 [--ui-movil]`.
