# Créditos

## Contenido original de este proyecto
Todo lo siguiente fue creado específicamente para *Última Brasa* y no usa material de terceros:

- **Diseño, reglas, textos, eventos, leyes, investigaciones, ubicaciones y nombres.** Inspirado en las mecánicas del género de supervivencia y gestión de ciudades, pero sin nombres, textos, logos ni assets de otros juegos.
- **Modelos 3D:** generados por código (`game/world/models.gd`) a partir de primitivas (cajas, cilindros, conos, techos).
- **Shaders:** nieve en techos, ventanas emisivas, nieve, humo, brillo simulado, superposiciones y viñeta de escarcha (`game/shaders/`).
- **Íconos:** SVG dibujados a mano por script (`tools/make_icons.py`).
- **Sonido y música:** sintetizados por script con NumPy (`tools/make_audio.py`).

Licencia de estos recursos propios: CC0 1.0 (dominio público).

## Software de terceros
- **Godot Engine 4.7.2** — © Juan Linietsky, Ariel Manzur y colaboradores de Godot. Licencia MIT. <https://godotengine.org/license>
  El ejecutable incluye componentes de terceros de Godot (FreeType, ICU, mbedTLS, etc.) bajo sus propias licencias libres; ver `Acerca de → Licencias de terceros` en el editor de Godot o <https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt>.
- **Tipografía:** la fuente por defecto que trae el motor Godot (Open Sans, licencia libre incluida con el motor).

## Herramientas usadas para producir el juego
Python 3 y NumPy (generación de íconos y sonidos), Xvfb + Mesa (capturas y benchmarks por software), OpenJDK y apksigner (firma del APK).

No se usaron assets de Kenney, Quaternius, Poly Haven ni ambientCG: no hizo falta porque todo se genera por código.
