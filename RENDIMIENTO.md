# RENDIMIENTO — Última Brasa

> **Versión 1.1.0.** Las tablas de mediciones son de la **v1.0.0**. En la v1.1 cambiaron los presets (nieve, límite de FPS en PC, límites fijos en el celular) y algunos materiales y modelos, así que las llamadas de dibujo, los triángulos, la memoria y los FPS **se vuelven a medir con la build de la Release v1.1.0** (`tools/perf_measure.sh`). Mientras tanto, cada sección dice qué cambia y por qué. No se agregó ninguna cifra que no se haya medido.

## Objetivos (requisitos)

| Equipo | Objetivo |
|---|---|
| PC mínima (Intel 7.ª gen. con HD 620, 4 GB) | **≥ 30 FPS a 1080p en Bajo** y **≥ 45 FPS a 720p**; proceso < 1,2 GB; ≤ 800 llamadas de dibujo y ≤ 250 000 triángulos por cuadro |
| Celular mínimo (Helio G25/G35, 2 GB) | En Muy bajo, **30 FPS** en escenas normales y **nunca menos de 25** en el peor caso (oleada + ciudad grande); proceso < 600 MB; ≤ 300 llamadas y ≤ 100 000 triángulos; APK ≤ 150 MB |

## Cómo se midió
- **Escena de prueba (peor caso):** `BenchMode` arma una ciudad de ~100 edificios con **400 ciudadanos simulados**, en plena *Gran Ventisca* (día 55, −90 °C, nevada doble, sobrecarga y humo en todas las chimeneas) y recorre el valle con la cámara durante 20 s.
- **Qué cubre y qué no:** el recorrido va de 50 a 110 m de distancia y de 0,45 a 1,05 rad de inclinación. La cámara del juego permite de 16 a 175 m y de 0,35 a 1,38 rad, así que los zooms más cerrados y más abiertos **no** están en la medición. Se dibujan el mundo 3D y la viñeta de escarcha; la **interfaz** (barra de recursos, paneles) **no está incluida** en las cifras de llamadas de dibujo y triángulos. Las dos cosas quedan para la próxima medición.
- Se ejecuta con la **build exportada** (mismo `.pck` que Windows y Android): `tools/perf_measure.sh` (Linux) o desde el juego en *Ajustes → Ejecutar benchmark* / el ejecutable con `-- --benchmark`. Cada corrida guarda un JSON en `user://benchmark/` con FPS promedio, 1 % más bajo, mínimo, llamadas de dibujo, triángulos, memoria del proceso y VRAM. Se mide sin vsync y con el límite de FPS del ajuste; desde la v1.1 el JSON guarda el límite que rigió de verdad (`limite_fps`), el vsync y la resolución real de la ventana y del 3D.
- **Limitación importante:** el contenedor de desarrollo no tiene GPU, celulares ni una PC con Intel HD 620. Las mediciones se hicieron con **Mesa llvmpipe (render por software en CPU)**, que es muchísimo más lento que cualquier GPU real. Por eso los FPS de abajo **no** representan el hardware mínimo; lo que sí es exacto y portable son las llamadas de dibujo, los triángulos, las texturas y la memoria. Para medir en el hardware real: instalar el juego y usar el botón *Benchmark* (el resultado se muestra en pantalla y queda en un archivo).

## Presupuestos por cuadro (peor caso) — medidos en la v1.0.0

| Preset | Llamadas de dibujo | Triángulos | Presupuesto | Cumple |
|---|---:|---:|---|:---:|
| Muy bajo (celular) | 46 | 13 065 | ≤ 300 / ≤ 100 000 | ✅ |
| Bajo (celular / PC mínima) | 46 | 17 597 | ≤ 300 / ≤ 100 000 | ✅ |
| Medio (PC) | 137 | 71 247 | ≤ 800 / ≤ 250 000 | ✅ |
| Alto (PC) | 137 | 94 563 | ≤ 800 / ≤ 250 000 | ✅ |

La cantidad de llamadas de dibujo casi no crece con el tamaño de la ciudad: cada **tipo** de edificio, pila o yacimiento es un MultiMesh (una llamada), igual que los ciudadanos, la nieve y el humo. En Medio/Alto la diferencia la ponen las sombras (cada objeto se dibuja de nuevo en el mapa de sombras).

**Qué cambia en la v1.1 (se re-mide en la v1.1.0):** la nieve en la oleada pasa de 3000 a 5000 copos en Alto (cada copo es un quad de 2 triángulos y todos van en la misma llamada de dibujo); en Muy bajo, Bajo y Medio la nieve de la oleada queda igual (300, 300 y 2400). También cambiaron materiales y modelos del mundo, por lo que los triángulos de todos los presets pueden moverse. El margen frente a los presupuestos es grande (46 de 300 y 137 de 800 llamadas), pero la cifra nueva sale de la medición, no de esta estimación.

## Memoria — medida en la v1.0.0 (RSS del proceso, pico durante el benchmark)

| Preset | 1280×720 | 1920×1080 | Presupuesto |
|---|---:|---:|---|
| Muy bajo | 303 MB | 323 MB | celular < 600 MB ✅ |
| Bajo | 307 MB | 331 MB | celular < 600 MB ✅ |
| Medio | 334 MB | 345 MB | PC < 1,2 GB ✅ |
| Alto | 357 MB | 412 MB | PC < 1,2 GB ✅ |

Con llvmpipe los *framebuffers* y las texturas viven en la RAM del proceso; con una GPU real (o la memoria compartida de un celular) ese número baja. VRAM reportada por el motor: 17–57 MB. Se re-mide en la v1.1.0.

## Presets y límites (v1.1)

| Preset | Escala de render | Sombras | Copos (oleada) | Ciudadanos visibles | Luces | Límite de FPS |
|---|---:|:---:|---:|---:|---:|---|
| Muy bajo | 60 % | no | 150 (300) | 30 | 1 | PC 60 · celular 30 |
| Bajo | 80 % | no | 200 (300) | 60 | 2 | PC 60 · celular 30 |
| Medio (solo PC) | 100 % | sí | 1200 (2400) | 150 | 4 | 60 |
| Alto (solo PC) | 100 % + MSAA 2x | sí | 2500 (5000) | 250 | 8 | 60 |

- **Celular:** los límites son fijos y se imponen siempre, también sobre ajustes guardados por una versión anterior: solo Muy bajo y Bajo, sin sombras, escala de render entre 60 y 80 %, 30 FPS como máximo (o 20, a elección; no se puede quitar el límite) y nieve con tope de 300 copos aun en las oleadas.
- **PC:** 60 FPS de límite por defecto en los cuatro presets (configurable en 30, 45, 60 o sin límite). En la v1.0 Bajo y Muy bajo tenían 30 FPS fijos también en PC, y como la detección automática elige Bajo en una PC con gráficos Intel HD, el objetivo de 45 FPS a 720p era inalcanzable por diseño. La nieve de Muy bajo y Bajo tiene el mismo tope de 300 en PC; Medio y Alto la duplican sin tope extra.

## Otros requisitos

| Requisito | Estado |
|---|---|
| Texturas ≤ 1024 px (≤ 512 en celular, ETC2) | ✅ El juego no usa texturas de imagen: todo es geometría con color por vértice. Solo íconos SVG de 64 px. Importación ETC2/ASTC activada para Android. |
| Sin sombras ni postprocesado en celular | ✅ En el celular solo existen Muy bajo y Bajo, y las sombras quedan apagadas aunque un ajuste guardado diga otra cosa. El brillo del generador y de las estaciones es un sprite aditivo. |
| Nieve ≤ 300 partículas en celular | ✅ 150 (Muy bajo) / 200 (Bajo); en las oleadas se duplica con tope de 300. Animada 100 % en GPU. |
| Ciudadanos visibles ≤ 60 en celular | ✅ 30 (Muy bajo) / 60 (Bajo). Impostor de un quad cuando la cámara se aleja. |
| Escala de render 60–80 % en celular | ✅ 60 % / 80 %; en el celular el control de *Ajustes* no sale de ese rango. |
| 30 FPS máximo en celular, menos en pausa o sin tocar | ✅ 30 FPS (o 20); 15 en pausa (a los 3 s sin tocar) y 20 si nadie toca la pantalla por 20 s. |
| Luces dinámicas ≤ 8 PC / ≤ 2 celular | ✅ 1/2/4/8 por preset (sol + generador + estaciones de vapor). Ventanas emisivas. |
| Contador de FPS y RAM | ✅ F3 en PC, *Ajustes → Contador* en celular (RAM real del proceso). |
| APK ≤ 150 MB | ✅ 53 MB en la v1.0.0 (ARM 32 y 64 bits). Windows: 38 MB comprimido. |
| 400 ciudadanos simulados | ✅ La economía es por grupos: un paso de simulación (1 hora) con 368–400 habitantes y 79 edificios costó **1,1 ms** en promedio y 3,3 ms en el peor caso en el contenedor (Xeon 2,1 GHz), medido en la v1.0.0. En un Cortex-A53 se estima 8–12 veces más: ~10–35 ms una vez cada 3,75 s a velocidad x3, sin efecto en el promedio de FPS. Guardar la partida: 135 KB, 1,4 ms. |

## FPS con render por software — v1.0.0 (solo como referencia)
Medición final de la v1.0.0, en el contenedor con llvmpipe y 4 vCPU libres, peor caso de 400 habitantes en la Gran Ventisca:

| Preset | 1280×720 promedio / 1 % bajo | 1920×1080 promedio / 1 % bajo |
|---|---:|---:|
| Muy bajo | 30,0 / 29,9 (tope de 30) | 24,3 / 16,7 |
| Bajo | 29,9 / 27,7 (tope de 30) | 19,4 / 15,8 |
| Medio | 18,7 / 12,7 | 10,6 / 6,9 |
| Alto | 9,2 / 5,6 | 5,3 / 3,7 |

En esta tabla Muy bajo y Bajo a 720p están recortados por el tope de 30 FPS que esos presets tenían en PC en la v1.0; con el tope de 60 de la v1.1 se re-miden en la v1.1.0. Aun renderizando todo por CPU, los presets de celular llegan a 30 FPS a 720p. Una Intel HD 620 rinde del orden de 20–40 veces más que llvmpipe en escenas así, y una Mali-G52/Adreno 505 del orden de 10–20 veces más, por lo que los objetivos son esperables, pero **no se pudieron verificar en el hardware real**.

## Cómo verificar los objetivos en el hardware real
- **PC mínima, 45 FPS a 720p:** dejar el preset que elige el juego en el primer arranque (Bajo en una HD 620) con el límite de 60 FPS, y correr desde una consola `UltimaBrasa.exe --resolution 1280x720 -- --benchmark`. En el JSON, `fps_promedio` tiene que ser ≥ 45 con `limite_fps` 60 (si dice 30, el límite está mal configurado y el objetivo no se puede medir).
- **PC mínima, 30 FPS a 1080p:** lo mismo con `--resolution 1920x1080` (el JSON guarda la resolución real de la ventana en `resolucion`): `fps_promedio` ≥ 30.
- **Celular:** *Ajustes → Ejecutar benchmark* con Muy bajo: `fps_promedio` cerca de 30 y `fps_minimo` ≥ 25. El resultado se muestra en pantalla con un botón para copiarlo.
