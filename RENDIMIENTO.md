# RENDIMIENTO — Última Brasa

## Cómo se midió
- **Escena de prueba (peor caso):** `BenchMode` arma una ciudad de ~100 edificios con **400 ciudadanos simulados**, en plena *Gran Ventisca* (día 55, −90 °C, nevada doble, sobrecarga y humo en todas las chimeneas) y recorre el valle con la cámara durante 20 s (incluye zooms muy abiertos y muy cerrados).
- Se ejecuta con la **build exportada** (mismo `.pck` que Windows y Android): `tools/perf_measure.sh` (Linux) o desde el juego en *Ajustes → Ejecutar benchmark* / el ejecutable con `-- --benchmark`. Cada corrida guarda un JSON en `user://benchmark/` con FPS promedio, 1 % más bajo, mínimo, llamadas de dibujo, triángulos, memoria del proceso y VRAM.
- **Limitación importante:** el contenedor de desarrollo no tiene GPU, celulares ni una PC con Intel HD 620. Las mediciones se hicieron con **Mesa llvmpipe (render por software en CPU)**, que es muchísimo más lento que cualquier GPU real. Por eso los FPS de abajo **no** representan el hardware mínimo; lo que sí es exacto y portable son las llamadas de dibujo, los triángulos, las texturas y la memoria. Para medir en el hardware real: instalar el juego y usar el botón *Benchmark* (el resultado queda en un archivo).

## Presupuestos por cuadro (peor caso) — medidos

| Preset | Llamadas de dibujo | Triángulos | Presupuesto | Cumple |
|---|---:|---:|---|:---:|
| Muy bajo (celular) | 46 | 13 065 | ≤ 300 / ≤ 100 000 | ✅ |
| Bajo (celular / PC mínima) | 46 | 17 597 | ≤ 300 / ≤ 100 000 | ✅ |
| Medio (PC) | 137 | 71 247 | ≤ 800 / ≤ 250 000 | ✅ |
| Alto (PC) | 137 | 94 563 | ≤ 800 / ≤ 250 000 | ✅ |

La cantidad de llamadas de dibujo casi no crece con el tamaño de la ciudad: cada **tipo** de edificio, pila o yacimiento es un MultiMesh (una llamada), igual que los ciudadanos, la nieve y el humo. En Medio/Alto la diferencia la ponen las sombras (cada objeto se dibuja de nuevo en el mapa de sombras).

## Memoria — medida (RSS del proceso, pico durante el benchmark)

| Preset | 1280×720 | 1920×1080 | Presupuesto |
|---|---:|---:|---|
| Muy bajo | 303 MB | 323 MB | celular < 600 MB ✅ |
| Bajo | 307 MB | 331 MB | celular < 600 MB ✅ |
| Medio | 334 MB | 345 MB | PC < 1,2 GB ✅ |
| Alto | 357 MB | 412 MB | PC < 1,2 GB ✅ |

Con llvmpipe los *framebuffers* y las texturas viven en la RAM del proceso; con una GPU real (o la memoria compartida de un celular) ese número baja. VRAM reportada por el motor: 17–57 MB.

## Otros requisitos

| Requisito | Estado |
|---|---|
| Texturas ≤ 1024 px (≤ 512 en celular, ETC2) | ✅ El juego no usa texturas de imagen: todo es geometría con color por vértice. Solo íconos SVG de 64 px. Importación ETC2/ASTC activada para Android. |
| Sin sombras ni postprocesado en celular | ✅ Presets Muy bajo y Bajo sin sombras; el brillo del generador y de las estaciones es un sprite aditivo. |
| Nieve ≤ 300 partículas en celular | ✅ 150 (Muy bajo) / 300 (Bajo), con tope de 300 aun en oleadas. Animada 100 % en GPU. |
| Ciudadanos visibles ≤ 60 en celular | ✅ 30 (Muy bajo) / 60 (Bajo). Impostor de un quad cuando la cámara se aleja. |
| Escala de render 60–80 % en celular | ✅ 60 % / 80 %, ajustable en *Ajustes*. |
| 30 FPS máximo en celular, menos en pausa o sin tocar | ✅ 30 FPS; 15 en pausa, 20 si nadie toca por 20 s. |
| Luces dinámicas ≤ 8 PC / ≤ 2 celular | ✅ 1/2/4/8 por preset (sol + generador + estaciones de vapor). Ventanas emisivas. |
| Contador de FPS y RAM | ✅ F3 en PC, *Ajustes → Contador* en celular (RAM real del proceso). |
| APK ≤ 150 MB | ✅ 53 MB (ARM 32 y 64 bits). Windows: 38 MB comprimido. |
| 400 ciudadanos simulados | ✅ La economía es por grupos: un paso de simulación (1 hora) con 368–400 habitantes y 79 edificios cuesta **1,1 ms** en promedio y 3,3 ms en el peor caso en el contenedor (Xeon 2,1 GHz). En un Cortex-A53 se estima 8–12 veces más: ~10–35 ms una vez cada 3,75 s a velocidad x3, sin efecto en el promedio de FPS. Guardar la partida: 135 KB, 1,4 ms. |

## FPS con render por software (solo como referencia)
Medición final (después del pase de materiales de PC), en el contenedor con llvmpipe y 4 vCPU libres, peor caso de 400 habitantes en la Gran Ventisca:

| Preset | 1280×720 promedio / 1 % bajo | 1920×1080 promedio / 1 % bajo |
|---|---:|---:|
| Muy bajo | 30,0 / 29,9 (tope de 30) | 24,3 / 16,7 |
| Bajo | 29,9 / 27,7 (tope de 30) | 19,4 / 15,8 |
| Medio | 18,7 / 12,7 | 10,6 / 6,9 |
| Alto | 9,2 / 5,6 | 5,3 / 3,7 |

Aun renderizando todo por CPU, los presets de celular llegan al tope de 30 FPS a 720p. Una Intel HD 620 rinde del orden de 20–40 veces más que llvmpipe en escenas así, y una Mali-G52/Adreno 505 del orden de 10–20 veces más, por lo que los objetivos (30 FPS en Bajo a 1080p en la PC mínima; 30 FPS en Muy bajo en celular, nunca menos de 25) son esperables, pero **no se pudieron verificar en el hardware real**. Para hacerlo: *Ajustes → Ejecutar benchmark* en el equipo; el resultado queda en un archivo JSON (la ruta se muestra al terminar).
