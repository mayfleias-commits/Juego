**Última Brasa** — supervivencia y gestión de una colonia en un invierno que no termina. Todo en español, para PC con Windows y celulares Android.

## Descargas
| Archivo | Para | Tamaño aprox. |
|---|---|---|
| `UltimaBrasa-Windows-x64.zip` | Windows 10/11 de 64 bits (trae `UltimaBrasa.exe` y `LICENCIAS.txt`) | 39 MB |
| `UltimaBrasa-Android.apk` | Android 8.0 o superior (ARM de 32 y 64 bits) | 53 MB |

### Instalar en PC
1. Bajá `UltimaBrasa-Windows-x64.zip` y descomprimilo en cualquier carpeta.
2. Ejecutá `UltimaBrasa.exe`. Si SmartScreen avisa que la aplicación no está firmada: *Más información → Ejecutar de todos modos*.
3. En el primer arranque el juego mide tu equipo 5 segundos y elige la calidad gráfica (se cambia en *Ajustes*).

### Instalar en el celular
1. Bajá `UltimaBrasa-Android.apk` desde el celular (o pasalo por cable).
2. Abrilo y aceptá *instalar apps de origen desconocido* para el navegador o el gestor de archivos.
3. Instalá y abrí **Última Brasa** (se juega en horizontal). Se instala encima de la versión anterior y conserva las partidas.

## Novedades de la v1.1.0
- **Nombres propios** para cuatro edificios, una investigación y una ley: *Cuadrilla de acopio*, *Torre de expediciones* (y la investigación *Expediciones al páramo*), *Cuartel de la ronda*, *Hospicio de la llama* y *El Puño del Consejo*.
- **80 eventos** (17 nuevos), con cadenas de consecuencias que vuelven días después. Los núcleos de vapor solo se consiguen explorando (el mercader ya no los vende).
- **Simulación corregida:** turnos largos y fatiga del turno de 24 h, azar de los eventos fijo desde que aparecen, viaje del personal, ocupación de cementerios y fosas, caza, autómatas parados. Las partidas de la v1.0 se convierten solas al formato nuevo.
- **Celular:** la calidad se limita a Muy bajo o Bajo, sin sombras, con escala de render de 60 a 80 % y 30 FPS como máximo (o 20).
- **PC:** 60 FPS por defecto en todos los presets; al pasar el mouse sobre un edificio aparece su nombre y estado; F5 guarda.
- **Guardado más seguro:** cada guardado se escribe aparte y se verifica antes de reemplazar al anterior; las partidas dañadas o de una versión más nueva se muestran con el motivo.
- **Licencias:** *Créditos → Licencias* muestra los avisos del motor Godot y de sus componentes; el `.zip` trae `LICENCIAS.txt` y el `.exe` tiene ícono e información de versión propios.

## Qué trae
- 60 días de campaña con 5 oleadas de frío (−45 a −90 °C) anunciadas con pronóstico.
- Generador con niveles, sobrecarga, estrés y radio; estaciones de vapor; 37 edificios.
- Leyes de adaptación y dos sendas excluyentes (Orden y Fe), 38 investigaciones en 4 ramas, 18 ubicaciones para explorar, 80 eventos y 15 pedidos del pueblo.
- Final con 1 a 5 estrellas y epílogo según tus decisiones.
- Controles completos con mouse y teclado o táctiles; 4 presets gráficos en PC (2 en el celular) con detección automática; guardado automático diario.

## Balance
Banco headless de 500 partidas por bot con 23 bots (competente, pasivo, aleatorio, 14 tramposos, 5 que ignoran una oleada y uno que se estanca). Criterios: el competente gana entre el 65 y el 85 %, el pasivo y el aleatorio pierden casi siempre, los sobrantes quedan por debajo del 30 %, ningún exploit mejora el resultado y ninguna oleada se puede ignorar. Cifras y detalle en `BALANCE.md`.

Las FPS no se pudieron medir en hardware real (el entorno de desarrollo no tiene GPU); las llamadas de dibujo, triángulos y memoria sí, ver `RENDIMIENTO.md`.
