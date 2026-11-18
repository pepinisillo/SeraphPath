extends "res://pruebas/comun.gd"
## Genera mapas de infiltración al azar (Generador) y se queda solo con los que pasan las mismas
## comprobaciones que los hechos a mano: inicio seguro, que correr directo te delate, que exista
## una ruta sin ser visto que tarde al menos 1,4 veces lo directo y se pueda reproducir, y que
## siga existiendo con las patrullas al azar. Los buenos van a escenas/generados/ y a
## datos/mapas_generados.json, de donde los toma la expedición.
## No es una prueba (no lo lanza ejecutar.sh): se ejecuta a mano y tarda varios minutos.
##   godot --headless --path . -s res://pruebas/generar_mapas.gd

const POR_ZONA := 4 # mapas buenos que se buscan en cada zona
const INTENTOS := 60 # candidatos como mucho por zona
const MAXIMO := 40.0 # s: una ruta sin ser visto más larga obliga a esperar demasiado
const CARPETA := "res://escenas/generados"
const INDICE := "res://datos/mapas_generados.json"
const NOMBRES := {1: "Pasillos de Sanguinem", 2: "Ruinas sin nombre", 3: "Barracones de Shibuya"}


func _initialize():
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var indice := {}
	for zona in [1, 2, 3]:
		var buenos := []
		var semilla: int = zona * 1000
		var intentos := 0
		while buenos.size() < POR_ZONA and intentos < INTENTOS:
			intentos += 1
			semilla += 1
			var datos := Generador.generar(semilla, zona)
			if datos.is_empty():
				continue
			var nombre := "%s %d" % [NOMBRES[zona], buenos.size() + 1]
			var ruta := "%s/mapa_gen_z%d_%d.tscn" % [CARPETA, zona, semilla]
			var f := FileAccess.open(ruta, FileAccess.WRITE)
			f.store_string(Generador.escena(datos, "MapaGenerado", nombre))
			f.close()
			var resultado: Dictionary = await _validar(ruta, datos.inicio, datos.salida)
			print("    zona %d, semilla %d: %s" % [zona, semilla, resultado.motivo])
			if resultado.bueno:
				buenos.append({"escena": ruta, "nombre": nombre, "semilla": semilla, "ruta": resultado.tiempo, "directo": resultado.directo})
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
		indice[str(zona)] = buenos
		print("ZONA %d: %d buenos en %d intentos" % [zona, buenos.size(), intentos])
	var f := FileAccess.open(INDICE, FileAccess.WRITE)
	f.store_string(JSON.stringify(indice, "\t"))
	f.close()
	terminar()


## ¿El candidato sirve? Devuelve {bueno, motivo, tiempo, directo}.
func _validar(escena: String, inicio: Vector2i, meta: Vector2i) -> Dictionary:
	Soldado.patrullas_al_azar = false
	var m: Mapa = await cargar_mapa(escena)
	var directo := tiempo_directo(m, inicio, meta)
	if m.camino(Vector2(inicio) + Vector2(0.5, 0.5), Vector2(meta) + Vector2(0.5, 0.5)).is_empty():
		m.queue_free()
		return {"bueno": false, "motivo": "sin camino"}
	var maximo := 0.0
	for i in roundi(30.0 / DT):
		paso(m)
		m.mika.sed = 0
		for s in m.soldados():
			maximo = maxf(maximo, s.medidor)
	m.queue_free()
	if maximo > 0.0:
		return {"bueno": false, "motivo": "inicio vigilado"}
	m = await cargar_mapa(escena)
	var corriendo := reproducir(m, ruta_directa(m, inicio, meta), false)
	m.queue_free()
	paused = false
	if corriendo:
		return {"bueno": false, "motivo": "basta con correr"}
	var ruta: Array = await buscar_ruta_con_apariciones(escena, inicio, meta)
	if ruta.is_empty():
		return {"bueno": false, "motivo": "sin ruta sin ser visto"}
	if ruta[-1][1] < directo * 1.4:
		return {"bueno": false, "motivo": "demasiado fácil (%.1f s frente a %.1f)" % [ruta[-1][1], directo]}
	if ruta[-1][1] > MAXIMO:
		return {"bueno": false, "motivo": "demasiada espera (%.1f s)" % ruta[-1][1]}
	m = await cargar_mapa(escena)
	var llega := reproducir(m, ruta, false)
	m.queue_free()
	paused = false
	if not llega:
		return {"bueno": false, "motivo": "la ruta no se reproduce"}
	Soldado.patrullas_al_azar = true
	for semilla in [1, 2]:
		Soldado.semilla_fija = semilla
		if (await buscar_ruta_con_apariciones(escena, inicio, meta)).is_empty():
			Soldado.patrullas_al_azar = false
			Soldado.semilla_fija = -1
			return {"bueno": false, "motivo": "sin ruta con la semilla %d" % semilla}
	Soldado.patrullas_al_azar = false
	Soldado.semilla_fija = -1
	return {"bueno": true, "motivo": "BUENO: %.1f s frente a %.1f" % [ruta[-1][1], directo], "tiempo": ruta[-1][1], "directo": directo}
