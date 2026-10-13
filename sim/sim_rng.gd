class_name SimRng
## Generador xorshift32 explícito con máscara de 32 bits.
## Mismo resultado en cualquier plataforma; su estado se guarda en la partida.

const MASK := 0xFFFFFFFF

static func seed_state(seed: int) -> int:
	# splitmix-like (solo sumas, xor y desplazamientos con máscara: sin desbordes).
	var z := (seed ^ 0x5DEECE66) & MASK
	for i in 4:
		z = (z + 0x9E3779B9) & MASK
		z ^= (z << 7) & MASK
		z ^= z >> 11
		z ^= (z << 3) & MASK
	if z == 0:
		z = 0x1234567
	return z

static func step(s: int) -> int:
	var x := s & MASK
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	return x & MASK
