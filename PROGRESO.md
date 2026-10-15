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
| 8 | Auditoría post-release contra requisitos y correcciones (v1.1.0) | 🔄 En curso |

## Fase 8: auditoría v1.1 — qué falta
Se auditó la v1.0.0 contra los requisitos y se corrigieron los hallazgos (simulación, bots tramposos, contenido y nombres propios, interfaz, ajustes del celular, guardado, exportación y documentación; las decisiones están en DECISIONES.md, sección «Auditoría v1.1»). Para cerrar la fase falta:
1. **Banco de balance completo** (`tools/balance.sh 500`, los 23 bots) porque cambió la simulación, y regenerar BALANCE.md con `python3 tools/balance_report.py --md`. Revisar en especial la oleada 1 (en la v1.0 ignorarla costaba solo 6,6 puntos, apenas por encima del umbral de 5).
2. **Re-medir rendimiento** con la build nueva (`tools/perf_measure.sh`) y actualizar las tablas de RENDIMIENTO.md (cambiaron la nieve de Alto, el tope de FPS de Bajo/Muy bajo en PC y algunos materiales).
3. **Release v1.1.0:** la versión ya está puesta (1.1.0 en `project.godot` y en `export_presets.cfg`, versionCode 2); después del commit, `tools/publish_release.sh v1.1.0`. Comprobar que el `.zip` traiga `LICENCIAS.txt` y que el `.exe` muestre el ícono y «Última Brasa» en sus propiedades.

## Resultados clave (v1.0.0; se actualizan al cerrar la fase 8)
- Balance (BALANCE.md, 500 semillas): competente 71,0 % de victorias; pasivo y aleatorio 0 %; sobrantes con mediana 11–20 % y p90 ≤ 25 %; 14 exploits sin ventaja; ignorar cualquier oleada baja las victorias entre 6,6 y 71 puntos; estancarse desde el día 15 = 0 %.
- Rendimiento (RENDIMIENTO.md): 46 llamadas de dibujo / 13–18 k triángulos en presets de celular, 137 / 71–95 k en PC; RSS 303–412 MB; APK 53 MB, zip de Windows 38 MB.

## Pendiente / no verificable en este entorno
- FPS en hardware real (PC con Intel HD 620 y celular Helio G25/G35): el contenedor no tiene GPU. Se mide con *Ajustes → Ejecutar benchmark* (ver RENDIMIENTO.md, «Cómo verificar los objetivos»).
- La medición de rendimiento todavía no incluye la interfaz ni los zooms extremos de la cámara (el recorrido del benchmark va de 50 a 110 m).

## Cómo publicar una versión nueva
1. `tools/run_tests.sh` y, si se tocó la simulación, el banco completo: `tools/balance.sh 500` (sin segundo argumento corre los 23 bots) + `python3 tools/balance_report.py --md`.
2. `tools/set_version.sh X.Y.Z`: pone la versión en `project.godot` (la que muestra el menú y va en los guardados) y en `export_presets.cfg` (Android: versionCode +1 y versionName; Windows: file_version y product_version). `SAVE_VERSION` (formato de guardado) es otra cosa: solo sube si cambia el formato, con su migración.
3. Commit y push.
4. `tools/publish_release.sh vX.Y.Z`: verifica que la etiqueta coincida con la versión del proyecto (si no, no publica), exporta (el `.zip` de Windows lleva `LICENCIAS.txt`), sube los binarios a la rama `release-assets` y un workflow de Actions crea la Release.

## Notas técnicas
- Simulación en `sim/` (cadena de herencia SimBase → SimMap → SimHeat → SimPeople → SimEconomy → SimSociety → SimWorld → Simulation).
- Contenido en `data/*.json` (solo enteros; `_m` = milésimas). Formato, unidades y cadenas de eventos en `data/LEEME.md`.
- Correr un script headless: `tools/gd.sh 120 res://tests/smoke.gd` (usa `--quit-after` para evitar cuelgues si hay un error de script).
- Capturas: `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/scenes/ui_shot.tscn -- --out=<carpeta> --day=30 [--ui-movil]`.
