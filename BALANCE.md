# BALANCE — Última Brasa

Banco de balance headless (`tools/balance.sh`). Generado el 2026-10-17 con **500 semillas por bot** (semillas 1000–1499).
Cada partida dura 60 días (1440 pasos de 1 hora). Mismo código de simulación que el juego.

## 1. Dificultad (criterio: competente 65–85 %, pasivo pierde ≥ 95 %, aleatorio pierde ≥ 90 %)

| Bot | Partidas | Victorias | Derrotas | Criterio | Cumple |
|---|---:|---:|---:|---|:---:|
| Competente | 500 | 71.2 % | 28.8 % | gana 65–85 % | ✅ |
| Pasivo | 500 | 0.0 % | 100.0 % | pierde ≥ 95 % | ✅ |
| Aleatorio | 500 | 0.0 % | 100.0 % | pierde ≥ 90 % | ✅ |

Causas de derrota del bot competente: esperanza en 0 90, descontento 100 (expulsión) 54.
Día de la derrota (tramos de 10 días): 1–10: 19, 11–20: 21, 21–30: 7, 31–40: 23, 41–50: 73, 51–60: 1.

Partidas ganadas: 2.65 estrellas en promedio, 11.0 muertes, población final 209.

## 2. Sobrantes al final (partidas ganadas por el bot competente)

Sobrante = stock final / total obtenido en la partida (stock inicial + todo lo que entró a los depósitos). Criterio: p90 ≤ 30 % y mediana entre 10 % y 25 %.

| Material | Mediana | Percentil 90 | Cumple |
|---|---:|---:|:---:|
| Carbón | 14.0 % | 17.0 % | ✅ |
| Madera | 20.0 % | 23.5 % | ✅ |
| Metal | 13.0 % | 19.0 % | ✅ |
| Núcleos | 16.0 % | 20.0 % | ✅ |
| Comida | 15.0 % | 19.0 % | ✅ |

## 3. Antiexploits (un bot tramposo por exploit)

Cada tramposo juega igual que el competente y además intenta el exploit. Criterio: no mejora la tasa de victoria ni los recursos obtenidos en más de 5 % respecto del competente (mismas semillas). Para pausar/acelerar y PC/celular se compara además el hash SHA-256 del estado final; para recargar, cuántas recargas cambiaron el desenlace del azar.

| Exploit | Victorias | Δ vs competente | Recursos obtenidos Δ | Estado final idéntico | Cumple |
|---|---:|---:|---:|---:|:---:|
| 1. Demoler y reconstruir (reintegro ≤ 50%) | 1.0 % | -70.2 pp | -81.5 % (máx., madera) | 0 % | ✅ |
| 2. Reasignar al final del turno (producción por hora, el viaje cuenta) | 58.8 % | -12.4 pp | -11.4 % (máx., carbón) | 0 % | ✅ |
| 3. Prender/apagar sobrecarga para resetear el estrés | 0.0 % | -71.2 pp | -86.6 % (máx., raciones) | 0 % | ✅ |
| 4. Recargar la partida (el azar va en el guardado) | 68.2 % | -3.0 pp | -1.6 % (máx., comida cruda) | 0 de 14172 recargas cambian el azar | ✅ |
| 5. Pausar/acelerar (simulación determinista) | 71.2 % | +0.0 pp | +0.0 % (máx., carbón) | 100 % | ✅ |
| 6. Spam de edificios de esperanza y leyes | 0.2 % | -71.0 pp | -55.9 % (máx., comida cruda) | 1 % | ✅ |
| 7. Acumular sin límite (almacenes con capacidad) | 71.0 % | -0.2 pp | +1.8 % (máx., raciones) | 8 % | ✅ |
| 8. Explotar pilas/bosques/caza/ubicaciones infinitas | 0.0 % | -71.2 pp | -86.4 % (máx., carbón) | 0 % | ✅ |
| 9. Apagar el generador de noche | 0.0 % | -71.2 pp | -56.9 % (máx., carbón) | 0 % | ✅ |
| 10. Mover enfermos para curarlos más rápido | 0.0 % | -71.2 pp | -82.9 % (máx., carbón) | 2 % | ✅ |
| 11. Repetir eventos o expediciones | 71.2 % | +0.0 pp | +0.0 % (máx., carbón) | 100 % | ✅ |
| 12. Autómatas sin costo | 71.2 % | +0.0 pp | +0.0 % (máx., carbón) | 100 % | ✅ |
| 13. Desbordes, negativos, clics rápidos | 59.4 % | -11.8 pp | -12.1 % (máx., carbón) | 0 % | ✅ |
| 14. Diferencias PC/celular (mismo seed y cuadros de 33 ms) | 71.2 % | +0.0 pp | +0.0 % (máx., carbón) | 100 % | ✅ |

Notas: «Recursos obtenidos Δ» es la mayor diferencia porcentual entre carbón, madera, metal, núcleos, comida cruda y raciones obtenidos en promedio. El de reasignar, terminado el turno de día, manda a la gente de producción a los lugares libres de los edificios con turno largo y a cubrir de noche los médicos y sociales (24 h), y a las 7 la devuelve; el viaje cuenta en todos los edificios. El de recargas, ante cada evento con azar, guarda, lo resuelve, recarga y prueba resolverlo una hora más tarde, después de contestar el pedido pendiente o eligiendo otra opción, y se queda con el mejor: la columna cuenta las recargas en las que esperar o cambiar el orden dio otro desenlace (el azar de cada evento se fija al aparecer y va en el guardado), y elegir otra opción sabiendo el desenlace entra en el criterio del 5 %. El de velocidad avanza con el reloj del juego (hasta 3 pasos por cuadro) alternando al azar cuadros en pausa —en los que da sus órdenes— con x1, x2 y x3 y cuadros de 16 a 250 ms; el de plataforma avanza como un celular (cuadros de 33 ms a x3, pausas por segundo plano y cuadros largos al volver): ambos terminan con el mismo hash que el competente. El de acumular se desarrolla como el competente, amplía almacenes en cuanto un recurso pasa del 60 % y no gasta excedentes hasta la tormenta final.

## 4. Ninguna oleada se puede ignorar

Variante del competente que *ignora* una oleada: no junta carbón ni comida extra para ella y durante la oleada deja el generador en potencia 1, sin sobrecarga ni calefactores.

| Oleada ignorada | Victorias | Δ vs competente | Muertes (ganadas) | Cumple |
|---|---:|---:|---:|:---:|
| Oleada 1 | 61.6 % | -9.6 pp | 12.1 (competente 11.0) | ✅ |
| Oleada 2 | 60.2 % | -11.0 pp | 12.1 (competente 11.0) | ✅ |
| Oleada 3 | 58.2 % | -13.0 pp | 12.2 (competente 11.0) | ✅ |
| Oleada 4 | 58.6 % | -12.6 pp | 17.4 (competente 11.0) | ✅ |
| Oleada 5 | 0.0 % | -71.2 pp | — (no gana ninguna) (competente 11.0) | ✅ |

## 5. Sobrevivir sin desarrollarse no alcanza

| Variante | Victorias | Cumple |
|---|---:|:---:|
| Deja de construir, investigar y legislar desde el día 15 | 0.0 % | ✅ |

## 6. Recolección a mano = 50 % del edificio básico

| Recurso | Cuadrilla de acopio (por trabajador-hora) | Edificio básico | Proporción | Cumple |
|---|---:|---:|---:|:---:|
| Carbón | 1 | 2 (Extractor de carbón) | 50 % | ✅ |
| Madera | 0.5 | 1 (Aserradero del bosque helado) | 50 % | ✅ |
| Metal | 0.3 | 0.6 (Mina de hierro) | 50 % | ✅ |

Las cuadrillas de acopio y los tres edificios básicos son de exterior y usan la misma curva de frío; las mejoras de investigación solo afectan a los edificios. El test `test_recoleccion_mitad_que_edificio` lo verifica en marcha.

## Cómo reproducir

```
tools/setup_env.sh
tools/balance.sh 500   # los 23 bots, semillas 1000–1499
python3 tools/balance_report.py --md
```

`tools/balance.sh` sin segundo argumento corre los 23 bots: competente pasivo aleatorio t01_demoler t02_reasignar t03_sobrecarga t04_recargar t05_velocidad t06_esperanza t07_acumular t08_pilas t09_generador_noche t10_enfermos t11_repetir t12_automatas t13_desbordes t14_plataforma ola_1 ola_2 ola_3 ola_4 ola_5 estancado.
