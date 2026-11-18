extends "res://pruebas/comun.gd"
## «Puesto de control» grande: el puesto original (10 × 10, con S1–S4) es el patio central, con
## afueras, barracones, almacén y la puerta norte alrededor. Estructura, grupos, inicio seguro,
## ruta sin ser visto con los grupos saliendo al pisar su zona y que correr directo te delate.

const ESCENA := "res://escenas/mapa_puesto_control.tscn"
const INICIO := Vector2i(1, 18)
const SALIDA := Vector2i(29, 0)


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	comprobar("nombre", m.nombre, "Puesto de control")
	comprobar("tamaño", [m.ancho, m.alto], [30, 20])
	comprobar("inicio y salida", [m.inicio_mika, m.celda_salida], [INICIO, SALIDA])
	comprobar("vial (el del puesto original)", m.celdas_vial, [Vector2i(14, 13)])
	comprobar("soldados fijos", m.soldados().map(func(s): return str(s.name)), ["S1", "S2", "S3", "S4", "F1"])
	var original: Mapa = load("res://escenas/mapa_pasos.tscn").instantiate()
	var filas := original.plano.strip_edges().split("\n")
	original.free()
	var igual := true
	for f in 10:
		for c in 10:
			var viejo := filas[f].strip_edges()[c]
			if (viejo if not viejo in ["M", "E"] else ".") != m.caracter(Vector2i(c + 6, f + 8)):
				igual = false
	comprobar("el patio central es el puesto original", igual, true)
	comprobar("grupos", m.apariciones().map(func(a): return [str(a.name), a.pendientes.map(func(s): return str(s.name)), a.probabilidad]),
		[["GrupoBarracones", ["B1", "B2"], 1.0], ["GrupoPuerta", ["P1"], 0.5], ["GrupoAlmacen", ["A1"], 0.5]])
	aparecer_todos(m)
	for s in m.soldados():
		_ruta_sin_muros(m, s)
	comprobar("hay camino de la M a la E", m.camino(Vector2(INICIO) + Vector2(0.5, 0.5), Vector2(SALIDA) + Vector2(0.5, 0.5)).is_empty(), false)
	m.queue_free()

	print("C) Sorteo de los grupos con probabilidad 0,5")
	Aparicion.forzar = false
	var existe := {true: 0, false: 0}
	for semilla in 20:
		Soldado.semilla_fija = semilla
		m = await cargar_mapa(ESCENA)
		existe[m.get_node("GrupoPuerta").estado != Aparicion.Estado.DESCARTADO] += 1
		comprobar("el de probabilidad 1 siempre existe", m.get_node("GrupoBarracones").estado, Aparicion.Estado.ESPERANDO)
		m.queue_free()
	comprobar("a veces está y a veces no", existe[true] > 0 and existe[false] > 0, true)
	Aparicion.forzar = true
	Soldado.semilla_fija = -1

	print("D) Inicio seguro, con todos los grupos")
	m = await cargar_mapa(ESCENA)
	aparecer_todos(m)
	var maximo := 0.0
	for i in roundi(60.0 / DT):
		paso(m)
		m.mika.sed = 0
		for s in m.soldados():
			maximo = maxf(maximo, s.medidor)
	comprobar("nadie ve a Mika quieto en el inicio en 60 s", maximo, 0.0)
	m.queue_free()

	print("E) Ruta sin ser visto (cada grupo sale cuando la ruta pisa su zona)")
	var ruta: Array = await buscar_ruta_con_apariciones(ESCENA, INICIO, SALIDA)
	comprobar("existe una ruta de la M a la E sin que nadie lo vea", ruta.is_empty(), false)
	m = await cargar_mapa(ESCENA)
	var directo := tiempo_directo(m, INICIO, SALIDA)
	m.queue_free()
	if not ruta.is_empty():
		print("    llega en %.1f s (yendo directo sin esperar: %.1f s)" % [ruta[-1][1], directo])
		print("    ", ruta.map(func(p): return "%s@%.1f" % [p[0], p[1]]))
		comprobar("no basta con correr (al menos 1,4 veces el tiempo directo)", ruta[-1][1] >= directo * 1.4, true)
		m = await cargar_mapa(ESCENA) # aquí los grupos salen solos, al pisar Mika su zona
		reproducir(m, ruta)
		comprobar("al reproducirla llega a la salida", m.terminado, true)
		comprobar("sin alarmas", m.estadisticas.alarmas, 0)
		m.queue_free()
		paused = false

	print("F) Corriendo directo a la salida, te ven")
	m = await cargar_mapa(ESCENA)
	comprobar("ir directo sin esperar no llega sin ser visto", reproducir(m, ruta_directa(m, INICIO, SALIDA), false), false)
	m.queue_free()
	paused = false

	print("G) En la expedición")
	var e := EstadoExpedicion.actual()
	e.nueva()
	comprobar("la primera infiltración es el puesto de control", e.escena_infiltracion(), ESCENA)
	e.activa = false
	terminar()


## Cada tramo de la ruta va en línea recta por casillas sin muro.
func _ruta_sin_muros(m: Mapa, s: Soldado) -> void:
	var n := s.ruta.size()
	for i in (n if s.en_bucle else n - 1):
		var a := Vector2(s.ruta[i]) + Vector2(0.5, 0.5)
		var b := Vector2(s.ruta[(i + 1) % n]) + Vector2(0.5, 0.5)
		if not m.hay_linea_de_vision(a, b) or m.es_muro(s.ruta[i]):
			ok = false
			print("FALLO: el tramo %s → %s de %s cruza un muro" % [s.ruta[i], s.ruta[(i + 1) % n], s.name])
