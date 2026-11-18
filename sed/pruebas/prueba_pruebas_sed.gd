extends "res://pruebas/comun.gd"
## Un mapa de la Prueba de la sed por zona: el orfanato, la calle encendida y el cuarto blanco.
## Cada uno se puede superar entrando con poca sed y es más duro que el anterior.


func _initialize():
	await process_frame
	var escenas := [1, 2, 3].map(func(z): return EstadoExpedicion.ZONAS[z].prueba)
	comprobar("uno distinto por zona", escenas, ["res://escenas/mapa_prueba_sed.tscn", "res://escenas/mapa_prueba_calle.tscn", "res://escenas/mapa_prueba_cuarto.tscn"])
	var subidas := []
	for escena in escenas:
		var m: Mapa = await cargar_mapa(escena)
		comprobar("%s: es una prueba, con ecos, Yuu y un punto cercano" % escena.get_file(),
			[m.prueba_de_la_sed, m.ecos().size() >= 8, m.celda_salida.x >= 0, not m.es_muro(m.inicio_cerca)], [true, true, true, true])
		m.queue_free()
		var r := await prueba_de_la_sed_con_bot(escena, 30)
		comprobar("%s: entrando con sed 30 se supera" % escena.get_file(), r[0], "superada")
		subidas.append(r[2] - 30)
	comprobar("cada zona aprieta más que la anterior", subidas[0] <= subidas[1] and subidas[1] <= subidas[2], true)
	print("    la sed sube %s" % [str(subidas)])
	var e := EstadoExpedicion.actual()
	e.nueva()
	e.pasar_de_zona()
	e.indice = 3
	e.humanidad = 3
	e.entrar()
	await process_frame
	await process_frame
	await process_frame
	var s := current_scene
	if s.name == "Escena": # con guion en disco, antes la entrada de la zona
		s.dialogo.saltar()
		for i in 3:
			await process_frame
		s = current_scene
	comprobar("la expedición usa el de su zona", str(s.name), "MapaPruebaCalle")
	e.volver_al_titulo()
	terminar()
