extends "res://pruebas/comun.gd"
## «La estación hundida», infiltración de la ruta arriesgada de la zona 2: dos andenes, las vías
## en penumbra con trenes descarrilados y un Jinete vagando por ellas.

const ESCENA := "res://escenas/mapa_estacion.tscn"


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	comprobar("nombre y tamaño", [m.nombre, m.ancho, m.alto], ["La estación hundida", 30, 14])
	comprobar("bandos: 5 soldados, un vampiro, un Jinete y un grupo", [m.soldados().size(), m.vampiros().size(), m.jinetes().size(), m.apariciones().size()], [5, 1, 1, 1])
	m.queue_free()
	print("B) Infiltración")
	await probar_infiltracion(ESCENA, Vector2i(0, 12), Vector2i(29, 1))
	terminar()
