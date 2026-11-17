extends "res://pruebas/comun.gd"
## Paso 3: medidor de detección, visión (sombra, muros, espalda) y ciclo de la alarma.

const NOMBRES := ["OCULTO", "SOSPECHA", "ALARMA"]


## Avanza hasta que el soldado llegue al estado; devuelve el tiempo o -1.
func esperar_estado(m: Mapa, s: Soldado, estado: int, maximo: float) -> float:
	var t := 0.0
	while t < maximo:
		if s.estado == estado:
			return t
		paso(m)
		t += DT
	return -1.0


func preparar() -> Mapa:
	var m: Mapa = await nuevo_mapa()
	var s: Soldado = m.get_node("S1")
	s.pos = Vector2(3.5, 5.5)
	s.mirada = Vector2(1, 0)
	return m


func _initialize():
	await process_frame
	print("A) Mika a 2 casillas, delante de S1")
	var m: Mapa = await preparar()
	var s: Soldado = m.get_node("S1")
	m.mika.pos = Vector2(5.5, 5.5)
	comprobar("tiempo hasta Sospecha", esperar_estado(m, s, 1, 3), 0.15, 0.04)
	comprobar("tiempo hasta Alarma (total)", 0.15 + esperar_estado(m, s, 2, 3), 0.30, 0.04)
	comprobar("alerta activa", m.alerta.activa, true)
	m.queue_free()

	print("B) Mika a 3,3 casillas, lejos dentro del cono")
	m = await preparar()
	s = m.get_node("S1")
	m.mika.pos = Vector2(6.8, 5.5)
	comprobar("tiempo hasta Sospecha", esperar_estado(m, s, 1, 3), 0.60, 0.04)
	comprobar("se quedó quieto mirando (el último fotograma ya va a investigar)", s.pos.distance_to(Vector2(3.5, 5.5)) <= 2.8 * DT + 0.001, true)

	print("C) Visión: sombra, muros y espalda")
	s.estado = Soldado.Estado.OCULTO
	s.pos = Vector2(3.5, 8.5); s.mirada = Vector2(-1, 0)
	m.mika.pos = Vector2(0.5, 8.5)
	comprobar("en sombra a 3 casillas", s._ve_a_mika(), false)
	m.mika.pos = Vector2(1.5, 8.5)
	comprobar("en suelo a 2 casillas", s._ve_a_mika(), true)
	s.pos = Vector2(2.5, 8.5); m.mika.pos = Vector2(0.5, 8.5)
	comprobar("en sombra a 2 casillas", s._ve_a_mika(), true)
	s.pos = Vector2(3.5, 5.5); s.mirada = Vector2(0, -1); m.mika.pos = Vector2(3.5, 3.2)
	comprobar("tras el muro (3,4)", s._ve_a_mika(), false)
	s.mirada = Vector2(1, 0); m.mika.pos = Vector2(2.5, 5.5)
	comprobar("a su espalda", s._ve_a_mika(), false)
	m.mika.pos = Vector2(5.5, 7.2)
	comprobar("a 60° del frente", s._ve_a_mika(), false)
	m.mika.pos = Vector2(6.5, 5.9)
	comprobar("a 8° del frente", s._ve_a_mika(), true)
	m.queue_free()

	print("D) Ciclo de alarma")
	m = await preparar()
	s = m.get_node("S1")
	m.mika.pos = Vector2(5.5, 5.5)
	m.mika.vida = 1000 # que los golpes no la tumben durante la prueba
	esperar_estado(m, s, 2, 3)
	paso(m, 3.0) # Mika se deja ver 3 s
	comprobar("en alarma se detuvo cerca de Mika", s.pos.distance_to(m.mika.pos) <= Config.SOLDADO_DISTANCIA_GOLPE + 0.01, true)
	m.mika.pos = Vector2(0.5, 0.5) # se esconde lejos
	m.mika.sed = 0
	var antes := {}
	var t := 0.0
	while t < 40.0:
		paso(m)
		t += DT
		m.mika.sed = 0 # sin Frenesí durante la prueba
		for h in m.soldados():
			if antes.get(h.name, -1) != h.estado:
				antes[h.name] = h.estado
				print("    t=%5.2f %s -> %s en %s" % [t, h.name, NOMBRES[h.estado], h.pos.snapped(Vector2(0.01, 0.01))])
	comprobar("refuerzos llamados", m.alerta.refuerzos, 1)
	comprobar("alerta apagada", m.alerta.activa, false)
	comprobar("S1 vuelve a estar Oculto", s.estado, Soldado.Estado.OCULTO)
	comprobar("S1 volvió a su ruta", s._volviendo, false)
	var r: Soldado = m.get_node("Refuerzo1")
	comprobar("refuerzo de vuelta en su puesto", r.pos, Vector2(9.5, 0.5), 0.06)
	terminar()
