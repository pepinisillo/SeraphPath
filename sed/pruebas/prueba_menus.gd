extends "res://pruebas/comun.gd"
## Opciones (volumen y pantalla completa, guardadas), galería de finales y los avisos de
## controles de la primera partida.


func _initialize():
	await process_frame
	print("A) Opciones")
	Opciones.archivo = "user://prueba_opciones.cfg"
	Opciones.volumen = 80
	Opciones.cambiar_volumen(-30)
	comprobar("baja el volumen", [Opciones.volumen, AudioServer.get_bus_volume_db(0) < 0.0], [50, true])
	Opciones.cambiar_volumen(-100)
	comprobar("a 0, silencio", [Opciones.volumen, AudioServer.is_bus_mute(0)], [0, true])
	Opciones.cambiar_volumen(70)
	Opciones.cambiar_pantalla_completa()
	Opciones.volumen = 10
	Opciones.pantalla_completa = false
	Opciones.cargar()
	comprobar("se guardan y se recuperan", [Opciones.volumen, Opciones.pantalla_completa], [70, true])
	Opciones.cambiar_pantalla_completa()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Opciones.archivo))
	Opciones.archivo = Opciones.ARCHIVO

	print("A2) Teclas")
	Opciones.archivo = "user://prueba_opciones.cfg"
	comprobar("Tajo es J, Golpe silencioso es K", [Opciones.tecla("tajo"), Opciones.tecla("golpe_silencioso")], [KEY_J, KEY_K])
	Opciones.cambiar_tecla("tajo", KEY_U)
	comprobar("Tajo pasa a U", [Opciones.tecla("tajo"), Opciones.nombre_tecla("tajo")], [KEY_U, "U"])
	var u := InputEventKey.new()
	u.physical_keycode = KEY_U
	u.pressed = true
	comprobar("y la U dispara el Tajo", InputMap.event_is_action(u, "tajo"), true)
	comprobar("el clic izquierdo y el mando siguen en el Tajo", InputMap.action_get_events("tajo").size(), 3)
	Opciones.cambiar_tecla("tajo", KEY_K)
	comprobar("si la usaba otra acción, se intercambian", [Opciones.tecla("tajo"), Opciones.tecla("golpe_silencioso")], [KEY_K, KEY_U])
	InputMap.load_from_project_settings()
	Opciones.cargar()
	comprobar("se guardan y se recuperan", [Opciones.tecla("tajo"), Opciones.tecla("golpe_silencioso")], [KEY_K, KEY_U])
	comprobar("la pausa enseña la tecla puesta", MenuPausa.teclas_de(MenuPausa.CONTROLES[1]), "K o clic izquierdo")
	Opciones.restaurar_teclas()
	comprobar("volver a las de siempre", [Opciones.tecla("tajo"), Opciones.tecla("golpe_silencioso")], [KEY_J, KEY_K])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Opciones.archivo))
	Opciones.archivo = Opciones.ARCHIVO

	print("B) Título, galería y opciones")
	var e := EstadoExpedicion.actual()
	e.recuerdos = []
	e.caidas = 0
	e.finales_vistos.assign(["En el límite"])
	change_scene_to_file("res://escenas/titulo.tscn")
	for i in 3:
		await process_frame
	var textos := current_scene.find_children("*", "Button", true, false).map(func(b): return b.text)
	comprobar("el título ofrece finales y opciones", [textos.has("Finales (1/3)"), textos.has("Opciones")], [true, true])
	change_scene_to_file("res://escenas/galeria_finales.tscn")
	for i in 3:
		await process_frame
	var botones := current_scene.find_children("*", "Button", true, false)
	comprobar("la galería: los no vistos, sin nombre", botones.map(func(b): return b.text).slice(0, 3), ["???", "En el límite", "???"])
	change_scene_to_file("res://escenas/menu_opciones.tscn")
	for i in 3:
		await process_frame
	comprobar("la pantalla de opciones, con una tecla por acción", current_scene.find_children("*", "Button", true, false).size() >= 4 + Opciones.ACCIONES.size(), true)

	print("C) Avisos de controles la primera vez")
	e.finales_vistos.assign([])
	comprobar("sin recuerdos, caídas ni finales: primera vez", e.primera_vez(), true)
	e.caidas = 1
	comprobar("con una caída, ya no", e.primera_vez(), false)
	e.caidas = 0
	terminar()
