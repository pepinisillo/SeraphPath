extends "res://pruebas/comun.gd"
## Paso 9: sensación. Parada al golpear, sacudida de cámara, destellos, partículas,
## rastro del dash y la pantalla que pierde color con la sed.


func contar(m: Mapa, clase) -> int:
	var n := 0
	for h in m.get_children():
		if is_instance_of(h, clase) and not h.is_queued_for_deletion():
			n += 1
	return n


func _initialize():
	await process_frame
	print("A) Tajo que conecta")
	var m: Mapa = await nuevo_mapa()
	m.efectos.permitir_paradas = true
	var s: Soldado = m.get_node("S1")
	s.pos = Vector2(3.5, 5.5); s.mirada = Vector2(1, 0)
	m.mika.pos = Vector2(2.6, 5.5); m.mika.mirada = Vector2(1, 0)
	var particulas_antes := contar(m, CPUParticles2D)
	m.mika.tajo()
	comprobar("congela el juego", Engine.time_scale < 0.01, true)
	comprobar("sacude la cámara", m.efectos.trauma, Config.SACUDIDA_TAJO)
	comprobar("salpica sangre", contar(m, CPUParticles2D), particulas_antes + 1)
	comprobar("destello rojo en el soldado", s._destello, Config.DESTELLO_DURACION)
	await create_timer(Config.PARADA_TAJO + 0.05, true, false, true).timeout
	comprobar("tras la parada el tiempo vuelve a la normalidad", Engine.time_scale, 1.0)
	m.efectos._process(1.0)
	comprobar("la sacudida se calma", m.efectos.trauma, 0.0)
	comprobar("y la cámara vuelve a su sitio", m.mika.get_node("Camara").offset, Vector2.ZERO)

	print("B) Paradas que se pisan")
	m.efectos.parada(0.03)
	m.efectos.parada(0.12)
	await create_timer(0.07, true, false, true).timeout
	comprobar("la más larga manda: sigue congelado", Engine.time_scale < 0.01, true)
	await create_timer(0.1, true, false, true).timeout
	comprobar("y luego se reanuda", Engine.time_scale, 1.0)
	m.efectos.parada(1.0)
	m.queue_free()
	await process_frame
	comprobar("salir del mapa nunca deja el juego congelado", Engine.time_scale, 1.0)

	print("C) Golpe recibido")
	m = await nuevo_mapa()
	m.mika.recibir_golpe(2)
	comprobar("destello rojo en Mika", m.mika._destello, Config.DESTELLO_DURACION)
	comprobar("sacude más que un Tajo", m.efectos.trauma > Config.SACUDIDA_TAJO, true)
	m.queue_free()

	print("D) Rastro del dash")
	m = await nuevo_mapa()
	m.get_node("S1").derribar()
	m.mika.pos = Vector2(0.5, 5.5)
	m.mika.impulso(Vector2(1, 1).normalized())
	while m.mika.esta_impulsando():
		paso(m)
	comprobar("deja una silueta cada 0,03 s (6 en 0,15 s)", contar(m, Silueta), 6)
	m.queue_free()

	print("E) La sed se ve")
	comprobar("sed 30: color completo", Efectos.desaturacion(30), 0.0)
	comprobar("sed 60: la mitad del camino", Efectos.desaturacion(60), Config.SED_COLOR_PERDIDO / 2.0)
	comprobar("sed 90: todo lo que se pierde", Efectos.desaturacion(90), Config.SED_COLOR_PERDIDO)
	m = await nuevo_mapa()
	m.get_node("S1").derribar(); m.get_node("S1").bebido = true
	m.mika.sed = 95
	paso(m)
	for i in 30: m.efectos._process(DT)
	var mat := m.efectos.filtro.material as ShaderMaterial
	comprobar("en Frenesí solo queda el rojo", m.efectos.frenesi, 1.0)
	comprobar("el filtro lo recibe", mat.get_shader_parameter("frenesi"), 1.0)
	comprobar("con la sed alta, la pantalla apagada", mat.get_shader_parameter("desaturacion"), Config.SED_COLOR_PERDIDO)
	m.queue_free()
	terminar()
