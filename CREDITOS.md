# Créditos

## Contenido original de este proyecto
Todo lo siguiente fue creado específicamente para *Última Brasa* y no usa material de terceros:

- **Código fuente:** GDScript, shaders y scripts de herramientas (`sim/`, `game/`, `bots/`, `bench/`, `tests/`, `tools/`).
- **Diseño, reglas, textos, eventos, leyes, investigaciones, ubicaciones y nombres.** Inspirado en las mecánicas del género de supervivencia y gestión de ciudades, pero sin nombres, textos, logos ni assets de otros juegos.
- **Modelos 3D:** generados por código (`game/world/models.gd`) a partir de primitivas (cajas, cilindros, conos, techos).
- **Shaders:** nieve en techos, ventanas emisivas, nieve, humo, brillo simulado, superposiciones y viñeta de escarcha (`game/shaders/`).
- **Íconos:** los de la interfaz (`assets/icons/`) son SVG generados por script (`tools/make_icons.py`); el ícono del juego (`assets/icon.svg`, el del `.exe` y el del APK) es un dibujo SVG manual de la fase 0-1 que no sale de ese script.
- **Sonido y música:** sintetizados por script con NumPy (`tools/make_audio.py`).

Licencia del código fuente y de estos recursos propios: CC0 1.0 (dominio público). El texto legal completo está en el archivo [`LICENSE`](LICENSE) de la raíz del repositorio.

## Software de terceros
- **Godot Engine 4.7.2** — © 2014-presente, colaboradores de Godot Engine; © 2007-2014, Juan Linietsky, Ariel Manzur. Licencia MIT (Expat). <https://godotengine.org/license>
  El ejecutable incluye componentes de terceros del motor (FreeType, HarfBuzz, ICU, mbedTLS, zlib, etc.) bajo sus propias licencias libres (MIT, BSD, Apache-2.0, Zlib, OFL y otras).
- **Tipografía:** la fuente por defecto que trae el motor Godot (Open Sans, © The Open Sans Project Authors, licencia SIL OFL 1.1).

- **Componentes del APK de Android** (solo en `UltimaBrasa-Android.apk`; vienen con la plantilla de exportación de Godot, verificados en el APK de la v1.0.0): AndroidX (core, fragment, lifecycle, activity y relacionados) y Kotlin (biblioteca estándar) y kotlinx.coroutines — © The Android Open Source Project y © JetBrains s.r.o. y colaboradores, licencia Apache-2.0; `libc++_shared.so` (biblioteca C++ de LLVM) — © colaboradores de LLVM, licencia Apache-2.0 con excepciones LLVM. El texto de la Apache-2.0 está en *Créditos → Licencias*.

### Dónde están los avisos de licencia
La licencia MIT de Godot (y las de sus componentes) pide que el aviso de copyright y el texto de la licencia acompañen cada copia del juego:

- **En el juego (PC y celular):** *Créditos → Licencias* muestra la licencia de Godot, la lista de componentes de terceros con sus titulares y licencias, y el texto completo de cada licencia (lo que devuelven `Engine.get_license_text()`, `Engine.get_copyright_info()` y `Engine.get_license_info()`).
- **En el `.zip` de Windows:** `LICENCIAS.txt`, al lado de `UltimaBrasa.exe`, con lo mismo, la licencia del código y del contenido propio y los componentes del APK de Android. Lo genera `tools/licencias.gd`, que `tools/export.sh` corre en cada exportación.
- Referencia completa del motor: <https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt>.

## Herramientas usadas para producir el juego
Python 3 y NumPy (generación de íconos y sonidos), Xvfb + Mesa (capturas y benchmarks por software), OpenJDK y apksigner (firma del APK).

No se usaron assets de Kenney, Quaternius, Poly Haven ni ambientCG: no hizo falta porque todo se genera por código.
