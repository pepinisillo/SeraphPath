extends "res://pruebas/comun.gd"
## Generador de mapas: con muchas semillas, cada mapa tiene inicio y salida conectados, nadie
## patrulla la sala de inicio, las rutas van en línea recta por suelo, la escena se carga, y la
## emboscada de la expedición usa los mapas generados de su zona (si los hay).


func _initialize():
	await process_frame
	print("A) Muchas semillas")
	var malos := 0
	var hechos := 0
	for zona in [1, 2, 3]:
		for semilla in range(zona * 100, zona * 100 + 30):
			var d := Generador.generar(semilla, zona)
			if d.is_empty():
				continue
			hechos += 1
			var filas: PackedStringArray = d.plano.split("\n")
			var en := func(c: Vector2i) -> String: return filas[c.y][c.x]
			if en.call(d.inicio) != "M" or en.call(d.salida) != "E":
				malos += 1
				print("FALLO: semilla %d sin M o E" % semilla)
			for e in d.entidades:
				var a: Vector2i = e.ruta[0]
				var b: Vector2i = e.ruta[1]
				var paso := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
				var c := a
				while c != b:
					if en.call(c) == "#":
						malos += 1
						print("FALLO: semilla %d, %s cruza un muro en %s" % [semilla, e.nombre, c])
						break
					c += paso
				if Vector2(a).distance_to(Vector2(d.inicio)) < 4.0 and e.tipo == "soldado":
					malos += 1
					print("FALLO: semilla %d, %s patrulla junto al inicio" % [semilla, e.nombre])
	comprobar("los mapas generados están bien formados", [hechos > 60, malos], [true, 0])
	var tipos := []
	for zona in [1, 2, 3]:
		tipos.append(Generador.generar(zona * 100 + 1, zona).entidades.map(func(e): return e.tipo).filter(func(t): return t != "soldado"))
	comprobar("el enemigo de cada zona", tipos.map(func(t): return t.filter(func(x): return x != "hechicero")), [["vampiro"], ["jinete"], ["portador"]])
	var con_grupo := 0
	var con_hechicero := 0
	for semilla in range(300, 330):
		var dz := Generador.generar(semilla, 3)
		if dz.is_empty():
			continue
		con_grupo += int(not dz.grupos.is_empty())
		con_hechicero += int(dz.entidades.any(func(x): return x.tipo == "hechicero"))
	comprobar("algunos tienen grupo que aparece y, en Shibuya, hechicero", [con_grupo > 3, con_hechicero > 10], [true, true])
	var con_atajo := 0
	for semilla in range(500, 530):
		var dc := Generador.generar(semilla, 1)
		con_atajo += int(not dc.is_empty() and dc.atajo)
	comprobar("hay mapas con atajo (dos caminos que elegir)", con_atajo > 5, true)

	print("A2) Volteados")
	var base := Generador.generar(101, 3)
	var v := Generador.voltear(base, true, true)
	var filas_b: PackedStringArray = base.plano.split("\n")
	var filas_v: PackedStringArray = v.plano.split("\n")
	comprobar("el plano se voltea", filas_v[0], filas_b[-1].reverse())
	comprobar("inicio y salida van con él", [v.inicio, v.salida], [Vector2i(Generador.ANCHO - 1, Generador.ALTO - 1) - base.inicio, Vector2i(Generador.ANCHO - 1, Generador.ALTO - 1) - base.salida])
	comprobar("la M y la E siguen en su sitio", [filas_v[v.inicio.y][v.inicio.x], filas_v[v.salida.y][v.salida.x]], ["M", "E"])
	var direcciones := {}
	for semilla in range(600, 640):
		var dv := Generador.generar(semilla, 1)
		if not dv.is_empty():
			direcciones[str(dv.volteado)] = true
	comprobar("salen en las cuatro direcciones", direcciones.size(), 4)

	print("B) La escena se carga")
	var ruta := "user://mapa_gen_prueba.tscn"
	var d := Generador.generar(101, 1)
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(Generador.escena(d, "MapaGenerado", "Prueba"))
	f.close()
	var m: Mapa = await cargar_mapa(ruta)
	comprobar("con su plano, Mika y sus enemigos", [m.inicio_mika, m.celda_salida, m.soldados().size() + m.vampiros().size() > 0], [d.inicio, d.salida, true])
	m.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))

	print("C) La emboscada usa los mapas generados de su zona")
	var e := EstadoExpedicion.actual()
	var indice := "user://generados_prueba.json"
	var f2 := FileAccess.open(indice, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"1": [{"escena": "res://escenas/mapa_shinjuku.tscn"}], "2": []}))
	f2.close()
	e.archivo_generados = indice
	e.nueva()
	comprobar("zona 1: el generado", e.escena_emboscada(), "res://escenas/mapa_shinjuku.tscn")
	e.zona = 2
	comprobar("sin generados, la primera infiltración", e.escena_emboscada(), e.datos_zona().infiltracion)
	e.zona = 1
	var arriesgados := {}
	for i in 30:
		e.mapa_arriesgado = ""
		e.indice = 2
		arriesgados[e.escena_infiltracion()] = true
	comprobar("la infiltración arriesgada: a veces la hecha a mano, a veces una generada", arriesgados.keys().size(), 2)
	var elegido := e.escena_infiltracion()
	comprobar("y no cambia al volver a preguntar en la misma zona", e.escena_infiltracion(), elegido)
	e.archivo_generados = "res://datos/mapas_generados.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(indice))
	e.activa = false
	terminar()
