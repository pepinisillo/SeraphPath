extends "res://pruebas/comun.gd"
## Controles táctiles: el joystick pulsa las acciones de moverse con su fuerza y los botones
## pulsan su acción mientras se tocan (Beber se mantiene). Sin pantalla táctil no aparecen.


func toque(ct: ControlesTactiles, dedo: int, punto: Vector2, pulsado: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = dedo
	ev.position = punto
	ev.pressed = pulsado
	ct._input(ev)


func arrastre(ct: ControlesTactiles, dedo: int, punto: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = dedo
	ev.position = punto
	ct._input(ev)


func _initialize():
	await process_frame
	var m: Mapa = await nuevo_mapa()
	comprobar("sin pantalla táctil no aparecen", m.get_node_or_null("ControlesTactiles") == null or DisplayServer.is_touchscreen_available(), true)
	m.queue_free()
	ControlesTactiles.forzar = true
	m = await nuevo_mapa()
	var ct: ControlesTactiles = m.get_node("ControlesTactiles")
	comprobar("con pantalla táctil, aparecen", ct != null, true)
	var tam := ct.lienzo.size
	print("A) Joystick")
	var centro := Vector2(150, tam.y - 150)
	toque(ct, 0, centro, true)
	arrastre(ct, 0, centro + Vector2(ControlesTactiles.RADIO_JOYSTICK, 0))
	comprobar("a la derecha: mover_derecha a fondo", [Input.is_action_pressed("mover_derecha"), snappedf(Input.get_action_strength("mover_derecha"), 0.01)], [true, 1.0])
	arrastre(ct, 0, centro + Vector2(0, -ControlesTactiles.RADIO_JOYSTICK * 0.5))
	comprobar("arriba a medias: mover_arriba a la mitad, y suelta la derecha", [snappedf(Input.get_action_strength("mover_arriba"), 0.01), Input.is_action_pressed("mover_derecha")], [0.5, false])
	toque(ct, 0, centro, false)
	comprobar("al soltar, nada", Input.is_action_pressed("mover_arriba"), false)
	print("B) Botones")
	var beber := ct.posicion_boton(Vector2(-3.4, -3.4), tam)
	toque(ct, 1, beber, true)
	comprobar("Beber se mantiene mientras se toca", Input.is_action_pressed("beber"), true)
	var tajo := ct.posicion_boton(Vector2(-1.2, -1.2), tam)
	toque(ct, 2, tajo, true)
	comprobar("con otro dedo, a la vez, el Tajo", [Input.is_action_pressed("tajo"), Input.is_action_pressed("beber")], [true, true])
	toque(ct, 1, beber, false)
	toque(ct, 2, tajo, false)
	comprobar("al soltar, se sueltan", [Input.is_action_pressed("tajo"), Input.is_action_pressed("beber")], [false, false])
	ControlesTactiles.forzar = false
	m.queue_free()
	terminar()
