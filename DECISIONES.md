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

## Economía y balance (fase 2)
- **Población inicial 80** (50 obreros, 15 ingenieros, 15 niños): con menos gente el arranque era imposible para el bot competente.
- **Tasas:** puesto de recolección 1,0 carbón / 0,5 madera / 0,3 metal por trabajador-hora; extractor 2,0, aserradero 1,0, mina de hierro 0,6 (exactamente el doble).
- **Generador:** 4 / 6 / 9 / 12 de carbón por hora según potencia; el radio multiplica 1,0 / 1,25 / 1,5 / 1,75; calor +8 °C por nivel, sobrecarga +8 °C.
- **Esperanza y descontento por objetivo:** cada hora se acercan 1/40 de la distancia a un objetivo que se calcula con las condiciones actuales (sin techo, frío en las casas, hambre, enfermos sin atender, cuerpos, muertes recientes, oleada, turnos largos, generador apagado, edificios sociales, leyes). Los eventos y las leyes dan golpes inmediatos. Así no se puede "acumular" esperanza con spam y una ciudad helada o hambrienta colapsa sola.
- **Edificios sociales con rendimientos decrecientes:** el 2.º edificio del mismo tipo rinde la mitad, el 3.º un cuarto, etc.; además hay un tope total de ±35 puntos.
- **Congelamiento:** quien pasa la hora en su casa (o sin techo) a nivel *Congelante* tiene 0,3 %/h de morir; *Muy frío* 0,03 %/h. El trabajo al aire libre enferma pero no mata directamente.
- **La caza se suspende durante las oleadas** (además de no salir con menos de −42 °C).
- **Perfiles de las oleadas 1 y 2** con días centrales más fríos (los picos siguen siendo −45 y −55 °C).
- **Investigación de nivel 1 sin costo material** (solo puntos) y la de nivel 2 a mitad de precio: con madera escasa la investigación se trababa y la colonia se estancaba.
- **Depósitos finitos:** vetas de carbón 2500–3200, veta profunda 6000–7500, bosques 1200–1600, muros de hielo 1000–1400, vetas de metal 600–780, pilas chicas; zonas de caza 450–800 con regeneración de 2–4 por día.
- **Estrellas:** 1 por sobrevivir, +1 por cada uno: supervivencia ≥ 95 %, población final ≥ 220, esperanza ≥ 80 y descontento ≤ 10 al final, gobierno "humano" (sin leyes extremas ni trabajo infantil y supervivencia ≥ 97 %).
- **Sobrantes y el bot competente:** el bot mantiene reservas razonables (≈2 núcleos, ~16 % de la madera al final, colchones de carbón y comida para las oleadas) y gasta los excedentes en mejoras, autómatas e invernaderos industriales, como haría un jugador cuidadoso.
- **"Ignorar una oleada"** se mide con una variante del bot competente que no se prepara para esa oleada y durante ella deja el generador en potencia 1 sin sobrecarga ni calefactores.
- **Bot tramposo de autómatas:** intenta conseguir autómatas *sin pagar* (órdenes inválidas); comprar autómatas pagando núcleos es juego legítimo y no se cuenta como exploit.

## Gráficos y rendimiento (fase 3)
- Todo el arte 3D se genera por código (no hay texturas): cada tipo de edificio es una malla de una sola superficie con color por vértice, dibujada con **un MultiMesh por tipo** (una llamada de dibujo por tipo, sin importar cuántos haya).
- En el renderer Compatibility el color de vértice de un MultiMesh se multiplica por el color de instancia: se activan colores de instancia en blanco.
- Nieve: MultiMesh de quads animado 100 % en el shader (sin CPU). Humo: igual. Brillo del generador: sprite aditivo (sin postprocesado). Ventanas: emisivas por vértice.
- Ciudadanos: decorativos, MultiMesh con impostor (un quad) cuando la cámara está lejos; tope por preset (30/60/150/250).
- Presets: Muy bajo (escala 60 %, 30 FPS, sin sombras, 150 copos, 1 luz), Bajo (80 %, 30 FPS, 300 copos, 2 luces), Medio (100 %, 60 FPS, sombras, 1200 copos, 4 luces), Alto (100 %, MSAA 2x, 3000 copos, 8 luces).
- Primer arranque: preset por plataforma/RAM/GPU (celular con < 3 GB → Muy bajo; PC con GPU Intel o < 6 GB → Bajo) y luego un mini benchmark de 5 s sobre una ciudad sintética en plena tormenta que baja o sube un escalón.
- Batería: en celular, 15 FPS con el juego en pausa y 20 FPS si nadie toca la pantalla por 20 s.

## Interfaz (fase 4)
- Interfaz construida por código con un tema propio. En celular la escala base es 960×540 (en lugar de 1280×720), así un botón de 58 unidades mide ~77 px en una pantalla de 720p (≈ 48 dp en 5,5").
- En PC los paneles se abren a la derecha; en celular son hojas inferiores. Construir en celular: el edificio fantasma queda en el centro de la pantalla, se mueve el mapa y se confirma.
- Los eventos y pedidos pausan el juego y abren un diálogo; si no se decide, vence el plazo y se aplica la opción por defecto.

## Audio (fase 6)
- Todo el audio se sintetiza con `tools/make_audio.py` (NumPy): viento en bucle que sube con el frío, zumbido del generador según la potencia, música ambiente en bucle de 64 s y efectos. WAV mono 22 kHz (3,8 MB en total).

## Exportación y publicación (fase 7)
- Android sin Gradle (plantilla precompilada), arquitecturas armeabi-v7a + arm64-v8a, firmado con `apksigner` y una clave de release generada por `tools/export.sh` en `secrets/` (fuera de git). Las contraseñas se pasan por variables de entorno, nunca quedan en `export_presets.cfg`.
- Windows: un solo `.exe` con el `.pck` incrustado, comprimido en `.zip`. No se modifica el ícono del `.exe` (requiere rcedit, que no está disponible en Linux sin Wine).
