extends "res://pruebas/comun.gd"
## «El hueco del río», infiltración de la ruta arriesgada de la zona 3: la orilla, los almacenes
## y la brecha de la muralla, con talismanes en la entrada.

const ESCENA := "res://escenas/mapa_rio.tscn"


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	comprobar("nombre y tamaño", [m.nombre, m.ancho, m.alto], ["El hueco del río", 28, 14])
	comprobar("solo se entra por el hueco de la muralla", [m.es_muro(Vector2i(20, 8)), m.es_muro(Vector2i(20, 9)), m.es_muro(Vector2i(20, 10))], [true, false, false])
	m.queue_free()
	print("B) Infiltración")
	await probar_infiltracion(ESCENA, Vector2i(9, 12), Vector2i(27, 0))
	terminar()
