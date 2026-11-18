extends "res://pruebas/comun.gd"
## «Dentro de la muralla», primera infiltración de la zona 3: barracones del ejército, un
## portador de arma maldita, un hechicero con sus talismanes y un grupo en el patio.

const ESCENA := "res://escenas/mapa_shibuya.tscn"


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	comprobar("nombre y tamaño", [m.nombre, m.ancho, m.alto], ["Dentro de la muralla", 30, 18])
	var tipos := m.soldados().map(func(s): return "portador" if s is Portador else ("hechicero" if s is Hechicero else "soldado"))
	comprobar("un portador, un hechicero y cuatro soldados", [tipos.count("portador"), tipos.count("hechicero"), tipos.count("soldado")], [1, 1, 4])
	await process_frame
	comprobar("tres talismanes activos", m.talismanes_activos().size(), 3)
	m.queue_free()
	print("B) Infiltración")
	await probar_infiltracion(ESCENA, Vector2i(0, 16), Vector2i(29, 0))
	terminar()
