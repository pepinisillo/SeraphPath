extends "res://pruebas/comun.gd"
## Menú de pausa: Esc pausa y reanuda, enseña los controles y, en una expedición, abandonar
## en mitad de una parada cuenta como caída.


func _initialize():
	await process_frame
	var m: Mapa = load("res://escenas/mapa_puesto_control.tscn").instantiate()
	root.add_child(m)
	await process_frame
	var menu: MenuPausa = m.get_node("MenuPausa")
	var pulsar_pausa := func() -> void:
		var ev := InputEventAction.new()
		ev.action = "pausa"
		ev.pressed = true
		menu._unhandled_input(ev)
	pulsar_pausa.call()
	comprobar("Esc pausa el juego", [menu.abierto, paused], [true, true])
	var textos := menu._caja.get_children().filter(func(h): return h is Button).map(func(b): return b.text)
	comprobar("seguir, controles y volver al título (fuera de una expedición)", textos, ["Seguir", "Controles", "Volver al título"])
	menu.abrir(true)
	await process_frame
	var etiquetas := menu._caja.get_children().filter(func(h): return h is Label).size()
	comprobar("los controles", etiquetas, 1 + MenuPausa.CONTROLES.size())
	pulsar_pausa.call()
	comprobar("Esc otra vez reanuda", [menu.abierto, paused], [false, false])
	m.terminado = true
	pulsar_pausa.call()
	comprobar("con el mapa terminado (resultado) no se abre", menu.abierto, false)
	m.queue_free()

	var e := EstadoExpedicion.actual()
	e.nueva()
	e.entrar()
	await process_frame
	await process_frame
	await process_frame
	m = current_scene
	menu = m.get_node("MenuPausa")
	menu.abrir()
	textos = menu._caja.get_children().filter(func(h): return h is Button).map(func(b): return b.text)
	comprobar("en una expedición, abandonar es caer", textos.has("Abandonar la expedición (Mika cae)"), true)
	menu._abandonar()
	await process_frame
	await process_frame
	await process_frame
	comprobar("abandonar: la expedición acaba en caída", [e.activa, str(current_scene.name)], [false, "Final"])
	e.borrar_partida()
	terminar()
