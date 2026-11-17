extends "res://pruebas/comun.gd"
## Paso 4: Golpe silencioso, Tajo, Impulso, ruido y descubrimiento de cuerpos.


func ondas(m: Mapa) -> int:
	var n := 0
	for h in m.get_children():
		if h is OndaRuido and not h.is_queued_for_deletion():
			n += 1
	return n


func preparar() -> Mapa:
	var m: Mapa = await nuevo_mapa()
	var s: Soldado = m.get_node("S1")
	s.pos = Vector2(3.5, 5.5)
	s.mirada = Vector2(1, 0)
	return m


func _initialize():
	await process_frame
	print("0) Entradas")
	for a in ["tajo", "golpe_silencioso", "impulso", "beber", "vial"]:
		comprobar("eventos de " + a, InputMap.action_get_events(a).size() >= 2, true)

	print("A) Golpe silencioso")
	var m: Mapa = await preparar()
	var s: Soldado = m.get_node("S1")
	m.mika.pos = Vector2(2.6, 5.5); m.mika.mirada = Vector2(1, 0)
	paso(m)
	comprobar("por la espalda: objetivo marcado", m.mika.objetivo_silencioso, s)
	comprobar("derriba", m.mika.golpe_silencioso() and s.derribado, true)
	comprobar("sin ruido", ondas(m), 0)
	comprobar("no hay objetivo sobre un derribado", m.mika._buscar_objetivo_silencioso(), null)
	m.queue_free(); m = await preparar(); s = m.get_node("S1")
	m.mika.pos = Vector2(4.5, 5.5); m.mika.mirada = Vector2(-1, 0)
	comprobar("de frente (lo ve): sin objetivo", m.mika._buscar_objetivo_silencioso(), null)
	comprobar("de frente: no hace nada", m.mika.golpe_silencioso(), false)
	m.mika.pos = Vector2(3.5, 6.4); m.mika.mirada = Vector2(0, -1)
	comprobar("de costado, fuera del cono: objetivo", m.mika._buscar_objetivo_silencioso(), s)
	m.alerta.dar_alarma(Vector2(0.5, 0.5))
	comprobar("con alarma activa: sin objetivo", m.mika._buscar_objetivo_silencioso(), null)

	print("B) Tajo y ruido")
	m.queue_free(); m = await preparar(); s = m.get_node("S1")
	var cerca := soldado_extra(m, "Cerca", Vector2i(0, 5), Vector2(-1, 0))
	var lejos := soldado_extra(m, "Lejos", Vector2i(9, 5), Vector2(1, 0))
	m.mika.pos = Vector2(3.5, 6.5); m.mika.mirada = Vector2(0, 1)
	comprobar("de espaldas no alcanza", m.mika.tajo() and s.derribado, false)
	comprobar("pero hizo ruido", ondas(m), 1)
	comprobar("S1 lo oyó: Sospecha", s.estado, Soldado.Estado.SOSPECHA)
	comprobar("Cerca lo oyó: Sospecha", cerca.estado, Soldado.Estado.SOSPECHA)
	comprobar("Cerca investiga el origen", cerca._punto_investigado, Vector2(3.5, 6.5))
	comprobar("Lejos no lo oyó", lejos.estado, Soldado.Estado.OCULTO)
	comprobar("enfriamiento: no repite al instante", m.mika.tajo(), false)
	paso(m, 25 * DT)
	m.mika.pos = Vector2(3.5, 6.5); m.mika.mirada = Vector2(0, -1); s.pos = Vector2(3.5, 5.5)
	comprobar("tras 0,4 s vuelve a poder, de frente a 1 casilla", m.mika.tajo() and s.derribado, true)
	m.queue_free(); m = await preparar(); s = m.get_node("S1")
	m.mika.pos = Vector2(5.0, 5.5); m.mika.mirada = Vector2(-1, 0)
	comprobar("a 1,5 casillas no alcanza", m.mika.tajo() and s.derribado, false)

	print("C) Impulso")
	m.queue_free(); m = await preparar()
	m.get_node("S1").derribar()
	m.mika.pos = Vector2(0.5, 5.5)
	var abajo_derecha := Vector2(1, 1).normalized() # en pantalla = +x en casillas
	comprobar("arranca", m.mika.impulso(abajo_derecha), true)
	comprobar("hace ruido", ondas(m), 1)
	var t := 0.0
	while m.mika.esta_impulsando():
		paso(m)
		t += DT
	comprobar("recorre 4 casillas", m.mika.pos, Vector2(4.5, 5.5))
	comprobar("en 0,15 s", t, 0.15)
	comprobar("enfriamiento", m.mika.impulso(abajo_derecha), false)
	paso(m, 82 * DT)
	m.mika.pos = Vector2(5.5, 5.5)
	comprobar("tras 1,5 s vuelve a poder", m.mika.impulso(abajo_derecha), true)
	while m.mika.esta_impulsando():
		paso(m)
	comprobar("se detiene contra el muro (7,5)", m.mika.pos, Vector2(6.7, 5.5))

	print("D) Cuerpos")
	m.queue_free(); m = await preparar(); s = m.get_node("S1")
	s.derribar()
	var otro := soldado_extra(m, "Otro", Vector2i(6, 5), Vector2(-1, 0))
	m.mika.pos = Vector2(0.5, 0.5)
	paso(m)
	comprobar("descubre el cuerpo", s.descubierto, true)
	comprobar("va a investigarlo", otro.estado, Soldado.Estado.SOSPECHA)
	comprobar("punto investigado = cuerpo", otro._punto_investigado, s.pos)
	paso(m, 12.0)
	comprobar("tras investigar vuelve a calma (no lo redescubre)", otro.estado, Soldado.Estado.OCULTO)
	terminar()
