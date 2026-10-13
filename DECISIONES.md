# DECISIONES

Registro de decisiones tomadas de forma autónoma (fecha: 2026-10-13 en adelante).

## Motor y entorno
- **Godot 4.7.2 estable** (la última 4.x publicada en GitHub al iniciar). Renderer *Compatibility*.
- `godotengine.org` y `dl.google.com` están bloqueados por el proxy del entorno: Godot y las
  plantillas se bajan de los *releases* de GitHub; el SDK de Android se arma con los paquetes de
  Ubuntu (`android-sdk`, `apksigner`, `zipalign`, build-tools 29.0.3/debian). Ver `tools/setup_env.sh`.
- Render de pruebas: Xvfb + Mesa llvmpipe (OpenGL 3.3 por software) para capturas y contar
  draw calls/triángulos. Los FPS reales en el hardware mínimo no se pueden medir acá.

## Simulación
- **Paso fijo de 1 hora de juego.** Un día = 24 pasos. A x1 un día dura 4,5 min reales (11,25 s por hora);
  la capa visual interpola dentro de la hora.
- **Enteros siempre.** Recursos, ánimo y tasas en punto fijo ×1000 (`FX`). Probabilidades en "pcm"
  (por cien mil). Azar: xorshift32 propio con máscara de 32 bits, estado guardado en la partida.
- El estado es un `Dictionary` serializado con `var_to_bytes` (mantiene tipos enteros y el orden de
  las claves). El hash SHA-256 de ese binario sirve para comparar ejecuciones.
- Las órdenes se aplican **entre pasos**; por eso pausar/acelerar no altera resultados.
- Economía por edificio y por grupo: la población se guarda por clase (obreros, ingenieros, niños)
  y estado (sano, leve, grave). Los ciudadanos que caminan en pantalla son decorativos.
- **Asignación con viaje:** el jugador fija el personal *deseado*; la simulación lo llena con gente
  sana y cada lote nuevo tarda 1–2 h en llegar (no produce mientras viaja).
- **Recolección a mano = 50% exacto** del edificio básico: carbón 0,5 vs 1,0; madera 0,3 vs 0,6;
  metal 0,2 vs 0,4 por trabajador-hora. Los tres edificios básicos y los puestos de recolección son
  de exterior y usan la misma curva de frío, así la proporción se mantiene en cualquier clima.
  Las mejoras de investigación solo afectan a los edificios (la regla habla del nivel básico).
- **Sobrantes:** "total obtenido" = stock inicial + todo lo que entró a los almacenes. La comida se mide
  en equivalente crudo: (crudo + raciones / proporción de cocina) / (crudo obtenido + raciones iniciales / 2).
- Generador: niveles 1–4 (+10 °C por nivel), sobrecarga +10 °C y ×1,5 carbón, estrés +1,2%/h en
  sobrecarga y −0,25%/h sin ella (no se resetea al apagar). Encender cuesta 30 de carbón y tarda 3 h en calentar.
- Temperatura de edificios con inercia (se enfrían 2–5 °C/h según aislamiento): apagar de noche
  enfría las casas.
- Niveles de calor: Congelante (< −30 °C), Muy frío (−30..−21), Frío (−20..−11), Fresco (−10..−1), Confortable (≥ 0).
- Oleadas: los perfiles diarios de `data/climate.json` están calculados para que el mínimo horario
  coincida con los picos pedidos (−45, −55, −65, −75, −90 °C, ±2 por semilla).

## Contenido
- Nombre: **Última Brasa**. Todos los nombres de edificios, leyes, eventos y lugares son originales.
- Sendas de propósito: **Orden** y **Fe**, 9 leyes cada una (las 2 últimas, extremas).
