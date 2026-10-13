class_name SimClock
extends RefCounted
## Reloj que convierte tiempo real en pasos enteros de simulación.
## La simulación solo avanza de a una hora completa; la pausa y las velocidades
## x1/x2/x3 cambian cuántas horas se ejecutan por segundo real, nunca el resultado.

const REAL_SECONDS_PER_HOUR_MS := 11250 # 4,5 min por día a x1

var sim: Simulation
var speed := 1 # 0 = pausa, 1, 2, 3
var acc_ms := 0 # milisegundos reales acumulados (entero)
var pre_step: Callable # se llama antes de cada paso (p.ej. aplicar órdenes en cola)
var max_steps_per_frame := 4
var stop_at := -1 # tick en el que se detiene (para pruebas/benchmarks); -1 = nunca

## Avanza según el tiempo real transcurrido. Devuelve cuántos pasos ejecutó.
func advance_ms(delta_ms: int) -> int:
	if speed <= 0 or sim == null:
		return 0
	acc_ms += delta_ms * speed
	var n := 0
	while acc_ms >= REAL_SECONDS_PER_HOUR_MS and n < max_steps_per_frame:
		if stop_at >= 0 and sim.tick() >= stop_at:
			acc_ms = 0
			break
		acc_ms -= REAL_SECONDS_PER_HOUR_MS
		advance_one()
		n += 1
	if n >= max_steps_per_frame:
		acc_ms = mini(acc_ms, REAL_SECONDS_PER_HOUR_MS)
	return n

func advance_one() -> void:
	if pre_step.is_valid():
		pre_step.call()
	sim.step()

## Fracción (0..1000) de la hora actual ya transcurrida, para interpolar visuales.
func hour_fraction() -> int:
	return clampi(acc_ms * 1000 / REAL_SECONDS_PER_HOUR_MS, 0, 1000)
