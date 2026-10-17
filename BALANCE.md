# BALANCE — Última Brasa

Banco de balance headless (`tools/balance.sh`). Generado el 2026-10-17 con **500 semillas por bot** (semillas 1000–1499).
Cada partida dura 60 días (1440 pasos de 1 hora). Mismo código de simulación que el juego.

## 1. Dificultad (criterio: competente 65–85 %, pasivo pierde ≥ 95 %, aleatorio pierde ≥ 90 %)

| Bot | Partidas | Victorias | Derrotas | Criterio | Cumple |
|---|---:|---:|---:|---|:---:|
| Competente | 500 | 73.4 % | 26.6 % | gana 65–85 % | ✅ |
| Pasivo | 500 | 0.0 % | 100.0 % | pierde ≥ 95 % | ✅ |
| Aleatorio | 500 | 0.0 % | 100.0 % | pierde ≥ 90 % | ✅ |

Causas de derrota del bot competente: esperanza en 0 100, descontento 100 (expulsión) 33.
Día de la derrota (tramos de 10 días): 1–10: 15, 11–20: 29, 21–30: 6, 31–40: 20, 41–50: 59, 51–60: 4.

Partidas ganadas: 2.81 estrellas en promedio, 10.4 muertes, población final 209.

## 2. Sobrantes al final (partidas ganadas por el bot competente)

Sobrante = stock final / total obtenido en la partida (stock inicial + todo lo que entró a los depósitos). Criterio: p90 ≤ 30 % y mediana entre 10 % y 25 %.

| Material | Mediana | Percentil 90 | Cumple |
|---|---:|---:|:---:|
| Carbón | 14.0 % | 17.0 % | ✅ |
| Madera | 20.0 % | 23.0 % | ✅ |
| Metal | 14.0 % | 19.0 % | ✅ |
| Núcleos | 16.0 % | 20.0 % | ✅ |
| Comida | 15.0 % | 21.0 % | ✅ |

## 3. Antiexploits (un bot tramposo por exploit)

Cada tramposo juega igual que el competente y además intenta el exploit. Criterio: no mejora la tasa de victoria ni los recursos obtenidos en más de 5 % respecto del competente (mismas semillas). Para pausar/acelerar y PC/celular se compara además el hash SHA-256 del estado final; para recargar, cuántas recargas cambiaron el desenlace del azar.

| Exploit | Victorias | Δ vs competente | Recursos obtenidos Δ | Estado final idéntico | Cumple |
|---|---:|---:|---:|---:|:---:|
| 1. Demoler y reconstruir (reintegro ≤ 50%) | 1.0 % | -72.4 pp | -81.6 % (máx., madera) | 0 % | ✅ |
| 2. Reasignar al final del turno (producción por hora, el viaje cuenta) | 59.0 % | -14.4 pp | -12.6 % (máx., carbón) | 0 % | ✅ |
| 3. Prender/apagar sobrecarga para resetear el estrés | 0.0 % | -73.4 pp | -86.9 % (máx., raciones) | 0 % | ✅ |
| 4. Recargar la partida (el azar va en el guardado) | 72.6 % | -0.8 pp | -0.2 % (máx., comida cruda) | 2 de 14219 recargas cambian el azar | ❌ |
| 5. Pausar/acelerar (simulación determinista) | 73.4 % | +0.0 pp | +0.0 % (máx., carbón) | 100 % | ✅ |
| 6. Spam de edificios de esperanza y leyes | 0.0 % | -73.4 pp | -55.7 % (máx., comida cruda) | 1 % | ✅ |
| 7. Acumular sin límite (almacenes con capacidad) | 72.4 % | -1.0 pp | +0.2 % (máx., raciones) | 7 % | ✅ |
| 8. Explotar pilas/bosques/caza/ubicaciones infinitas | 0.0 % | -73.4 pp | -86.4 % (máx., carbón) | 0 % | ✅ |
| 9. Apagar el generador de noche | 0.0 % | -73.4 pp | -55.5 % (máx., carbón) | 0 % | ✅ |
| 10. Mover enfermos para curarlos más rápido | 0.0 % | -73.4 pp | -81.9 % (máx., carbón) | 2 % | ✅ |
| 11. Repetir eventos o expediciones | 73.4 % | +0.0 pp | +0.0 % (máx., carbón) | 100 % | ✅ |
| 12. Autómatas sin costo | 73.4 % | +0.0 pp | +0.0 % (máx., carbón) | 100 % | ✅ |
| 13. Desbordes, negativos, clics rápidos | 58.0 % | -15.4 pp | -14.2 % (máx., carbón) | 0 % | ✅ |
| 14. Diferencias PC/celular (mismo seed y cuadros de 33 ms) | 73.4 % | +0.0 pp | +0.0 % (máx., carbón) | 100 % | ✅ |

Notas: «Recursos obtenidos Δ» es la mayor diferencia porcentual entre carbón, madera, metal, núcleos, comida cruda y raciones obtenidos en promedio. El de reasignar, terminado el turno de día, manda a la gente de producción a los lugares libres de los edificios con turno largo y a cubrir de noche los médicos y sociales (24 h), y a las 7 la devuelve; el viaje cuenta en todos los edificios. El de recargas, ante cada evento con azar, guarda, lo resuelve, recarga y prueba resolverlo una hora más tarde, después de contestar el pedido pendiente o eligiendo otra opción, y se queda con el mejor: la columna cuenta las recargas en las que esperar o cambiar el orden dio otro desenlace (el azar de cada evento se fija al aparecer y va en el guardado), y elegir otra opción sabiendo el desenlace entra en el criterio del 5 %. El de velocidad avanza con el reloj del juego (hasta 3 pasos por cuadro) alternando al azar cuadros en pausa —en los que da sus órdenes— con x1, x2 y x3 y cuadros de 16 a 250 ms; el de plataforma avanza como un celular (cuadros de 33 ms a x3, pausas por segundo plano y cuadros largos al volver): ambos terminan con el mismo hash que el competente. El de acumular se desarrolla como el competente, amplía almacenes en cuanto un recurso pasa del 60 % y no gasta excedentes hasta la tormenta final.

## 4. Ninguna oleada se puede ignorar

Variante del competente que *ignora* una oleada: no junta carbón ni comida extra para ella y durante la oleada deja el generador en potencia 1, sin sobrecarga ni calefactores.

| Oleada ignorada | Victorias | Δ vs competente | Muertes (ganadas) | Cumple |
|---|---:|---:|---:|:---:|
| Oleada 1 | 75.4 % | +2.0 pp | 12.0 (competente 10.4) | ❌ |
| Oleada 2 | 63.8 % | -9.6 pp | 12.3 (competente 10.4) | ✅ |
| Oleada 3 | 63.6 % | -9.8 pp | 11.8 (competente 10.4) | ✅ |
| Oleada 4 | 59.4 % | -14.0 pp | 17.1 (competente 10.4) | ✅ |
| Oleada 5 | 0.0 % | -73.4 pp | — (no gana ninguna) (competente 10.4) | ✅ |

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
