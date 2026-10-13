# BALANCE — Última Brasa

Banco de balance headless (`tools/balance.sh`). Generado el 2026-10-13 con **100 semillas por bot** (semillas 1000–1099).
Cada partida dura 60 días (1440 pasos de 1 hora). Mismo código de simulación que el juego.

## 1. Dificultad (criterio: competente 65–85 %, pasivo pierde ≥ 95 %, aleatorio pierde ≥ 90 %)

| Bot | Partidas | Victorias | Derrotas | Criterio | Cumple |
|---|---:|---:|---:|---|:---:|
| Competente | 100 | 73.0 % | 27.0 % | gana 65–85 % | ✅ |
| Pasivo | 100 | 0.0 % | 100.0 % | pierde ≥ 95 % | ✅ |
| Aleatorio | 100 | 0.0 % | 100.0 % | pierde ≥ 90 % | ✅ |

Causas de derrota del bot competente: esperanza en 0 16, descontento 100 (expulsión) 11.
Día de la derrota (tramos de 10 días): 1–10: 2, 11–20: 3, 21–30: 3, 31–40: 5, 41–50: 14.

Partidas ganadas: 2.53 estrellas en promedio, 11.9 muertes, población final 206.

## 2. Sobrantes al final (partidas ganadas por el bot competente)

Sobrante = stock final / total obtenido en la partida (stock inicial + todo lo que entró a los depósitos). Criterio: p90 ≤ 30 % y mediana entre 10 % y 25 %.

| Material | Mediana | Percentil 90 | Cumple |
|---|---:|---:|:---:|
| Carbón | 13.0 % | 17.0 % | ✅ |
| Madera | 19.0 % | 23.8 % | ✅ |
| Metal | 11.0 % | 18.0 % | ✅ |
| Núcleos | 16.0 % | 18.0 % | ✅ |
| Comida | 15.0 % | 22.0 % | ✅ |

## 3. Antiexploits (un bot tramposo por exploit)

Cada tramposo juega igual que el competente y además intenta el exploit. Criterio: no mejora la tasa de victoria ni los recursos obtenidos en más de 5 % respecto del competente (mismas semillas). Para los exploits de determinismo se compara además el hash SHA-256 del estado final.

| Exploit | Victorias | Δ vs competente | Recursos obtenidos Δ | Estado final idéntico | Cumple |
|---|---:|---:|---:|---:|:---:|
| 1. Demoler y reconstruir (reintegro ≤ 50%) | 1.0 % | -72.0 pp | -81.4 % (máx.) | 0 % | ✅ |
| 2. Reasignar al final del turno (producción por hora, el viaje cuenta) | 73.0 % | +0.0 pp | +0.0 % (máx.) | 100 % | ✅ |
| 3. Prender/apagar sobrecarga para resetear el estrés | 0.0 % | -73.0 pp | -86.9 % (máx.) | 0 % | ✅ |
| 4. Recargar la partida (el azar va en el guardado) | 73.0 % | +0.0 pp | +0.0 % (máx.) | 100 % | ✅ |
| 5. Pausar/acelerar (simulación determinista) | 73.0 % | +0.0 pp | +0.0 % (máx.) | 100 % | ✅ |
| 6. Spam de edificios de esperanza y leyes | 0.0 % | -73.0 pp | -52.7 % (máx.) | 1 % | ✅ |
| 7. Acumular sin límite (almacenes con capacidad) | 0.0 % | -73.0 pp | -58.2 % (máx.) | 3 % | ✅ |
| 8. Explotar pilas/bosques/caza/ubicaciones infinitas | 15.0 % | -58.0 pp | -51.7 % (máx.) | 0 % | ✅ |
| 9. Apagar el generador de noche | 0.0 % | -73.0 pp | -56.6 % (máx.) | 0 % | ✅ |
| 10. Mover enfermos para curarlos más rápido | 0.0 % | -73.0 pp | -76.9 % (máx.) | 0 % | ✅ |
| 11. Repetir eventos o expediciones | 73.0 % | +0.0 pp | +3.1 % (máx.) | 0 % | ✅ |
| 12. Autómatas sin costo | 54.0 % | -19.0 pp | +36.0 % (máx.) | 27 % | ❌ |
| 13. Desbordes, negativos, clics rápidos | 65.0 % | -8.0 pp | -7.1 % (máx.) | 0 % | ✅ |
| 14. Diferencias PC/celular (mismo seed y cuadros de 33 ms) | 73.0 % | +0.0 pp | +0.0 % (máx.) | 100 % | ✅ |

Notas: «Recursos obtenidos Δ» es la mayor diferencia porcentual entre carbón, madera, metal y comida cruda obtenidos en promedio. El bot de recargas guarda al empezar cada día y, si hubo muertes, recarga y vuelve a jugarlo: el resultado es idéntico porque el estado del azar está dentro del guardado. El de plataforma avanza con cuadros de 33 ms a x3 (como un celular) y el de velocidad alterna pausas y velocidades al azar: ambos terminan con el mismo hash que el competente.

## 4. Ninguna oleada se puede ignorar

Variante del competente que *ignora* una oleada: no junta carbón ni comida extra para ella y durante la oleada deja el generador en potencia 1, sin sobrecarga ni calefactores.

| Oleada ignorada | Victorias | Δ vs competente | Muertes (ganadas) | Cumple |
|---|---:|---:|---:|:---:|
| Oleada 1 | 65.0 % | -8.0 pp | 11.6 (competente 11.9) | ✅ |
| Oleada 2 | 55.0 % | -18.0 pp | 12.6 (competente 11.9) | ✅ |
| Oleada 3 | 58.0 % | -15.0 pp | 12.4 (competente 11.9) | ✅ |
| Oleada 4 | 59.0 % | -14.0 pp | 19.1 (competente 11.9) | ✅ |
| Oleada 5 | 0.0 % | -73.0 pp | nan (competente 11.9) | ✅ |

## 5. Sobrevivir sin desarrollarse no alcanza

| Variante | Victorias | Cumple |
|---|---:|:---:|
| Deja de construir, investigar y legislar desde el día 15 | 0.0 % | ✅ |

## 6. Recolección a mano = 50 % del edificio básico

| Recurso | Puesto (por trabajador-hora) | Edificio básico | Proporción | Cumple |
|---|---:|---:|---:|:---:|
| Carbón | 1 | 2 (Extractor de carbón) | 50 % | ✅ |
| Madera | 0.5 | 1 (Aserradero del bosque helado) | 50 % | ✅ |
| Metal | 0.3 | 0.6 (Mina de hierro) | 50 % | ✅ |

Los puestos y los tres edificios básicos son de exterior y usan la misma curva de frío; las mejoras de investigación solo afectan a los edificios. El test `test_recoleccion_mitad_que_edificio` lo verifica en marcha.

## Cómo reproducir

```
tools/setup_env.sh
tools/balance.sh 500 "competente pasivo aleatorio t01_demoler ... ola_1 ... estancado" 4 1000
python3 tools/balance_report.py --md
```
