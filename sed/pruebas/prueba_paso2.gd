extends SceneTree
## Paso 2: ruta de patrulla de S1 y rayos de visión contra los muros.

func _initialize():
	Soldado.patrullas_al_azar = false # la prueba coloca a S1 en el primer punto de su ruta
	var mapa: Mapa = load("res://escenas/mapa_pasos.tscn").instantiate()
	root.add_child(mapa)
	await process_frame
	mapa.process_mode = Node.PROCESS_MODE_DISABLED
	var ok := true
	var s: Soldado = mapa.get_node("S1")
	s.pos = Vector2(3.5, 5.5)
	mapa.mika.pos = Vector2(0.5, 0.5) # lejos, que no lo vea
	var visitados := []
	var t := 0.0
	var dt := 1.0 / 60.0
	var anterior := s.pos
	while t < 16.0:
		s._physics_process(dt)
		t += dt
		if mapa.es_muro(Vector2i(floori(s.pos.x), floori(s.pos.y))): ok = false; print("FALLO: dentro de muro ", s.pos)
		if s.pos == anterior and (visitados.is_empty() or visitados[-1] != s.pos):
			visitados.append(s.pos)
		anterior = s.pos
	print("puntos donde se detuvo: ", visitados)
	var esperado := [Vector2(6.5,5.5), Vector2(6.5,8.5), Vector2(3.5,8.5), Vector2(3.5,5.5)]
	for i in 4:
		if visitados[i] != esperado[i]: ok = false; print("FALLO orden ruta")
	var d := mapa.distancia_hasta_muro(Vector2(3.5,5.5), Vector2(1,0), 5.0)
	print("desde (3.5,5.5) hacia +x: ", d, " (3.5)")
	if absf(d - 3.5) > 0.001: ok = false
	d = mapa.distancia_hasta_muro(Vector2(3.5,5.5), Vector2(0,-1), 5.0)
	print("desde (3.5,5.5) hacia -y: ", d, " (0.5)")
	if absf(d - 0.5) > 0.001: ok = false
	d = mapa.distancia_hasta_muro(Vector2(9.5,8.5), Vector2(0,-1), 5.0)
	print("por la columna 9: ", d, " (5)")
	if absf(d - 5.0) > 0.001: ok = false
	if not mapa.hay_linea_de_vision(Vector2(0.5,5.5), Vector2(6.5,5.5)): ok = false; print("FALLO línea libre")
	if mapa.hay_linea_de_vision(Vector2(3.5,2.5), Vector2(3.5,5.5)): ok = false; print("FALLO línea tapada")
	if s.cono._lejos.size() != Config.VISION_RAYOS + 1: ok = false; print("FALLO puntos del cono")
	print("RESULTADO: ", "OK" if ok else "FALLO")
	quit()
