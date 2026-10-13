# Última Brasa

Juego de construcción de ciudades y supervivencia en un invierno que no termina, para **PC (Windows)** y **Android**.
Todo el juego está en español. Hecho con Godot 4.7 (renderer *Compatibility*), todo el arte, los textos, los íconos y el sonido son originales.

> Sesenta días de frío extremo. Un generador de vapor en el fondo de un cráter. Cada decisión, una vida.

## Instalación

### PC (Windows 10/11, 64 bits)
1. Bajá `UltimaBrasa-Windows-x64.zip` desde la sección **Releases** del repositorio.
2. Descomprimilo en cualquier carpeta.
3. Ejecutá `UltimaBrasa.exe`. Si Windows SmartScreen avisa que la aplicación no está firmada, tocá *Más información → Ejecutar de todos modos*.
4. En el primer arranque el juego mide tu equipo durante 5 segundos y elige la calidad gráfica (se puede cambiar en *Ajustes*).

Requisitos mínimos: Intel de 7.ª generación con gráficos HD 620, 4 GB de RAM, OpenGL 3.3.

### Celular (Android 8.0 o superior)
1. Bajá `UltimaBrasa-Android.apk` desde **Releases** (desde el celular o pasalo por cable).
2. Abrí el archivo. Android va a pedir permiso para *instalar apps de origen desconocido* para el navegador o el gestor de archivos: aceptalo.
3. Instalá y abrí **Última Brasa**. El juego se juega en horizontal.

Requisitos mínimos: 2 GB de RAM, pantalla de 720p, GPU con OpenGL ES 3.0 (PowerVR GE8320, Adreno 505, Mali-G52 o mejor). El APK incluye ARM de 32 y 64 bits.

Las partidas se guardan solas cada día de juego y cuando la app pasa a segundo plano.

## Cómo se juega

- **Objetivo:** llegar al final del día 60 con el generador encendido y gente viva. Hay 5 oleadas de frío (−45, −55, −65, −75 y −90 °C). Se gana con 1 a 5 estrellas y un epílogo según tus decisiones.
- **Se pierde si** la esperanza llega a 0, el descontento a 100, muere toda la población o el generador explota.
- **Recursos:** carbón, madera, metal, núcleos de vapor (rarísimos, solo explorando), comida cruda y raciones. Todos los depósitos se agotan y los almacenes tienen límite.

### Controles
| Acción | PC | Celular |
|---|---|---|
| Mover la cámara | arrastrar con clic izquierdo, WASD o flechas | arrastrar con un dedo |
| Zoom | rueda, R/F | pellizcar |
| Rotar | clic derecho y arrastrar, Q/E | girar con dos dedos |
| Seleccionar | clic | tocar |
| Ver información | pasar el mouse | mantener presionado |
| Construir | menú *Construir* (B), clic para colocar; Mayús para seguir colocando | menú *Construir*, mover el mapa bajo el fantasma y *Construir aquí* |
| Pausa / velocidad | Espacio, 1, 2, 3 | botones arriba a la derecha |
| Paneles | G generador, L leyes, I investigar, M mapa, H capas, Esc menú | barra inferior |
| Rendimiento | F3 (FPS y memoria) | *Ajustes → Contador de FPS* |

## Compilar desde el código

En Linux (probado en Ubuntu 24.04):

```bash
tools/setup_env.sh        # instala Godot 4.7.2, plantillas de exportación, SDK de Android mínimo, Xvfb
tools/run_tests.sh        # tests unitarios del núcleo de simulación (headless)
tools/balance.sh 500      # banco de balance con bots (resultados en bench_out/)
python3 tools/balance_report.py --md   # regenera BALANCE.md
tools/export.sh           # exporta build/UltimaBrasa-Windows-x64.zip y build/UltimaBrasa.apk
```

Para abrir el proyecto en el editor: `godot -e --path .`

### Clave de firma de Android
`tools/export.sh` firma el APK con una clave de *release* propia del proyecto:

- Almacén: `secrets/ultimabrasa-release.keystore` (alias `ultimabrasa`).
- Contraseña: `secrets/clave_android.env`.

La carpeta `secrets/` está en `.gitignore` y **nunca se sube al repositorio**. La clave se generó en el contenedor de desarrollo y se entregó aparte al dueño del proyecto (no está en GitHub). **Guardala en un lugar seguro**: para publicar actualizaciones del APK que se instalen encima de la versión anterior hace falta exactamente la misma clave. Si se pierde, `tools/export.sh` genera una nueva, pero los usuarios tendrán que desinstalar la versión vieja.

## Estructura

| Carpeta | Contenido |
|---|---|
| `sim/` | Núcleo de simulación determinista (solo enteros, paso fijo de 1 hora, sin render). |
| `data/` | Todo el contenido: edificios, leyes, investigación, eventos, pedidos, ubicaciones, clima, balance, textos. |
| `bots/`, `bench/` | Bots (competente, pasivo, aleatorio, 14 tramposos, variantes) y banco de balance. |
| `tests/` | Tests unitarios headless. |
| `game/` | Capa visual e interfaz (solo lee el estado de la simulación). |
| `assets/` | Íconos SVG y sonidos generados por `tools/make_icons.py` y `tools/make_audio.py`. |
| `tools/` | Scripts de entorno, tests, balance, exportación, capturas y benchmarks. |

Ver también: [BALANCE.md](BALANCE.md), [DECISIONES.md](DECISIONES.md), [PROGRESO.md](PROGRESO.md), [RENDIMIENTO.md](RENDIMIENTO.md) y [CREDITOS.md](CREDITOS.md).
