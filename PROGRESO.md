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
| 1 | Núcleo de simulación + tests headless (`tools/run_tests.sh`) | ✅ Terminada (v1.1: 32 grupos, 1639 comprobaciones) |
| 2 | Banco de balance con bots (`tools/balance.sh`) + BALANCE.md | ✅ Terminada: 500 semillas × 23 bots, todos los criterios cumplidos |
| 3 | Mundo 3D, render y presets | ✅ Terminada |
| 4 | Interfaz mouse + táctil | ✅ Terminada |
| 5 | Exploración, eventos, sendas, finales (UI y contenido) | ✅ Terminada (18 ubicaciones, 80 eventos —49 diarios, 8 encadenados por followup, 13 de ubicación, 7 de ley y 3 de oleada—, 15 pedidos, sendas Orden/Fe, epílogo y estrellas) |
| 6 | Audio, tutorial y pulido | ✅ Terminada |
| 7 | Rendimiento/memoria, exports Windows + Android, Release | ✅ Terminada: RENDIMIENTO.md, `tools/export.sh`, Release `v1.0.0` publicada con `tools/publish_release.sh` |
| 8 | Auditoría post-release contra requisitos y correcciones (v1.1.0) | ✅ Terminada: banco de 500 semillas × 23 bots con todos los criterios cumplidos; Release v1.1.0 |

## Resultados clave (v1.1.0)
- Balance (BALANCE.md, 500 semillas × 23 bots): competente 71,2 % de victorias; pasivo y aleatorio 0 %; sobrantes con mediana 13–20 % y p90 ≤ 24 %; los 14 exploits sin ventaja; ignorar una oleada baja las victorias entre 9,6 y 71 puntos; estancarse desde el día 15 = 0 %.
- Rendimiento: las cifras de RENDIMIENTO.md son de la v1.0.0 (llamadas de dibujo, triángulos y memoria) y hay que re-medirlas con la build 1.1.0 (`tools/perf_measure.sh`).

## Pendiente / no verificable en este entorno
- FPS en hardware real (PC con Intel HD 620 y celular Helio G25/G35): el contenedor no tiene GPU. Se mide con *Ajustes → Ejecutar benchmark* (ver RENDIMIENTO.md, «Cómo verificar los objetivos»).
- La medición de rendimiento todavía no incluye la interfaz; el recorrido del benchmark de la v1.1 cubre todo el rango de la cámara (16–175 m), pero las tablas de la v1.0 usaron 50–110 m y hay que re-medir.

## Cómo publicar una versión nueva
1. `tools/run_tests.sh` y, si se tocó la simulación, el banco completo: `tools/balance.sh 500` (sin segundo argumento corre los 23 bots) + `python3 tools/balance_report.py --md`.
2. `tools/set_version.sh X.Y.Z`: pone la versión en `project.godot` (la que muestra el menú y va en los guardados) y en `export_presets.cfg` (Android: versionCode +1 y versionName; Windows: file_version y product_version). `SAVE_VERSION` (formato de guardado) es otra cosa: solo sube si cambia el formato, con su migración.
3. Actualizar `tools/release/NOTAS.md` (sección «Novedades de la vX.Y.Z»), commit y push.
4. `tools/publish_release.sh vX.Y.Z`: verifica que la etiqueta coincida con la versión del proyecto, que no haya cambios sin commitear, que HEAD sea el destino y que NOTAS.md tenga las novedades (si no, no publica), exporta (el `.zip` de Windows lleva `LICENCIAS.txt`), sube los binarios a la rama `release-assets` y un workflow de Actions crea la Release.

## Notas técnicas
- Simulación en `sim/` (cadena de herencia SimBase → SimMap → SimHeat → SimPeople → SimEconomy → SimSociety → SimWorld → Simulation).
- Contenido en `data/*.json` (solo enteros; `_m` = milésimas). Formato, unidades y cadenas de eventos en `data/LEEME.md`.
- Correr un script headless: `tools/gd.sh 120 res://tests/smoke.gd` (usa `--quit-after` para evitar cuelgues si hay un error de script).
- Capturas: `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/scenes/ui_shot.tscn -- --out=<carpeta> --day=30 [--ui-movil]`.
