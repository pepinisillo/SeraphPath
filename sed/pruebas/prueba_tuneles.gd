extends "res://pruebas/comun.gd"
## Segundo mapa de infiltración, «Túneles de abastecimiento»: estructura, patrullas, que el inicio
## sea seguro, que exista una ruta sin ser visto (y cuánto tarda) y que la expedición lo use.

const ESCENA := "res://escenas/mapa_tuneles.tscn"


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	comprobar("nombre", m.nombre, "Túneles de abastecimiento")
	comprobar("tamaño", [m.ancho, m.alto], [14, 11])
	comprobar("inicio y salida", [m.inicio_mika, m.celda_salida], [Vector2i(0, 6), Vector2i(13, 0)])
	comprobar("vial", m.celdas_vial, [Vector2i(11, 8)])
	comprobar("cinco soldados", m.soldados().map(func(s): return str(s.name)), ["T1", "T2", "T3", "T4", "T5"])
	for s in m.soldados():
		for celda in s.ruta:
			if m.es_muro(celda):
				ok = false
				print("FALLO: %s tiene un punto de ruta en un muro: %s" % [s.name, celda])
	comprobar("hay camino de la M a la E", m.camino(Vector2(0.5, 6.5), Vector2(13.5, 0.5)).is_empty(), false)

	print("B) Patrullas y un inicio seguro")
	var maximo := 0.0
	for i in roundi(60.0 / DT):
		paso(m)
		m.mika.sed = 0
		for s in m.soldados():
			maximo = maxf(maximo, s.medidor)
	comprobar("nadie ve a Mika quieto en el inicio en 60 s", maximo, 0.0)
	comprobar("sin alarmas", m.estadisticas.alarmas, 0)
	m.queue_free()

	print("C) Ruta sin ser visto")
	m = await cargar_mapa(ESCENA)
	grabar_linea(m)
	var ruta := buscar_ruta(m, Vector2i(0, 6), Vector2i(13, 0))
	comprobar("existe una ruta de la M a la E sin que nadie lo vea", ruta.is_empty(), false)
	m.queue_free()
	if not ruta.is_empty():
		print("    llega en %.1f s: %s" % [ruta[-1][1], ruta.map(func(p): return "%s@%.1f" % [p[0], p[1]])])
		var directo := tiempo_directo(m, Vector2i(0, 6), Vector2i(13, 0))
		print("    yendo directo sin esperar se tarda %.1f s" % directo)
		comprobar("no basta con correr: la ruta exige esperar (al menos 1,4 veces el tiempo directo)", ruta[-1][1] >= directo * 1.4, true)
		m = await cargar_mapa(ESCENA)
		reproducir(m, ruta)
		comprobar("al reproducirla llega a la salida", m.terminado, true)
		comprobar("sin alarmas", m.estadisticas.alarmas, 0)
		m.queue_free()
		paused = false

	print("D) En la expedición")
	var e := EstadoExpedicion.actual()
	e.nueva()
	comprobar("la primera infiltración es el puesto de control", e.escena_infiltracion(), e.ESCENA_INFILTRACION)
	e.indice = 1
	e.elegir_ruta("arriesgada")
	e.indice = 2
	comprobar("la de la ruta arriesgada son los túneles", [e.parada_actual(), e.escena_infiltracion()], ["infiltracion", ESCENA])
	e.activa = false
	terminar()
