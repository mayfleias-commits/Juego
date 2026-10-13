class_name FX
## Aritmética de punto fijo (escala 1000) y utilidades enteras deterministas.
## La simulación NUNCA usa float: todo pasa por enteros de 64 bits.

const ONE := 1000

static func mul(a: int, b: int) -> int:
	return (a * b) / ONE

static func div(a: int, b: int) -> int:
	if b == 0:
		return 0
	return (a * ONE) / b

## División entera con redondeo hacia abajo (también para negativos).
static func floordiv(a: int, b: int) -> int:
	var q := a / b
	if (a % b != 0) and ((a < 0) != (b < 0)):
		q -= 1
	return q

static func clampi(v: int, lo: int, hi: int) -> int:
	return lo if v < lo else (hi if v > hi else v)

## Interpolación lineal por tramos sobre una tabla [[x, y], ...] ordenada por x.
static func piecewise(table: Array, x: int) -> int:
	if table.is_empty():
		return ONE
	if x <= int(table[0][0]):
		return int(table[0][1])
	for i in range(1, table.size()):
		var x1: int = table[i][0]
		if x <= x1:
			var x0: int = table[i - 1][0]
			var y0: int = table[i - 1][1]
			var y1: int = table[i][1]
			if x1 == x0:
				return y1
			return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
	return int(table[table.size() - 1][1])

## Formatea un valor FP como texto con 1 decimal (para la interfaz y los informes).
static func fmt(v: int, decimals: int = 0) -> String:
	if decimals <= 0:
		return str(floordiv(v, ONE))
	var neg := v < 0
	var a := absi(v)
	var ent := a / ONE
	var frac := (a % ONE) / 100
	return ("-" if neg else "") + str(ent) + "," + str(frac)
