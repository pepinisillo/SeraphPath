extends "res://pruebas/comun.gd"
func _initialize():
	await process_frame
	var m: Mapa = await cargar_mapa("res://escenas/mapa_estacion.tscn")
	paso(m, 30.0)
	print("CAZADOS ", m.estadisticas.cazados_por_jinetes)
	quit()
