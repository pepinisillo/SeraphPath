extends "res://pruebas/comun.gd"
## Patrullas al azar: cada soldado empieza en un punto cualquiera de su ruta y las pausas varían.
## Con varias semillas fijas, en los dos mapas de infiltración: que cada soldado empiece sobre su
## ruta, que las partidas sean distintas, que nadie vea a Mika en el inicio y que siga existiendo
## una ruta sin ser visto (con los grupos saliendo al pisar su zona) que, al reproducirla en
## el juego, llegue a la salida.

const SEMILLAS := [1, 2, 3] # cada una tarda unos 30 s por mapa
const MAPAS := {
	"res://escenas/mapa_puesto_control.tscn": [Vector2i(1, 18), Vector2i(29, 0)],
	"res://escenas/mapa_tuneles.tscn": [Vector2i(1, 16), Vector2i(29, 0)],
}


func _initialize():
	await process_frame
	Soldado.patrullas_al_azar = true

	print("A) Pausas")
	var pausas := []
	var suelto := Soldado.new()
	for i in 500:
		pausas.append(suelto._pausa_en_punto())
	suelto.free()
	comprobar("dentro del margen", [pausas.min() >= Config.SOLDADO_PAUSA_RUTA_MIN, pausas.max() <= Config.SOLDADO_PAUSA_RUTA_MAX], [true, true])
	comprobar("y variadas", pausas.max() - pausas.min() > 0.4, true)

	for escena in MAPAS:
		var inicio: Vector2i = MAPAS[escena][0]
		var meta: Vector2i = MAPAS[escena][1]
		print("B) %s" % escena.get_file())
		var arranques := {}
		var tiempos := []
		for semilla in SEMILLAS:
			Soldado.semilla_fija = semilla
			var m: Mapa = await cargar_mapa(escena)
			aparecer_todos(m)
			var foto := []
			for s in m.soldados():
				foto.append(s.pos.snapped(Vector2(0.01, 0.01)))
				if _distancia_a_ruta(s) > 0.01:
					ok = false
					print("FALLO: semilla %d, %s empieza fuera de su ruta: %s" % [semilla, s.name, s.pos])
			arranques[str(foto)] = true
			var maximo := 0.0
			for i in roundi(30.0 / DT):
				paso(m)
				m.mika.sed = 0
				for s in m.soldados():
					maximo = maxf(maximo, s.medidor)
			if maximo > 0.0:
				ok = false
				print("FALLO: semilla %d, alguien ve a Mika quieto en el inicio" % semilla)
			m.queue_free()

			var ruta: Array = await buscar_ruta_con_apariciones(escena, inicio, meta)
			if ruta.is_empty():
				ok = false
				print("FALLO: semilla %d, no hay ruta sin ser visto" % semilla)
				continue
			m = await cargar_mapa(escena) # los grupos salen solos, al pisar Mika su zona
			if not reproducir(m, ruta, false) or m.estadisticas.alarmas > 0:
				ok = false
				print("FALLO: semilla %d, la ruta no llega sin ser visto al reproducirla" % semilla)
			m.queue_free()
			paused = false
			tiempos.append(ruta[-1][1])
		comprobar("cada semilla empieza distinto", arranques.size(), SEMILLAS.size())
		var m: Mapa = await cargar_mapa(escena)
		print("    ruta sin ser visto en %s s (directo: %.1f s)" % [tiempos.map(func(t): return "%.1f" % t), tiempo_directo(m, inicio, meta)])
		m.queue_free()

	Soldado.semilla_fija = -1
	Soldado.patrullas_al_azar = false
	terminar()


## Distancia de la posición del soldado al tramo más cercano de su ruta.
func _distancia_a_ruta(s: Soldado) -> float:
	var mejor := INF
	var n := s.ruta.size()
	for i in (n if s.en_bucle else n - 1):
		var a := Vector2(s.ruta[i]) + Vector2(0.5, 0.5)
		var b := Vector2(s.ruta[(i + 1) % n]) + Vector2(0.5, 0.5)
		mejor = minf(mejor, s.pos.distance_to(Geometry2D.get_closest_point_to_segment(s.pos, a, b)))
	return mejor
