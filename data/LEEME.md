# Datos del juego (`data/`)

Todo el contenido de *Última Brasa* vive en estos JSON: edificios, costos, leyes,
investigaciones, eventos, pedidos, ubicaciones, clima, constantes de balance y
textos. La simulación (`sim/`) los carga con `sim/data_db.gd` y no tiene contenido
escrito en el código.

| Archivo | Contenido |
|---|---|
| `balance.json` | Constantes de balance: arranque, mapa, generador, calor, producción, comida, salud, ánimo, leyes, eventos, pedidos, exploración y estrellas. |
| `climate.json` | Temperatura base, variación por hora y las 5 oleadas de frío. |
| `buildings.json` | Edificios: costo, tamaño, tipo, personal, producción, calor. |
| `research.json` | Árbol de investigación (4 ramas × 4 niveles). |
| `laws.json` | Libro de leyes: adaptación y las dos sendas de propósito (Orden y Fe). |
| `events.json` | Eventos narrativos con sus opciones y consecuencias. |
| `requests.json` | Pedidos del pueblo: objetivo, plazo, premio y castigo. |
| `locations.json` | Ubicaciones del páramo para explorar. |
| `texts.json` | Mensajes, notificaciones, finales y epílogos. |

## Reglas generales

- **Solo enteros.** La simulación no usa números con coma: `DataDB` convierte cada
  número a entero y marca un error si alguno no lo es (`1.5` es un error; `2.0`
  pasa como `2`). Para valores fraccionarios se usan escalas fijas, indicadas por
  el sufijo de la clave.
- **Los `id` no se cambian.** Las partidas guardadas, los bots del banco de
  balance y la capa visual (modelos 3D, íconos) referencian los `id`. Los nombres
  visibles (`name`, `title`, `text`, `desc`) se pueden cambiar libremente.
- Los archivos con una lista `"list"` (edificios, investigación, leyes, eventos,
  pedidos, ubicaciones) se convierten en diccionarios `id → definición`, en el
  mismo orden del archivo.
- Las claves `_doc` son comentarios: la simulación no las lee.
- Todo texto visible va en español rioplatense (voseo).

## Unidades y sufijos

| Sufijo o caso | Significado | Ejemplo |
|---|---|---|
| `_m` | Milésimas (punto fijo, escala 1000). | `rate_m: 2000` = 2 unidades por trabajador y hora. `portion_m: 500` = media ración. |
| `_pcm` | Por cien mil. Probabilidad o tasa **por hora**, salvo que se indique otra cosa. | `frost_death_pcm: 300` = 0,3 % por persona y hora. |
| `_pct` | Porcentaje. En los modificadores se suma a 100. | `gen_coal_pct: -15` = el generador gasta 85 %. |
| `_h` | Horas de juego (1 paso de simulación = 1 hora). | `build_h: 12`, `timeout_h: 12`. |
| `_days` | Días de juego. | `cooldown_days: 7`. |
| `_pts` | Puntos del **objetivo** de esperanza o descontento cuando la fracción de población afectada es 1,0. | `hunger_disc_pts: 50`. |
| Sin sufijo, recursos | Unidades enteras de recurso. | Costos, botín, almacenes, efectos `res`. |
| Sin sufijo, temperaturas | Grados Celsius enteros. | `thresholds`, `profile`, `insul`. |
| Esperanza y descontento | Puntos de 0 a 100 (en el estado se guardan en milésimas). | `hope: 60`. |

Hay valores en escala que **no llevan sufijo** porque son tablas:

- `prod.level_mult` y el segundo número de cada par de `prod.outdoor_curve` están
  en milésimas (1000 = 100 % de productividad).
- Las tasas de `health` sin sufijo (`*_heal`, `*_death`, `untreated_light_worsen`)
  están en **pcm por hora**.
- `mood.cold_weights` está en porcentaje (300 = el triple de peso).
- `food.zones[].regen` está en unidades **por día** (se repone al terminar cada día).

Recursos válidos: `carbon`, `madera`, `metal`, `nucleos`, `crudo` (comida cruda) y
`raciones`. Clases de población: `obreros`, `ingenieros` y `ninos`. Niveles de
calor: 0 Congelante, 1 Muy frío, 2 Frío, 3 Fresco, 4 Confortable.

Los núcleos de vapor solo se consiguen explorando: botín de ubicaciones y eventos
de ubicación (`trigger: "location"`). Ningún otro evento, ley o pedido debe dar
núcleos. La partida arranca con 1 núcleo de reserva (`balance.json`, `start.res`).

## `balance.json`

| Sección | Claves y unidades |
|---|---|
| `days` | Duración de la partida en días. |
| `start` | `hour` (hora del día inicial), `res` (unidades), `pop` (personas por clase), `hope` y `disc` (puntos), `buildings` (lista de `{type, x, y}` ya construidos). |
| `map` | `size` y `radius` en casillas. `sites` (yacimientos de 3×3) y `piles` (pilas de 2×2): `kind`, `n` (cantidad), `amt` [mín, máx] unidades, `r` [mín, máx] distancia al generador en casillas; `look` es el aspecto visual de la pila. |
| `gen` | `max_level_base` (potencia máxima sin investigar). `radius` (casillas por nivel de radio). `heat` (°C por nivel de potencia 0–4). `over_heat` (°C extra en sobrecarga). `warm_hours` (horas de calentamiento al reencender). `coal_m` (carbón por hora por nivel). `radius_coal_pct` (consumo según el nivel de radio). `over_coal_pct` (consumo en sobrecarga). `stress_up_m` y `stress_down_m` (puntos de estrés por hora; 100 = explosión). `ignite_coal_m` (carbón para reencender). |
| `heat` | `thresholds` (°C mínimos de Muy frío, Frío, Fresco y Confortable; por debajo del primero es Congelante). `station_heat` y `heater_heat` (°C). `heater_coal_m` (carbón por vivienda y por hora con los calefactores encendidos). `warm_rate` y `cool_rate` (°C por hora que sube o baja un edificio; el aislamiento resta `insul/10` al enfriamiento, mínimo 2). `homeless_mod` (°C para la gente sin techo). |
| `prod` | `outdoor_curve`: pares [°C, milésimas] con interpolación lineal, para edificios al aire libre. `level_mult`: milésimas por nivel de calor del edificio (0–4), para los de interior. |
| `build` | `min_speed_m` (velocidad mínima de obra con mucho frío). `refund_pct` (reintegro al demoler y descuento al mejorar; los núcleos no se reintegran). |
| `staff` | `travel_base` (horas de viaje al puesto). `travel_far_tiles` (a partir de esta distancia se suma 1 hora). `child_eff_m` (rendimiento de un niño). |
| `auto` | `eq_m` (trabajadores equivalentes de un autómata). `coal_m` (carbón por hora por autómata). `maint_metal_m` (metal por autómata y por día, a la hora 0). `cost` (unidades por autómata). `max_per_building`. |
| `storage` | `base`: capacidad inicial por recurso (unidades). |
| `food` | `meal_hours` (horas de las dos comidas). `portion_m` (raciones por persona y comida). `raw_sick_pcm` (probabilidad de enfermar por porción comida cruda). `hunger_hope_m` y `hunger_disc_m` (golpe por comida con toda la población con hambre, proporcional). `starve_after` (comidas seguidas con hambre antes de morir). `starve_pcm` (por persona con hambre y comida). `cook_ratio_m` (raciones por unidad de comida cruda). `greenhouse_level_m` (rendimiento por nivel de calor). `hunt_min_temp` (°C). `hunt_trip_m` (comida cruda por cazador y salida). `hunt_ext_pct` (rinde con turno prolongado). `zones`: `max` (unidades) y `regen` (unidades por día). |
| `health` | `sick_pcm` (por nivel de calor, por persona y hora). `grave_frac_pct` (% de los nuevos enfermos que entran graves, por nivel). `shelter_sick_pct` (exposición de los niños en refugio). Curación y muerte por tipo de atención en pcm por hora: `untreated_*`, `basic_*`, `adv_*`, `care_*`. `frost_death_pcm` y `frost_death_vc_pcm` (muerte directa por hora en casa Congelante o Muy fría). |
| `society` | Golpes inmediatos en milésimas de punto: `death_hope_m` y `death_disc_m` (por muerte), `arrival_hope_m` (por cada 10 llegados, hasta 20), `research_hope_m` (por investigación), `wave_survived_hope_m` (al terminar una oleada). |
| `shift` | `cont_death_pcm`: muerte por agotamiento por persona y por día completo en turno de 24 h. |
| `laws` | `cooldown_h`: espera entre leyes. |
| `events` | `roll_pct` (probabilidad de evento diario en cada tirada). `roll_hours` (horas del día en que se tira). `timeout_h` (plazo para decidir). |
| `requests` | `first_h` (hora de juego, contada desde el inicio, del primer pedido posible). `offer_hour` (hora del día en que se ofrece). `offer_hours` (cuánto dura la oferta). `gap_h` + azar hasta `gap_rand_h` (espera entre pedidos). `accept_hope_m` y `decline_disc_m` (golpe al aceptar o rechazar). |
| `explore` | `hours_per_dist` (horas de viaje por unidad de `dist`, en cada sentido). `team_size` (obreros por equipo). `food_m` (raciones por expedición). `survivor_extra_h` (horas extra hasta que llegan los sobrevivientes). |
| `stars` | `surv_pct` y `humane_surv_pct` (% de supervivientes), `pop_end` (personas), `hope_min` y `disc_max` (puntos). |
| `mood` | Esperanza y descontento se acercan cada hora 1/`relax_div` de la distancia a un objetivo. `base_hope` y `base_disc` (puntos). `hope_per_day_div` y `disc_per_day_div` (el objetivo se mueve 1 punto cada N días). `*_pts` (ver la tabla de sufijos). `cold_weights` (% por nivel de calor). `bodies_*_each_m` (por cuerpo sin enterrar, hasta `bodies_cap`). `recent_death_hours` (ventana de muertes recientes) y `recent_death_cap` (puntos). `wave_*`, `gen_off_*`, `good_*`, `shift_*`, `social_cap`, `target_min` y `target_max` en puntos; `gen_off_temp` en °C. |

## `climate.json`

`base_start` y `base_end` son la temperatura media del primer y del último día (°C).
Entre esos días baja de forma lineal, con un ruido de ±`noise` °C por día y semilla.
`diurnal` tiene 24 valores en °C que se suman a la media según la hora. Cada oleada
tiene `id`, `name`, `start` (día de inicio), `announce` (días de aviso previo) y
`profile` (temperatura media de cada día de la oleada, ±2 °C por semilla).

## `buildings.json`

| Campo | Significado |
|---|---|
| `id`, `name`, `desc` | Identificador, nombre y descripción visibles. |
| `cat` | Pestaña del menú de construcción. |
| `size` | [ancho, alto] en casillas. |
| `cost` | Recursos para construir (unidades). |
| `build_h` | Horas de obra a ritmo normal; con frío la obra va más lenta. |
| `kind` | Comportamiento: `housing`, `gather`, `extract`, `convert`, `cook`, `greenhouse`, `hunt`, `medical`, `burial`, `station`, `research`, `storage`, `scouts`, `factory`, `social`, `shelter`. |
| `staff` | `max` (puestos) y `types` (clases que pueden trabajar). |
| `shifts` | Turnos permitidos: 0 normal (8 a 18 h), 1 prolongado (8 a 22 h), 2 continuo (24 h). Los turnos 1 y 2 además piden leyes. |
| `outdoor` | Trabaja al aire libre: rinde según `prod.outdoor_curve` y no según su nivel de calor. |
| `insul` | Aislamiento en °C (se suma a la temperatura del edificio). |
| `self_heat` | °C que el edificio se da a sí mismo mientras funciona. |
| `housing` | Camas. `upgrade_to`: edificio al que se mejora. |
| `radius` | Casillas: alcance de recolección (`gather`) o de calor (`station`). |
| `rates_m` | (`gather`) unidades por trabajador y hora de cada recurso. |
| `site`, `res`, `rate_m` | (`extract`) tipo de yacimiento, recurso y unidades por trabajador y hora. |
| `in`, `out`, `in_m`, `out_m` | (`convert`) recurso que consume y que produce, por trabajador y hora. `in_m` también se usa en `cook`. |
| `rate_m`, `min_lvl`, `coal_m` | (`greenhouse`) comida cruda por trabajador y hora, nivel de calor mínimo y carbón por hora. `coal_m` también es el consumo de una `station`. |
| `tier`, `beds` | (`medical`) atención `basic`, `adv` o `care`, y camas. |
| `graves` | (`burial`) cuerpos que entran. |
| `children` | (`shelter`) plazas para niños. |
| `rp_m` | (`research`) puntos de investigación por trabajador y hora. |
| `work_m` | (`factory`) trabajador-horas para armar un autómata. |
| `storage` | Capacidad extra por recurso (unidades). |
| `hope_t_m`, `disc_t_m` | Aporte al objetivo de esperanza o descontento con el personal completo. El segundo edificio del mismo tipo rinde 1/2, el tercero 1/4, y así. |
| `child_ok`, `apprentice`, `auto_ok` | Admite niños con trabajo infantil, niños aprendices o autómatas. |
| `limit` | Máximo de edificios de ese tipo. |
| `req_research`, `req_law` | Investigación o ley que lo habilita. |
| `hidden` | Opcional: no aparece en el menú ni se puede construir. |

## `research.json`

`id`, `name`, `desc`, `branch` (`calor`, `recursos`, `comida_salud`,
`exploracion`), `tier` (1 a 4), `rp` (puntos de investigación necesarios, enteros),
`cost` (recursos que se pagan una sola vez al empezar), `req` (investigaciones
previas) y `effects` (efectos `mod`, `reveal`, etc.).

## `laws.json`

`id`, `name`, `desc`, `cat` (`adaptacion` o `proposito`), `group` (subgrupo en el
libro de leyes), `req` (leyes previas), `excl` (leyes excluyentes), `path` (`orden`
o `fe`: la primera ley de una senda cierra la otra), `extreme` (ley extrema) y
`effects`. Los efectos `mod` duran mientras la ley esté vigente (es decir, siempre).
Los demás efectos se aplican una vez, al promulgarla. Campos opcionales: `min_day`,
`conds` y `req_research`. Al promulgar una ley se disparan los eventos con
`trigger: "law:<id>"`.

## `events.json`

| Campo | Significado |
|---|---|
| `id`, `title`, `text` | Identificador, título y texto del diálogo. |
| `trigger` | Cuándo aparece (ver abajo). |
| `unique` | `true`: no se repite. `false`: se repite después de `cooldown_days` (5 si falta). |
| `day_min`, `day_max` | Días en que puede aparecer. |
| `weight` | Peso en el sorteo diario. |
| `conds` | Condiciones que se tienen que cumplir para que aparezca. |
| `choices` | Opciones: `text`, `effects`, `req` (condiciones para poder elegirla) y, opcional, `cost` (recursos que se pagan al elegirla). |
| `default` | Índice de la opción que se aplica si vence el plazo. Si no se puede elegir, se aplica la primera que sí. |
| `timeout_h` | Opcional: plazo propio en horas. |

Un evento con una sola opción es informativo: se aplica en el acto, sin diálogo.

Valores de `trigger`:

- `daily`: entra en el sorteo diario (`balance.json`, `events`), solo si no hay otro
  evento pendiente.
- `location`: lo dispara una ubicación al llegar la expedición (campo `event`).
- `law:<id de ley>`: al promulgar esa ley.
- `wave:<id de oleada>`: el primer día de esa oleada.
- `followup`: solo lo programa el efecto `followup` de otro evento. Sale pasadas
  `hours` horas si en ese momento se cumplen sus `conds` (no mira `day_min`, `day_max`
  ni `unique`).

### Cadenas y marcas (flags)

Las consecuencias encadenadas se arman con dos herramientas:

1. `{"k": "followup", "id": "<evento>", "hours": N}` programa un evento con
   `trigger: "followup"` para dentro de N horas.
2. `{"k": "flag", "v": "<nombre>"}` deja una marca permanente. Otro evento puede
   pedirla con `{"k": "flag", "v": "<nombre>"}` (o su ausencia con `noflag`) en sus
   `conds`, y `{"k": "unflag", "v": "<nombre>"}` la borra.

Si existe el texto `epi_flag_<nombre>` en `texts.json`, la marca agrega esa frase al
epílogo. `extremo` y `trabajo_infantil` además restan la estrella de gobierno humano.

Marcas en uso:

| Marca | La pone | La lee |
|---|---|---|
| `ladron_perdonado` | `ev_ladron_carbon` (perdonar) | `ev_ladron_deuda`, epílogo |
| `rebelde_perdonado` | `ev_rebeldes` (convencerlos, si sale bien) | `ev_rebeldes_palabra` (puede borrarla), epílogo |
| `partieron` | `ev_rebeldes` (dejarlos ir) | `ev_partieron_noticias`, epílogo |
| `sur_helado` | `ev_partieron_noticias` | epílogo |
| `nino_salvado` | `ev_nino_hielo` (rescate exitoso) | `ev_nina_rescatada`, epílogo |
| `nina_perdida` | `ev_nino_hielo` (no rescatarla o fallar) | `ev_nina_madre`, epílogo |
| `traidores` | `ev_fuga` (dejarlos ir) | `ev_traidores_vuelven` (puede borrarla), epílogo |
| `traidores_perdonados` | `ev_traidores_vuelven` | epílogo |
| `predicador_libre` | `ev_profeta_falso` (dejarlo hablar) | `ev_predicador_seguidores` (puede borrarla), epílogo |
| `mercader_amigo` | `ev_comerciante` | `ev_mercader_vuelve`, epílogo |
| `trabajo_infantil` | ley `ley_manos` | `ev_nino_derrumbe`, estrellas |
| `abono` | ley `ley_abono` | `ev_abono_cosecha`, epílogo |
| `mano_hierro` | ley `ord_mano_hierro` | `ev_denuncias` |
| `nuevo_orden` | ley `ord_nuevo_orden` | `ev_sillas_vacias` |
| `profeta` | ley `fe_profeta` | `ev_ayuno_fuego` |
| `comunion` | ley `fe_comunion` | `ev_muro_comunion` |
| `extremo` | las cuatro leyes extremas | estrellas |

## Efectos

Los usan las opciones de eventos, las leyes, las investigaciones y los premios y
castigos de los pedidos. Todos llevan `k` (tipo) y casi todos `v` (valor).

| `k` | Campos | Efecto |
|---|---|---|
| `hope`, `disc` | `v` puntos | Golpe inmediato a la esperanza o al descontento. |
| `res` | `r`, `v` unidades | Suma hasta el límite del almacén o resta lo que haya. |
| `mod` | `key`, `v` | Modificador mientras dure la ley o investigación (ver abajo). |
| `perm_mod` | `key`, `v` | Modificador permanente que deja un evento. |
| `flag`, `unflag` | `v` nombre | Pone o borra una marca. |
| `followup` | `id`, `hours` (24 si falta) | Programa un evento encadenado. |
| `refugees` | `o`, `i`, `n`, `sick`, `hours` (12 si falta) | Llegan obreros, ingenieros y niños; `sick` de los obreros llegan enfermos. |
| `sick` | `v` personas, `grave` (0 o 1) | Enferma gente sana (leves o graves). |
| `cure` | `v` personas | Cura enfermos leves. |
| `kill` | `v` personas, `cause` | Muertes de gente sana. El aviso usa el texto `muertes_<cause>` (`muertes_otro` si no existe). |
| `leave` | `v` personas | Obreros sanos que se van de la ciudad. |
| `stress` | `v` puntos | Estrés del generador (queda entre 0 y 99). |
| `hunt_zone` | `v` unidades | Repone presas, repartidas entre las zonas de caza. |
| `reveal` | `v` id de ubicación | Descubre una ubicación. |
| `autos` | `v` | Agrega autómatas libres. |
| `law_cd` | `v` horas | Alarga la espera hasta la próxima ley. |
| `rand` | `pct` (50 si falta), `then`, `else` | Azar: aplica una de las dos listas. |
| `note` | `v` texto | Agrega un aviso al registro. |

Claves de modificador (`mod` y `perm_mod`):

| Clave | Unidad | Efecto |
|---|---|---|
| `gen_max_level`, `gen_radius_lvl` | niveles | Potencia máxima y radio de calor del generador. |
| `gen_coal_pct` | % | Consumo del generador. |
| `station_heat`, `heat_housing`, `heat_work` | °C | Calor de las estaciones, de las viviendas y de los lugares de trabajo de interior. |
| `heaters` | 1 | Habilita los calefactores domésticos. |
| `prod_all_pct` | % | Recolección a mano, extracción, conversión y caza. |
| `prod_carbon_pct`, `prod_madera_pct`, `prod_metal_pct` | % | Edificios de extracción y conversión de ese recurso (no la recolección a mano). |
| `cook_pct`, `cook_ratio_m` | %, milésimas | Velocidad de las cocinas y raciones extra por unidad de comida cruda. |
| `greenhouse_pct`, `hunt_pct` | % | Invernaderos y caza. |
| `portion_m` | milésimas | Ración por persona y comida (negativo = porciones más chicas). |
| `sick_pct`, `cure_pct`, `death_pct`, `beds_pct` | % | Probabilidad de enfermar, curación, muertes de graves y camas. |
| `home_heal_pcm` | pcm por hora | Curación en casa de los leves sin atender. |
| `death_hope_pct` | % | Golpe de esperanza por cada muerte. |
| `hope_t_m`, `disc_t_m` | milésimas de punto | Suma fija al objetivo de esperanza o descontento. |
| `shift_max` | niveles | Turnos largos permitidos: cada +1 habilita el siguiente (primero el prolongado, después el continuo). |
| `child_labor`, `child_all`, `child_apprentice` | 1 | Trabajo infantil, en todos lados o como aprendices. |
| `child_eff_m` | milésimas | Rendimiento extra de los niños. |
| `research_pct`, `travel_pct` | % | Velocidad de investigación y duración de los viajes. |
| `auto_eq_pct`, `auto_coal_pct` | % | Trabajo y consumo de carbón de los autómatas. |

## Condiciones

Las usan `conds` (eventos, pedidos, leyes) y `req` (opciones de eventos).

| `k` | Campos | Se cumple si... |
|---|---|---|
| `pop_min`, `pop_max` | `v` | La población total es al menos o como mucho `v`. |
| `res_min`, `res_max` | `r`, `v` | Hay al menos o como mucho `v` unidades del recurso. |
| `flag`, `noflag` | `v` | La marca está o no está. |
| `law`, `nolaw` | `v` | La ley está o no está promulgada. |
| `path` | `v` | La senda elegida es `orden` o `fe`. |
| `research`, `noresearch` | `v` | La investigación está o no está terminada. |
| `day_min`, `day_max` | `v` | Día actual. |
| `sick_min`, `sick_max` | `v` | Enfermos (leves más graves). |
| `hope_min`, `hope_max`, `disc_min`, `disc_max` | `v` puntos | Esperanza o descontento actuales. |
| `wave` | `v` (1 o 0) | Hay o no hay una oleada en curso. |
| `homeless_min` | `v` | Al menos `v` personas sin techo. |
| `no_homeless` | | Nadie sin techo. |
| `bodies_min`, `no_bodies` | `v` | Cuerpos sin enterrar. |
| `building` | `type`, `min` (1 si falta) | Hay al menos `min` edificios terminados de ese tipo. |
| `nobuilding` | `type` | No hay ninguno, ni siquiera en obra. |
| `hungry` | | Alguien se quedó sin comer en la última comida. |
| `gen_over` | | El generador está en sobrecarga. |
| `gen_level_min` | `v` | El generador está encendido con potencia `v` o más. |
| `deaths_min` | `v` | Muertes totales de la partida. |
| `children_min`, `engineers_min` | `v` | Niños o ingenieros sanos. |
| `autos_min` | `v` | Autómatas construidos. |
| `heat_homes_min` | `v` nivel | Nadie sin techo y nadie vive en una vivienda por debajo del nivel de calor `v`. |
| `stress_max` | `v` puntos | Estrés del generador. |
| `rand` | `v` % | Azar. |
| `explored_min` | `v` | Ubicaciones exploradas. |

## `requests.json`

`id`, `name`, `text` (lo que ve el jugador: tiene que describir exactamente el
objetivo), `goal`, `hours` (plazo desde que se acepta), `reward`, `penalty`,
`day_min`, `day_max`, `conds` (cuándo se puede ofrecer) y `repeat` (opcional: se
puede volver a ofrecer). Un pedido no se ofrece si su objetivo ya se cumple.

Objetivos (`goal`):

- `count_delta`: `types` (lista de edificios) y `v`: terminar `v` edificios nuevos de
  esos tipos desde que se aceptó.
- `count_min`: `types` y `v`: tener al menos `v` terminados.
- `research_delta`: completar `v` investigaciones desde que se aceptó.
- `explore_delta`: explorar `v` ubicaciones desde que se aceptó.
- Cualquier condición de la tabla anterior (por ejemplo `sick_max`, `no_homeless`,
  `res_min`), evaluada en cada hora del plazo.

## `locations.json`

`id`, `name`, `desc`, `dist` (el viaje dura `dist × explore.hours_per_dist` horas
en cada sentido, ajustado por `travel_pct`, mínimo 2), `tier` (dato informativo), `loot` (unidades por recurso;
varía ±25 % por semilla salvo los núcleos, que son exactos), `survivors`
(`obreros`, `ingenieros`, `ninos` y `sick`; varía entre 70 y 130 % por semilla),
`reveals` (ubicaciones que descubre al explorarla), `event` (evento con
`trigger: "location"`), `start_known` (conocida desde el inicio), `req_research` y
`pos` ([x, y] en el mapa del páramo). Cada ubicación se explora una sola vez.

## `texts.json`

Mensajes con `%d` (número) o `%s` (nombre). Cuando el número puede ser 1 se usa
la forma `persona(s)`. Familias de claves que arma el código:

- `fin_<motivo>` y `epi_<motivo>`: `victoria`, `explosion`, `esperanza`,
  `expulsion`, `extincion` y `frio_final`.
- `epi_path_<senda>`, `epi_law_<id de ley>` y `epi_flag_<marca>`: frases del epílogo.
- `epi_refugios`, `epi_sin_muertes`, `epi_muchas_muertes` y `epi_automatas`.
- `muertes_<causa>`: aviso de muertes por causa (`enfermedad`, `hambre`,
  `agotamiento`, `accidente`, `purga`, `frio`, `lobos`, `combate`; si falta, se usa
  `muertes_otro`).

## Cómo validar

`tools/run_tests.sh` corre los tests headless. `test_datos_integridad`
(`tests/test_sim.gd`) revisa las referencias entre ids, los efectos conocidos, los
destinos de `followup` y `reveal`, la cantidad de eventos y ubicaciones, las 8 a 10
leyes por senda y las 4 ramas × 4 niveles. Si se cambian números que afectan la
simulación, hay que volver a correr el banco de balance (`tools/balance.sh`).
