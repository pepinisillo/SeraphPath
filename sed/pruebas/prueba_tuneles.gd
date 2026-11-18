extends "res://pruebas/comun.gd"
## «Túneles de abastecimiento», mapa grande de salas y pasillos: estructura, grupos que aparecen
## al entrar en su zona (aviso, gracia y sorteo), inicio seguro, ruta sin ser visto con todos
## los grupos en el mapa y que la expedición lo use.

const ESCENA := "res://escenas/mapa_tuneles.tscn"
const INICIO := Vector2i(1, 16)
const SALIDA := Vector2i(29, 0)


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	comprobar("nombre", m.nombre, "Túneles de abastecimiento")
	comprobar("tamaño", [m.ancho, m.alto], [30, 18])
	comprobar("inicio y salida", [m.inicio_mika, m.celda_salida], [INICIO, SALIDA])
	comprobar("vial", m.celdas_vial, [Vector2i(28, 15)])
	comprobar("soldados fijos", m.soldados().map(func(s): return str(s.name)), ["A1", "A2", "F1"])
	comprobar("grupos", m.apariciones().map(func(a): return [str(a.name), a.pendientes.map(func(s): return str(s.name)), a.probabilidad]),
		[["GrupoSalaNorte", ["B1", "B2"], 1.0], ["GrupoSalida", ["F2"], 0.5], ["GrupoVial", ["V1"], 0.5]])
	aparecer_todos(m)
	for s in m.soldados():
		_ruta_sin_muros(m, s)
	comprobar("hay camino de la M a la E", m.camino(Vector2(INICIO) + Vector2(0.5, 0.5), Vector2(SALIDA) + Vector2(0.5, 0.5)).is_empty(), false)
	m.queue_free()

	print("B) Un grupo aparece al entrar en su zona")
	m = await cargar_mapa(ESCENA)
	var norte: Aparicion = m.get_node("GrupoSalaNorte")
	m.mika.pos = Vector2(7.5, 14.5) # en el primer pasillo, antes de la zona
	paso(m, 0.5)
	comprobar("fuera de la zona no aparece", [norte.estado, m.soldados().size()], [Aparicion.Estado.ESPERANDO, 3])
	m.mika.pos = Vector2(11.5, 14.5)
	paso(m)
	comprobar("al pisarla avisa", norte.estado, Aparicion.Estado.AVISANDO)
	paso(m, Config.APARICION_AVISO - 0.1)
	comprobar("durante el aviso aún no están", m.soldados().size(), 3)
	paso(m, 0.2)
	var b1: Soldado = m.get_node("B1")
	comprobar("tras el aviso aparecen", [norte.estado, m.soldados().size()], [Aparicion.Estado.APARECIDO, 5])
	comprobar("en el primer punto de su ruta", b1.pos.distance_to(Vector2(9.5, 4.5)) < 0.3, true)
	b1._pausa = 10.0 # que se quede quieto, mirando al norte
	m.mika.pos = Vector2(9.5, 2.0) # justo delante de B1
	paso(m, Config.APARICION_GRACIA * 0.5)
	comprobar("recién aparecido no puede verlo", b1.medidor, 0.0)
	paso(m, Config.APARICION_GRACIA)
	comprobar("pasada la gracia, sí", b1.medidor > 0.0, true)
	m.queue_free()

	print("C) Sorteo de los grupos con probabilidad 0,5")
	Aparicion.forzar = false
	var existe := {true: 0, false: 0}
	for semilla in 20:
		Soldado.semilla_fija = semilla
		m = await cargar_mapa(ESCENA)
		existe[m.get_node("GrupoSalida").estado != Aparicion.Estado.DESCARTADO] += 1
		comprobar("el de probabilidad 1 siempre existe", m.get_node("GrupoSalaNorte").estado, Aparicion.Estado.ESPERANDO)
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
	comprobar("la primera infiltración es el puesto de control", e.escena_infiltracion(), e.ESCENA_INFILTRACION)
	e.indice = 1
	e.elegir_ruta("arriesgada")
	e.indice = 2
	comprobar("la de la ruta arriesgada: los túneles (o un mapa generado)", [e.parada_actual(), e.escena_infiltracion() in [ESCENA] + e.mapas_generados(1)], ["infiltracion", true])
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
