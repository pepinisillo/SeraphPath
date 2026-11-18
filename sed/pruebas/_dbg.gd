extends "res://pruebas/comun.gd"
func _initialize():
	await process_frame
	var ruta: Array = await buscar_ruta_con_apariciones("res://escenas/mapa_estacion.tscn", Vector2i(0, 12), Vector2i(29, 1))
	print("RUTA ", ruta.map(func(p): return "%s@%.1f" % [p[0], p[1]]))
	quit()
