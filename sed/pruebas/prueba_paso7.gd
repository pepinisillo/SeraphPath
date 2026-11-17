extends "res://pruebas/comun.gd"
## Paso 7: el puesto de control completo con sus cuatro soldados.
## Además de comprobar rutas y muros transparentes, busca una ruta de la M a la E en la que
## ningún soldado vea a Mika nunca, y la reproduce en el juego real para confirmarla.




func _initialize():
	await process_frame
	print("A) Los cuatro soldados y sus rutas")
	var m: Mapa = await nuevo_mapa(true)
	var nombres := []
	for s in m.soldados():
		nombres.append(str(s.name))
	comprobar("soldados", nombres, ["S1", "S2", "S3", "S4"])
	comprobar("S2 en vaivén", m.get_node("S2").en_bucle, false)
	var extremos := {"S2": [Vector2(4.5, 3.5), Vector2(9.5, 3.5)], "S3": [Vector2(9.5, 4.5), Vector2(9.5, 8.5)], "S4": [Vector2(5.5, 0.5), Vector2(8.5, 0.5)]}
	var tocados := {}
	m.mika.pos = FUERA
	for i in roundi(30.0 / DT):
		paso(m)
		m.mika.sed = 0
		for nombre in extremos:
			for punto in extremos[nombre]:
				if m.get_node(nombre).pos.distance_to(punto) < 0.01:
					tocados[nombre + str(punto)] = true
	comprobar("cada vaivén llega a sus dos extremos", tocados.size(), 6)
	comprobar("nadie vio nada", m.estadisticas.alarmas == 0 and m.soldados().all(func(s): return s.estado == Soldado.Estado.OCULTO), true)
	m.queue_free()

	print("B) Muros semitransparentes")
	m = await nuevo_mapa(true)
	m.mika.pos = Vector2(2.5, 5.65) # justo detrás del muro (2,6)
	paso(m)
	comprobar("el muro de delante se vuelve transparente", m.muros.transparentes.has(Vector2i(2, 6)), true)
	comprobar("el de detrás no", m.muros.transparentes.has(Vector2i(2, 4)), false)
	m.mika.pos = Vector2(9.5, 5.5) # columna 9: ningún muro delante
	paso(m)
	comprobar("sin muros delante, ninguno transparente", m.muros.transparentes.is_empty(), true)
	m.queue_free()

	print("C) Ruta sin ser visto")
	m = await nuevo_mapa(true)
	grabar_linea(m)
	var ruta := buscar_ruta(m, Vector2i(0, 9), Vector2i(9, 0))
	comprobar("existe una ruta de la M a la E sin que nadie lo vea", ruta.is_empty(), false)
	m.queue_free()
	if not ruta.is_empty():
		print("    ruta (casilla, segundo): ", ruta.map(func(p): return "%s@%.1f" % [p[0], p[1]]))
		var directo := tiempo_directo(m, Vector2i(0, 9), Vector2i(9, 0))
		print("    llega en %.1f s; yendo directo sin esperar se tarda %.1f s" % [ruta[-1][1], directo])
		comprobar("no basta con correr: la ruta exige esperar (al menos 1,4 veces el tiempo directo)", ruta[-1][1] >= directo * 1.4, true)
		m = await nuevo_mapa(true)
		reproducir(m, ruta)
		comprobar("al reproducirla llega a la salida", m.terminado, true)
		comprobar("sin alarmas", m.estadisticas.alarmas, 0)
		m.queue_free()
		paused = false
	terminar()
