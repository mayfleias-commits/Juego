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
- **Recolección a mano = 50% exacto** del edificio básico: carbón 1,0 vs 2,0; madera 0,5 vs 1,0;
  metal 0,3 vs 0,6 por trabajador-hora (cuadrilla de acopio contra extractor, aserradero y mina de
  hierro). Los tres edificios básicos y las cuadrillas de acopio son de exterior y usan la misma
  curva de frío, así la proporción se mantiene en cualquier clima.
  Las mejoras de investigación solo afectan a los edificios (la regla habla del nivel básico).
- **Sobrantes:** "total obtenido" = stock inicial + todo lo que entró a los almacenes. La comida se mide
  en equivalente crudo: (crudo + raciones / proporción de cocina) / (crudo obtenido + raciones iniciales / 2).
- Generador: niveles 1–4 (+8 °C por nivel), sobrecarga +8 °C y ×1,5 carbón, estrés +1,2%/h en
  sobrecarga y −0,25%/h sin ella (no se resetea al apagar). Encender cuesta 30 de carbón y tarda 3 h en calentar.
- Temperatura de edificios con inercia: se calientan 8 °C/h y se enfrían de 3 a 6 °C/h según el
  aislamiento (carpas y barracones 5, casas de piedra 4): apagar de noche enfría las casas.
- Niveles de calor: Congelante (< −30 °C), Muy frío (−30..−21), Frío (−20..−11), Fresco (−10..−1), Confortable (≥ 0).
- Oleadas: los perfiles diarios de `data/climate.json` están calculados para que el mínimo horario
  coincida con los picos pedidos (−45, −55, −65, −75, −90 °C, ±2 por semilla).

## Contenido
- Nombre: **Última Brasa**. Todos los nombres de edificios, leyes, eventos y lugares son originales
  (en la v1.1 se cambiaron seis que eran traducciones literales de nombres de otro juego; ver
  «Auditoría v1.1»).
- Sendas de propósito: **Orden** y **Fe**, 9 leyes cada una (las 2 últimas, extremas).

## Economía y balance (fase 2)
- **Reservas iniciales de comida (v1.1):** 100 de comida cruda y 150 raciones (antes 80 y 120). Las correcciones de la auditoría (viaje por clase, memoria de turnos, caza interrumpida, eventos nuevos con penalidades) hicieron el arranque más duro (el competente bajó de 71 % a 63 % de victorias; las pruebas por separado muestran que cada cambio aporta entre 1,5 y 3 puntos, sin una causa única); se compensó con más comida inicial, que es la reserva que más pesa en los primeros días antes de las oleadas, en lugar de aflojar las reglas arregladas.
- **Población inicial 80** (50 obreros, 15 ingenieros, 15 niños): con menos gente el arranque era imposible para el bot competente.
- **Tasas:** cuadrilla de acopio 1,0 carbón / 0,5 madera / 0,3 metal por trabajador-hora; extractor 2,0, aserradero 1,0, mina de hierro 0,6 (exactamente el doble).
- **Generador:** 4 / 6 / 9 / 12 de carbón por hora según potencia; el radio multiplica 1,0 / 1,25 / 1,5 / 1,75; calor +8 °C por nivel, sobrecarga +8 °C.
- **Esperanza y descontento por objetivo:** cada hora se acercan 1/40 de la distancia a un objetivo que se calcula con las condiciones actuales (sin techo, frío en las casas, hambre, enfermos sin atender, cuerpos, muertes recientes, oleada, turnos largos, generador apagado, edificios sociales, leyes). Los eventos y las leyes dan golpes inmediatos. Así no se puede "acumular" esperanza con spam y una ciudad helada o hambrienta colapsa sola.
- **Edificios sociales con rendimientos decrecientes:** el 2.º edificio del mismo tipo rinde la mitad, el 3.º un cuarto, etc.; además hay un tope total de ±35 puntos.
- **Congelamiento:** quien pasa la hora en su casa (o sin techo) a nivel *Congelante* tiene 0,3 %/h de morir; *Muy frío* 0,03 %/h. El trabajo al aire libre enferma pero no mata directamente.
- **La caza se suspende durante las oleadas** (además de no salir con menos de −42 °C).
- **Perfiles de las oleadas 1 y 2** con días centrales más fríos (los picos siguen siendo −45 y −55 °C).
- **Investigación de nivel 1 sin costo material** (solo puntos) y la de nivel 2 a mitad de precio: con madera escasa la investigación se trababa y la colonia se estancaba.
- **Depósitos finitos:** vetas de carbón 2500–3200, veta profunda 6000–7500, bosques 1200–1600, muros de hielo 1000–1400, vetas de metal 600–780, pilas chicas; zonas de caza 450–800 con regeneración de 2–4 por día.
- **Estrellas:** 1 por sobrevivir, +1 por cada uno: supervivencia ≥ 95 %, población final ≥ 220, esperanza ≥ 80 y descontento ≤ 10 al final, gobierno "humano" (sin leyes extremas ni trabajo infantil y supervivencia ≥ 97 %).
- **Sobrantes y el bot competente:** el bot mantiene reservas razonables (1 o 2 núcleos según cuántos consiguió, ~16 % de la madera al final, colchones de carbón y comida para las oleadas) y gasta los excedentes en mejoras, autómatas e invernaderos industriales, como haría un jugador cuidadoso.
- **"Ignorar una oleada"** se mide con una variante del bot competente que no se prepara para esa oleada y durante ella deja el generador en potencia 1 sin sobrecarga ni calefactores. **Criterio:** la oleada no se puede ignorar si esa variante gana más de 5 puntos porcentuales menos que el competente con las mismas 500 semillas (el mismo margen que los antiexploits; es el umbral que aplica `tools/balance_report.py`). En la v1.0 la oleada 1 lo pasaba por poco (−6,6 pp: en 101 semillas ignorarla convirtió una victoria en derrota y en 68 al revés; la diferencia pareada es significativa, z ≈ 2,5), así que es la que hay que mirar en cada banco nuevo.
- **Bot tramposo de autómatas:** intenta conseguir autómatas *sin pagar* (órdenes inválidas); comprar autómatas pagando núcleos es juego legítimo y no se cuenta como exploit.

## Gráficos y rendimiento (fase 3)
- Todo el arte 3D se genera por código (no hay texturas): cada tipo de edificio es una malla de una sola superficie con color por vértice, dibujada con **un MultiMesh por tipo** (una llamada de dibujo por tipo, sin importar cuántos haya).
- En el renderer Compatibility el color de vértice de un MultiMesh se multiplica por el color de instancia: se activan colores de instancia en blanco.
- Nieve: MultiMesh de quads; la CPU integra la posición de los copos (un vector y un ángulo por cuadro), se dibuja en una sola llamada y el resto se calcula en el shader. Humo: animado en la GPU con `TIME`. Brillo del generador: sprite aditivo (sin postprocesado). Ventanas: emisivas por vértice.
- Ciudadanos: decorativos, MultiMesh; a más de 95 m de la cámara cada uno se dibuja como impostor de 3 quads (6 triángulos) que gira solo sobre Y, el resto con el modelo completo; tope por preset (30/60/150/250).
- Presets: Muy bajo (escala 60 %, sin sombras, 150 copos, 1 luz), Bajo (80 %, sin sombras, 200 copos, 2 luces), Medio (100 %, sombras, 1200 copos, 4 luces), Alto (100 %, sombras, MSAA 2x, 2500 copos, 8 luces). En las oleadas la nieve se duplica (ver «Auditoría v1.1»).
- Límite de FPS: en PC, 60 por defecto en los cuatro presets (también Bajo y Muy bajo, para que la PC mínima pueda pasar de 45 FPS a 720p), configurable en 30, 45, 60 o sin límite. En el celular, 30 como máximo (opción de 20).
- Primer arranque: preset por plataforma/RAM/GPU (celular con < 3 GB → Muy bajo, si no Bajo; PC con render por software, < 6 GB o gráficos Intel integrados anteriores a Iris Xe → Bajo; el resto → Medio) y luego un mini benchmark de 5 s sobre una ciudad sintética en plena tormenta que baja o sube un escalón.
- Batería: en celular, 15 FPS con el juego en pausa (después de 3 s sin tocar) y 20 FPS si nadie toca la pantalla por 20 s; el menú principal va a 30 FPS y baja a 15 tras 10 s sin tocar.

## Interfaz (fase 4)
- Interfaz construida por código con un tema propio. En celular la escala base es 960×540 (en lugar de 1280×720), así un botón de 62 unidades mide ~83 px en una pantalla de 720p (≈ 49 dp en 5,5" y en 6,5" de 20:9).
- En PC los paneles se abren a la derecha; en celular son hojas inferiores. Construir en celular: el edificio fantasma queda en el centro de la pantalla, se mueve el mapa y se confirma.
- Los eventos y pedidos pausan el juego y abren un diálogo; si no se decide, vence el plazo y se aplica la opción por defecto.

## Audio (fase 6)
- Todo el audio se sintetiza con `tools/make_audio.py` (NumPy): viento en bucle que sube con el frío, zumbido del generador según la potencia, música ambiente en bucle de 64 s y efectos. WAV mono 22 kHz (3,8 MB en total).

## Exportación y publicación (fase 7)
- Android sin Gradle (plantilla precompilada), arquitecturas armeabi-v7a + arm64-v8a, firmado con `apksigner` y una clave de release generada por `tools/export.sh` en `secrets/` (fuera de git). Las contraseñas se pasan por variables de entorno, nunca quedan en `export_presets.cfg`.
- Windows: un solo `.exe` con el `.pck` incrustado, comprimido en `.zip` junto con `LICENCIAS.txt`. El ícono y la información de versión del `.exe` (producto «Última Brasa», versión, descripción y copyright, en UTF-16 con tildes) los escribe Godot 4.7 al exportar con `application/modify_resources=true`: el modificador de recursos PE es nativo del motor (`platform/windows/export/template_modifier.cpp`) y no necesita rcedit ni Wine, así que funciona en Linux. En la v1.0 se había dejado desactivado creyendo que hacía falta rcedit; era un error.
- **Release de GitHub mediante Actions:** las herramientas de este entorno no pueden crear Releases ni subir binarios por la API. `tools/publish_release.sh` sube el `.zip` y el `.apk` a una rama huérfana `release-assets` (sin código) junto con un workflow; GitHub Actions crea la Release con la etiqueta pedida, apuntando al commit del código. Los binarios no entran en el historial de la rama de desarrollo.
- **La clave de firma no sale del contenedor por git:** `secrets/` está en `.gitignore`; los dos archivos se entregan al dueño como adjuntos. `tools/export.sh` usa siempre la ruta local de `secrets/`, así la clave sirve aunque el proyecto se copie a otra carpeta.

## Auditoría v1.1 (después de publicar la v1.0.0)
Se auditó el proyecto contra los requisitos originales y se corrigió lo que no cumplía. Decisiones comunes:

1. **Nombres propios.** Cuatro edificios, una investigación y una ley eran traducciones literales de nombres distintivos de otro juego del género. Para alejarse de ellos se cambió el nombre visible; los ids internos no cambian, así que las partidas guardadas siguen sirviendo:

   | id | Antes | Ahora |
   |---|---|---|
   | `puesto_rec` | Puesto de recolección | Cuadrilla de acopio |
   | `faro` | Faro de exploradores | Torre de expediciones |
   | `exp_faro` (investigación) | Faros de exploración | Expediciones al páramo |
   | `guardia` | Puesto de guardia | Cuartel de la ronda |
   | `casa_sanacion` | Casa de sanación | Hospicio de la llama |
   | `ord_nuevo_orden` (ley extrema del Orden) | El Nuevo Orden | El Puño del Consejo |

   En la interfaz, «Equipo del faro #N» pasa a «Expedición #N». Todo texto que nombra estas cosas usa el nombre nuevo con su género gramatical («la Cuadrilla», «la Torre», «el Cuartel», «el Hospicio»).
2. **Celular con límites fijos** (`Settings.is_mobile()`): solo los presets Muy bajo y Bajo, sin sombras, escala de render entre 60 y 80 %, como mucho 30 FPS (opciones 20 y 30) y nieve de 300 copos como máximo. Se imponen siempre, también sobre ajustes guardados por una versión anterior. Copos por preset: Muy bajo 150, Bajo 200, Medio 1200 y Alto 2500. En las oleadas la nieve se duplica, con tope de 300 en el celular o con Muy bajo/Bajo, y sin tope extra en PC con Medio/Alto (2400 y 5000; el MultiMesh tiene instancias suficientes y sigue siendo una sola llamada de dibujo). En PC los cuatro presets arrancan con 60 FPS de límite, configurable.
3. **Versión del juego:** vive en `project.godot` (`application/config/version`, hoy 1.1.0) y `Session.GAME_VERSION` la lee de ahí (menú principal y cabecera de cada guardado). `SAVE_VERSION` es la versión del *formato* de guardado y solo sube si el formato cambia. `tools/set_version.sh X.Y.Z` actualiza `project.godot` y `export_presets.cfg` (Android: version/code +1 y version/name; Windows: file_version y product_version con 4 números), y `tools/publish_release.sh vX.Y.Z` se niega a publicar si la etiqueta no coincide con la versión del proyecto, si hay cambios sin commitear en archivos versionados, si `HEAD` no es el commit destino, si el APK exportado no declara esa versión, si el `.zip` no trae `LICENCIAS.txt` (con `SKIP_EXPORT=1` además exige que `build/` sea más nuevo que el último commit que toca `game/`, `sim/`, `data/`, `project.godot` o `export_presets.cfg`) o si `tools/release/NOTAS.md` no tiene la sección «Novedades de la vX.Y.Z». **Paso obligatorio antes de publicar: actualizar `tools/release/NOTAS.md`** (novedades, tamaños y requisitos de la versión nueva), porque el script la copia tal cual a la Release.
4. **Licencias:** *Créditos → Licencias* muestra en el juego la licencia de Godot (`Engine.get_license_text()`), los avisos de copyright de los componentes de terceros del motor (`Engine.get_copyright_info()`) y los textos de sus licencias (`Engine.get_license_info()`). El `.zip` de Windows lleva lo mismo en `LICENCIAS.txt`, generado por `tools/licencias.gd` desde `tools/export.sh`. El contenido propio **y el código fuente** son CC0 1.0: el repositorio trae `LICENSE` con el texto legal completo, y CREDITOS.md, `LICENCIAS.txt` y la pantalla de Créditos dicen lo mismo (antes el juego decía «licencia propia», CREDITOS.md no nombraba el código y no había `LICENSE`, con lo que el código quedaba legalmente sin licencia). El APK además lleva componentes de la plantilla de Android (AndroidX, Kotlin stdlib, kotlinx.coroutines: Apache-2.0; `libc++_shared.so`: Apache-2.0 con excepciones LLVM); se acreditan en CREDITOS.md, en `LICENCIAS.txt` y en *Créditos → Licencias*, y el texto de la Apache-2.0 sale de `Engine.get_license_info()`. El ícono `assets/icon.svg` es un dibujo manual (fase 0-1), no sale de `tools/make_icons.py`.
5. **Información al pasar el mouse (PC):** sobre un edificio, el generador, una pila o un yacimiento aparece un cartel breve con el nombre y el estado; el clic abre su panel. Mantener presionado (clic o dedo) muestra lo mismo; en el celular, tocar abre el panel.
6. **Balance:** los cambios de simulación de la auditoría arreglan errores; no se ajustaron números para compensarlos. Como cambió la simulación, antes de publicar se vuelve a correr el banco completo (500 semillas × 23 bots) y se regenera BALANCE.md.
7. **Toques y mouse emulado:** se mantiene `emulate_mouse_from_touch=true` en `project.godot`, porque los botones y controles de la interfaz reciben los toques como clics. El código que ya maneja los toques reales (cámara, mundo) ignora los eventos de mouse emulados (`InputEvent.device == InputEvent.DEVICE_ID_EMULATION`) para no procesar dos veces el mismo toque.
8. **Android 8.0 como objetivo, minSdk 24 en el APK.** Sin Gradle (`use_gradle_build=false`) el ajuste `gradle_build/min_sdk` no tiene efecto y el APK declara Android 7.0 (SDK 24) como mínimo técnico. El juego está pensado para Android 8.0 o superior; en 7.x el APK se puede instalar, pero no se prueba ni se da soporte. Subir el mínimo a 26 exigiría pasar a compilación con Gradle y la plantilla de Android instalada, y no se hizo: README y NOTAS lo dicen tal cual.

### Reglas de la simulación que cambiaron
- **Turnos:** el descontento por turnos largos cuenta los edificios que trabajaron horas extra en las últimas 24 h (cambiar el turno por un rato ya no lo esquiva). La fatiga del turno de 24 h alcanza a obreros, ingenieros y niños, según las horas de 22 a 8 que cada uno trabajó de verdad.
- **Azar de los eventos:** el resultado `rand` de cada evento se fija cuando el evento aparece, con una semilla propia que va en el guardado; contestar pedidos del pueblo no consume azar. Así, recargar, esperar o contestar en otro orden no cambia el desenlace.
- **Personal:** cada lote de gente en viaje lleva su clase (obreros, ingenieros, niños), y los edificios médicos y sociales cuentan solo al personal que ya llegó.
- **Muertos:** cada cementerio y cada fosa lleva su propia ocupación.
- **Caza:** si la cabaña se apaga o se reasigna a los cazadores, la partida de caza vuelve.
- **Autómatas:** uno parado por falta de mantenimiento no consume carbón.
- **Guardado:** formato `SAVE_VERSION` 2, con migración automática de las partidas del formato 1.

### Contenido
- **80 eventos:** 49 diarios, 8 encadenados por `followup`, 13 de ubicación, 7 de ley y 3 de oleada. Las cadenas usan dos mecanismos: el efecto `followup` programa otro evento para dentro de N horas, y las marcas (`flag`) que deja una decisión habilitan o bloquean eventos posteriores (condiciones `flag`/`noflag`) y pueden sumar una frase al epílogo. El formato está en `data/LEEME.md`.
- **Núcleos de vapor:** la partida empieza con 1 de reserva (stock inicial de `data/balance.json`). No se fabrican ni se compran (el mercader ya no los vende): solo la exploración da núcleos nuevos (botín de ubicaciones y eventos de exploración).
