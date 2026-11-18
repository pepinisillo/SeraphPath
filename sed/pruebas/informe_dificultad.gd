extends "res://pruebas/comun.gd"
## Informe de dificultad con jugadores automáticos: recorre los mapas, los jefes y la Prueba de
## la sed, y escribe los números en docs/dificultad.md para ajustar con datos.
## No es una prueba (no lo lanza ejecutar.sh): se ejecuta a mano, tarda varios minutos.
##   godot --headless --path . -s res://pruebas/informe_dificultad.gd

const SEMILLAS := [1, 2, 3]
const INFILTRACIONES := [
	["Puesto de control", "res://escenas/mapa_puesto_control.tscn", Vector2i(1, 18), Vector2i(29, 0)],
	["Túneles de abastecimiento", "res://escenas/mapa_tuneles.tscn", Vector2i(1, 16), Vector2i(29, 0)],
	["Ruinas de Shinjuku", "res://escenas/mapa_shinjuku.tscn", Vector2i(0, 18), Vector2i(31, 1)],
	["La estación hundida", "res://escenas/mapa_estacion.tscn", Vector2i(0, 12), Vector2i(29, 1)],
	["Dentro de la muralla", "res://escenas/mapa_shibuya.tscn", Vector2i(0, 16), Vector2i(29, 0)],
	["El hueco del río", "res://escenas/mapa_rio.tscn", Vector2i(9, 12), Vector2i(27, 0)],
]


func _initialize():
	await process_frame
	var lineas := PackedStringArray([
		"# Dificultad medida con jugadores automáticos",
		"",
		"Lo genera `sed/pruebas/informe_dificultad.gd` (%s). Son jugadores perfectos: un jugador de verdad tarda más y se equivoca, así que esto marca el suelo de la dificultad, no la experiencia." % Time.get_date_string_from_system(),
		"",
		"## Infiltraciones",
		"",
		"Con patrullas al azar (semillas %s) y los grupos saliendo al pisar su zona. «Ruta» es lo que tarda la ruta sin ser visto más corta que encuentra la planificación (prudente); «directo», lo que se tarda corriendo sin esperar; «¿corriendo te ven?», si ir directo te delata." % ", ".join(SEMILLAS.map(func(x): return str(x))),
		"",
		"«Menos exacto» repite cada ruta 5 veces llegando a cada casilla hasta 0,15 s tarde (sin acumularlo), como alguien que reacciona algo tarde: cuántas veces sigue sin ser visto.",
		"",
		"| Mapa | Ruta sin ser visto (s) | Directo (s) | Veces más | ¿Corriendo te ven? | Menos exacto |",
		"| --- | --- | --- | --- | --- | --- |",
	])
	Soldado.patrullas_al_azar = true
	for datos in INFILTRACIONES:
		var tiempos := []
		var te_ven := 0
		var directo := 0.0
		var exactos := 0
		var intentos := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for semilla in SEMILLAS:
			Soldado.semilla_fija = semilla
			var ruta: Array = await buscar_ruta_con_apariciones(datos[1], datos[2], datos[3])
			tiempos.append(ruta[-1][1] if not ruta.is_empty() else -1.0)
			var m: Mapa = await cargar_mapa(datos[1])
			directo = tiempo_directo(m, datos[2], datos[3])
			if not reproducir(m, ruta_directa(m, datos[2], datos[3]), false):
				te_ven += 1
			m.queue_free()
			paused = false
			if not ruta.is_empty():
				for intento in 5:
					var otra: Mapa = await cargar_mapa(datos[1])
					intentos += 1
					if reproducir(otra, ruta_con_retrasos(ruta, 0.15, rng), false):
						exactos += 1
					otra.queue_free()
					paused = false
		var validos := tiempos.filter(func(t): return t >= 0.0)
		var media: float = validos.reduce(func(a, b): return a + b, 0.0) / maxf(1.0, validos.size())
		var texto_rutas := ", ".join(tiempos.map(func(t): return "%.1f" % t if t >= 0.0 else "sin ruta"))
		lineas.append("| %s | %s | %.1f | %.1f | %d de %d | %d de %d |" % [datos[0], texto_rutas, directo, media / maxf(directo, 0.1), te_ven, SEMILLAS.size(), exactos, intentos])
		print("    %s: %s" % [datos[0], texto_rutas])
	Soldado.patrullas_al_azar = false
	Soldado.semilla_fija = -1

	lineas.append_array(["", "## Jefes", "", "Dos jugadores: uno que no esquiva nada y otro que sale de lo marcado en el suelo (y, contra Crowley y Guren, solo pega mientras se recuperan).", "", "| Jefe | Sin esquivar | Esquivando |", "| --- | --- | --- |"])
	var sin := await huir_de_ferid("res://escenas/mapa_hangar.tscn", Vector2(39.5, 5.5), false)
	var con := await huir_de_ferid("res://escenas/mapa_hangar.tscn", Vector2(39.5, 5.5), true)
	lineas.append("| Ferid (llegar a la rampa) | %s, atrapado %d veces, vida %d, %.1f s | %s, atrapado %d veces, vida %d, %.1f s |" % [
		"llega" if sin[0] else "no llega", sin[1], sin[2], sin[3], "llega" if con[0] else "no llega", con[1], con[2], con[3]])
	for jefe in [["Crowley", "res://escenas/mapa_cruce.tscn"], ["Guren", "res://escenas/mapa_patio.tscn"]]:
		sin = await pelear_con_jefe(jefe[1], false)
		con = await pelear_con_jefe(jefe[1], true)
		lineas.append("| %s | %s, vida de Mika %d, del jefe %d, %.1f s | %s, vida de Mika %d, del jefe %d, %.1f s |" % [
			jefe[0], "gana" if sin[0] else "pierde", sin[1], sin[2], sin[3], "gana" if con[0] else "pierde", con[1], con[2], con[3]])
	print("    jefes hechos")

	lineas.append_array(["", "## Prueba de la sed", "", "Un jugador que va derecho hacia Yuu rodeando a los ecos.", "", "| Mapa | Sed al entrar | Resultado | Tiempo (s) | Sed al salir |", "| --- | --- | --- | --- | --- |"])
	for zona in [1, 2, 3]:
		var escena: String = EstadoExpedicion.ZONAS[zona].prueba
		for sed_inicial in [30, 55, 70]:
			var r := await prueba_de_la_sed_con_bot(escena, sed_inicial)
			lineas.append("| %s | %d | %s | %.1f | %d |" % [escena.get_file(), sed_inicial, r[0], r[1], r[2]])
	lineas.append("")
	var ruta_docs := ProjectSettings.globalize_path("res://").path_join("../docs/dificultad.md").simplify_path()
	var f := FileAccess.open(ruta_docs, FileAccess.WRITE)
	f.store_string("\n".join(lineas))
	f.close()
	print("INFORME escrito en %s" % ruta_docs)
	terminar()
