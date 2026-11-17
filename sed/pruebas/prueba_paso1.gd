extends SceneTree
## Paso 1: conversión isométrica, diagonales del teclado y choque con muros.

func _initialize():
	var mapa: Mapa = load("res://escenas/mapa_puesto_control.tscn").instantiate()
	root.add_child(mapa)
	await process_frame
	mapa.process_mode = Node.PROCESS_MODE_DISABLED
	var ok := true
	for c in [Vector2i(0,0), Vector2i(3,7), Vector2i(9,9)]:
		var a := Iso.a_pantalla(Vector2(c) + Vector2(0.5,0.5))
		var b := mapa.muros.map_to_local(c)
		if not a.is_equal_approx(b): ok = false; print("FALLO conversión ", c, a, b)
		if not Iso.a_casilla(a).is_equal_approx(Vector2(c) + Vector2(0.5,0.5)): ok = false; print("FALLO inversa ", c)
	print("tamaño ", mapa.ancho, "x", mapa.alto, " inicio ", mapa.inicio_mika)
	for e in [Vector2.RIGHT, Vector2.UP, Vector2(1,-1).normalized()]:
		var d := Iso.direccion_desde_pantalla(e)
		print("tecla ", e, " -> casilla ", d.snapped(Vector2(0.01,0.01)), " -> pantalla ", (Iso.a_pantalla(d) - Iso.a_pantalla(Vector2.ZERO)).normalized().snapped(Vector2(0.01,0.01)))
	var mika: Mika = mapa.get_node("Mika")
	mika.pos = Vector2(1.5, 9.5)
	for i in 120: mika.mover(Vector2(0.1, 0))
	print("contra muro (2,9): x = ", mika.pos.x, " (esperado 1.7)")
	if absf(mika.pos.x - 1.7) > 0.001: ok = false
	mika.pos = Vector2(0.5, 9.5)
	mika.mover(Vector2(-5, 0))
	print("borde izquierdo: x = ", mika.pos.x, " (esperado 0.3)")
	if absf(mika.pos.x - 0.3) > 0.001: ok = false
	mika.pos = Vector2(0.5, 5.5)
	mika.mover(Vector2(0, -4))
	print("dash contra muro (0,4): ", mika.pos, " (y esperado 5.3)")
	if absf(mika.pos.y - 5.3) > 0.001: ok = false
	print("RESULTADO: ", "OK" if ok else "FALLO")
	quit()
