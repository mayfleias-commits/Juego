# Última Brasa

Juego de construcción de ciudades y supervivencia en un invierno que no termina, para **PC (Windows)** y **Android**.
Todo el juego está en español. Hecho con Godot 4.7 (renderer *Compatibility*), todo el arte, los textos, los íconos y el sonido son originales. El código y el contenido son de dominio público (CC0 1.0, ver [`LICENSE`](LICENSE) y [CREDITOS.md](CREDITOS.md)).

> Sesenta días de frío extremo. Un generador de vapor en el fondo de un cráter. Cada decisión, una vida.

## Instalación

### PC (Windows 10/11, 64 bits)
1. Bajá `UltimaBrasa-Windows-x64.zip` desde la sección **Releases** del repositorio.
2. Descomprimilo en cualquier carpeta. Trae `UltimaBrasa.exe` (el juego completo, en un solo archivo) y `LICENCIAS.txt` (licencias del motor y de sus componentes).
3. Ejecutá `UltimaBrasa.exe`. Si Windows SmartScreen avisa que la aplicación no está firmada, tocá *Más información → Ejecutar de todos modos*.
4. En el primer arranque el juego mide tu equipo durante 5 segundos y elige la calidad gráfica (se puede cambiar en *Ajustes*).

Requisitos mínimos: Intel de 7.ª generación con gráficos HD 620, 4 GB de RAM, OpenGL 3.3.

### Celular (pensado para Android 8.0 o superior)
1. Bajá `UltimaBrasa-Android.apk` desde **Releases** (desde el celular o pasalo por cable).
2. Abrí el archivo. Android va a pedir permiso para *instalar apps de origen desconocido* para el navegador o el gestor de archivos: aceptalo.
3. Instalá y abrí **Última Brasa**. El juego se juega en horizontal.

El APK declara Android 7.0 como mínimo técnico, pero no se prueba ni se da soporte por debajo de Android 8.0.
Requisitos mínimos: 2 GB de RAM, pantalla de 720p, GPU con OpenGL ES 3.0 (PowerVR GE8320, Adreno 505, Mali-G52 o mejor). El APK incluye ARM de 32 y 64 bits.
En el celular la calidad gráfica se limita a *Muy bajo* o *Bajo*, sin sombras y con 30 FPS como máximo (20 para ahorrar más batería).

Las partidas se guardan solas cada día de juego (con las 3 anteriores de respaldo), al salir al menú y cuando la app pasa a segundo plano o se cierra. También se puede guardar a mano desde el menú (o con F5 en PC).

## Cómo se juega

- **Objetivo:** llegar al final del día 60 con el generador encendido y gente viva. Hay 5 oleadas de frío (−45, −55, −65, −75 y −90 °C). Se gana con 1 a 5 estrellas y un epílogo según tus decisiones.
- **Se pierde si** la esperanza llega a 0, el descontento a 100, muere toda la población o el generador explota.
- **Recursos:** carbón, madera, metal, núcleos de vapor, comida cruda y raciones. Todos los depósitos se agotan y los almacenes tienen límite. Los núcleos de vapor son rarísimos: se empieza con 1 de reserva, no se fabrican ni se compran, y solo la exploración da núcleos nuevos.
- **Producción:** al principio se junta a mano desde las pilas con la *Cuadrilla de acopio* (rinde la mitad que los edificios específicos: extractor, aserradero, mina de hierro). Para explorar el páramo hace falta investigar *Expediciones al páramo* y construir la *Torre de expediciones*.

### Controles
| Acción | PC | Celular |
|---|---|---|
| Mover la cámara | arrastrar con clic izquierdo, WASD o flechas | arrastrar con un dedo |
| Zoom | rueda, R/F | pellizcar |
| Rotar | clic derecho y arrastrar, Q/E | girar con dos dedos |
| Seleccionar (abre el panel del edificio) | clic | tocar |
| Ver información | pasar el mouse: cartel breve con el nombre y el estado del edificio, el generador o la pila; en la barra superior, el detalle de cada recurso. También mantener el clic | mantener presionado; tocar la barra superior |
| Construir | menú *Construir* (B), clic para colocar; Mayús para seguir colocando | menú *Construir*, mover el mapa bajo el fantasma y *Construir aquí* |
| Pausa / velocidad | Espacio, 1, 2, 3 | botones arriba a la derecha |
| Paneles | G generador, L leyes, I investigar, M mapa, H capas, Esc menú | barra inferior |
| Guardar | F5 o *Menú → Guardar partida* | *Menú → Guardar partida* |
| Rendimiento | F3 (FPS y memoria) | *Ajustes → Contador de FPS* |

## Compilar desde el código

En Linux (probado en Ubuntu 24.04):

```bash
tools/setup_env.sh        # instala Godot 4.7.2, plantillas de exportación, SDK de Android mínimo, Xvfb
tools/run_tests.sh        # tests unitarios del núcleo de simulación (headless)
tools/balance.sh 500      # banco de balance completo (los 23 bots, semillas 1000–1499; resultados en bench_out/)
python3 tools/balance_report.py --md   # regenera BALANCE.md con lo que haya en bench_out/
tools/export.sh           # exporta build/UltimaBrasa-Windows-x64.zip (.exe + LICENCIAS.txt) y build/UltimaBrasa.apk
```

`bench_out/` no se sube al repositorio: en un clon nuevo hay que correr el banco completo antes de regenerar BALANCE.md (si falta algún bot, el informe lo marca como «sin datos» y no cumplido). Con un segundo argumento, `tools/balance.sh` corre solo los bots indicados (por ejemplo `tools/balance.sh 100 "competente ola_1"`). En el contenedor de desarrollo el banco completo de 500 semillas tardó unas 2 horas.

### Publicar una versión nueva
```bash
tools/set_version.sh 1.2.0          # versión en project.godot y export_presets.cfg (versionCode de Android +1)
# Actualizar tools/release/NOTAS.md: sección «## Novedades de la v1.2.0», tamaños y requisitos
git commit -am "Versión 1.2.0" && git push
tools/publish_release.sh v1.2.0     # verifica, exporta y sube los binarios para crear la Release
```

**Actualizar `tools/release/NOTAS.md` antes de publicar:** el script copia ese archivo tal cual como notas de la Release, y se niega a publicar si no tiene la sección «Novedades de la v1.2.0». El script también aborta si hay cambios sin commitear en archivos versionados, si `HEAD` no es el commit destino, si el APK exportado no declara la versión pedida o si el `.zip` no trae `LICENCIAS.txt`. Con `SKIP_EXPORT=1` reutiliza lo que haya en `build/`, pero exige que sea más nuevo que el último commit que toca `game/`, `sim/`, `data/`, `project.godot` o `export_presets.cfg`.

Para abrir el proyecto en el editor: `godot -e --path .`

### Clave de firma de Android
`tools/export.sh` firma el APK con una clave de *release* propia del proyecto:

- Almacén: `secrets/ultimabrasa-release.keystore` (alias `ultimabrasa`).
- Contraseña: `secrets/clave_android.env`.

La carpeta `secrets/` está en `.gitignore` y **nunca se sube al repositorio** (tampoco a la rama `release-assets`). Esos dos archivos se generaron en el contenedor de desarrollo y se **enviaron como archivos adjuntos en la conversación de Claude Code** que creó el proyecto; no están en GitHub. **Guardalos en un lugar seguro** (por ejemplo un gestor de contraseñas o un disco propio):

- Para volver a exportar con la misma clave, copiá ambos archivos a `secrets/` en la raíz del proyecto antes de correr `tools/export.sh`.
- Para publicar actualizaciones del APK que se instalen encima de la versión anterior hace falta exactamente la misma clave. Si se pierde, `tools/export.sh` genera una nueva, pero quien tenga instalada la versión vieja tendrá que desinstalarla primero.

`clave_android.env` contiene el alias (`GODOT_ANDROID_KEYSTORE_RELEASE_USER`, que es `ultimabrasa`) y la contraseña (`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`); la contraseña del almacén y la de la clave son la misma. Para firmar a mano: `apksigner sign --ks ultimabrasa-release.keystore --ks-key-alias ultimabrasa archivo.apk`.

## Estructura

| Carpeta | Contenido |
|---|---|
| `sim/` | Núcleo de simulación determinista (solo enteros, paso fijo de 1 hora, sin render). |
| `data/` | Todo el contenido: edificios, leyes, investigación, eventos, pedidos, ubicaciones, clima, balance, textos. Formato, unidades y convenciones en [`data/LEEME.md`](data/LEEME.md). |
| `bots/`, `bench/` | Bots (competente, pasivo, aleatorio, 14 tramposos, 5 variantes que ignoran una oleada y uno que se estanca: 23 en total) y banco de balance. |
| `tests/` | Tests unitarios headless. |
| `game/` | Capa visual e interfaz (solo lee el estado de la simulación). |
| `assets/` | Íconos SVG y sonidos generados por `tools/make_icons.py` y `tools/make_audio.py`; `icon.svg` (ícono del `.exe` y del APK) es un dibujo manual. |
| `tools/` | Scripts de entorno, tests, balance, exportación (con `licencias.gd`), versión (`set_version.sh`), publicación, capturas y benchmarks. |

Ver también: [BALANCE.md](BALANCE.md), [DECISIONES.md](DECISIONES.md), [PROGRESO.md](PROGRESO.md), [RENDIMIENTO.md](RENDIMIENTO.md) y [CREDITOS.md](CREDITOS.md).
