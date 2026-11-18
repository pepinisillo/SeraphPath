extends "res://pruebas/comun.gd"
## Jinete del Apocalipsis: ignora a Mika y a los vampiros, acude a los ruidos (desde más lejos
## que un soldado) y caza al soldado que ve, que queda derribado (Mika puede beber de él).
## Y el evento «El Jinete dormido».

const ESCENA := "res://escenas/mapa_shinjuku.tscn"


func _initialize():
	await process_frame
	print("A) Ignora a Mika y a los vampiros")
	var m: Mapa = await cargar_mapa(ESCENA)
	var j: Jinete = m.get_node("J1")
	for s in m.soldados():
		s.free() # sin soldados: solo Mika y el vampiro
	m.mika.pos = j.pos + j.mirada * 1.5
	m.get_node("VS1").pos = j.pos + j.mirada * 2.0
	paso(m, 2.0)
	comprobar("con Mika y un vampiro delante, sigue vagando", [j.estado, j.derribados, m.mika.vida], [Jinete.Estado.VAGA, 0, m.mika.vida_max])
	m.queue_free()

	print("B) Acude al ruido y caza al soldado que ve")
	m = await cargar_mapa(ESCENA)
	j = m.get_node("J1")
	for s in m.soldados():
		s.free() # que solo esté la presa
	m.mika.pos = Vector2(0.5, 17.5)
	m.hacer_ruido(Vector2(21.5, 9.5))
	comprobar("lo oye desde más lejos que un soldado", [j.estado, j.pos.distance_to(Vector2(21.5, 9.5)) > Config.RUIDO_RADIO], [Jinete.Estado.ACUDE, true])
	var presa := soldado_extra(m, "Presa", Vector2i(23, 9), Vector2(1, 0))
	var cazado := false
	for i in roundi(10.0 / DT):
		paso(m)
		m.mika.sed = 0
		if presa.derribado:
			cazado = true
			break
	comprobar("ve al soldado y lo derriba", [cazado, j.derribados, m.estadisticas.cazados_por_jinetes >= 1], [true, j.derribados, true])
	comprobar("sin alarma: solo queda un cuerpo", m.alerta.activa, false)
	m.mika.pos = presa.pos + Vector2(0.4, 0)
	paso(m)
	comprobar("Mika puede beber del soldado cazado", m.mika.objetivo_beber == presa, true)
	m.queue_free()

	print("C) El Jinete dormido: 2 soldados menos y un Jinete suelto")
	var e := EstadoExpedicion.actual()
	e.nueva()
	e.aplicar_efectos(Eventos.por_id("jinete_dormido").opciones[1].efectos)
	comprobar("ya tiene efecto", Eventos.describir(Eventos.por_id("jinete_dormido").opciones[1].efectos).contains("aún sin efecto"), false)
	m = await cargar_mapa(ESCENA)
	await process_frame
	comprobar("el siguiente mapa: 2 soldados menos y un Jinete más", [m.soldados().size(), m.jinetes().size()], [2, 2])
	m.queue_free()
	e.activa = false
	terminar()
