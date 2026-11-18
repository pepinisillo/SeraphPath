extends "res://pruebas/comun.gd"
## «Ruinas de Shinjuku», primera infiltración de la zona 2: calles entre edificios, soldados, un
## vampiro, un Jinete en la plaza y un grupo junto a la salida.

const ESCENA := "res://escenas/mapa_shinjuku.tscn"


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	comprobar("nombre y tamaño", [m.nombre, m.ancho, m.alto], ["Ruinas de Shinjuku", 32, 20])
	comprobar("bandos: 4 soldados, un vampiro, un Jinete y un grupo", [m.soldados().size(), m.vampiros().size(), m.jinetes().size(), m.apariciones().size()], [4, 1, 1, 1])
	m.queue_free()
	print("B) Infiltración")
	await probar_infiltracion(ESCENA, Vector2i(0, 18), Vector2i(31, 1))
	terminar()
