extends "res://pruebas/comun.gd"
## Paso 8: Prueba de la sed. Ritmo de la sed, lo que Mika no puede hacer en su mente,
## ecos que siguen y cortan el paso, y los tres finales: superada, cedida y fallida.


func solo_mika(m: Mapa, segundos: float) -> void:
	for i in roundi(segundos / DT):
		m.mika._physics_process(DT)


func apartar_ecos(m: Mapa) -> void:
	for eco in m.ecos():
		eco.pos = Vector2(-50, -50)


func _initialize():
	await process_frame
	print("A) Ritmo de la sed")
	var m: Mapa = await nueva_prueba_de_la_sed()
	var mika := m.mika
	comprobar("es una Prueba de la sed", m.prueba_de_la_sed, true)
	comprobar("cinco ecos", m.ecos().size(), 5)
	comprobar("Yuu en la salida", m.celda_salida, Vector2i(11, 0))
	apartar_ecos(m)
	var sed_antes := mika.sed
	solo_mika(m, 15.0 + DT)
	comprobar("sin ecos: +1 cada PRUEBA_SED_INTERVALO s", mika.sed, sed_antes + floori(15.0 / Config.PRUEBA_SED_INTERVALO))
	m.ecos()[0].pos = mika.pos + Vector2(1.0, 0)
	m.ecos()[1].pos = mika.pos + Vector2(0, 1.2)
	comprobar("ecos cerca", mika.ecos_cerca(), 2)
	sed_antes = mika.sed
	solo_mika(m, 15.0 + DT)
	comprobar("con 2 ecos cerca: +3 cada PRUEBA_SED_INTERVALO s", mika.sed, mini(Config.SED_MAX, sed_antes + 3 * floori(15.0 / Config.PRUEBA_SED_INTERVALO)))
	m.queue_free()

	print("B) Lo que no puede hacer en su mente")
	m = await nueva_prueba_de_la_sed(); mika = m.mika
	apartar_ecos(m)
	mika.viales = 1
	Input.action_press("tajo"); Input.action_press("vial")
	solo_mika(m, DT)
	Input.action_release("tajo"); Input.action_release("vial")
	comprobar("no hay Tajo", mika._enfriamiento_tajo <= 0.0, true)
	comprobar("no toma viales", mika.progreso_bebida(), -1.0)
	mika.sed = 95
	solo_mika(m, 1.0)
	comprobar("con sed 95 no hay Frenesí", mika.en_frenesi(), false)

	print("C) Fallida")
	mika.sed = 99
	solo_mika(m, 2.0)
	comprobar("termina al llegar a 100", m.terminado, true)
	comprobar("como fallida", m.motivo, "fallida")
	comprobar("despierta con sed 90", mika.sed, 90)
	paused = false
	m.queue_free()

	print("D) Cedida")
	m = await nueva_prueba_de_la_sed(); mika = m.mika
	apartar_ecos(m)
	var eco: Eco = m.ecos()[0]
	eco.pos = mika.pos + Vector2(0.8, 0)
	mika.sed = 60
	Input.action_press("beber")
	solo_mika(m, 2.05)
	Input.action_release("beber")
	comprobar("bebió del eco", eco.bebido, true)
	comprobar("sed a 0", mika.sed, 0)
	comprobar("Humanidad −1", mika.humanidad, 2)
	comprobar("espera a que elija la mejora", m.terminado, false)
	mika.elegir_mejora(Mejoras.VIGOR)
	await process_frame
	comprobar("cedida tras elegir", m.terminado and m.motivo == "cedida", true)
	paused = false
	m.queue_free()

	print("E) Ecos")
	m = await nueva_prueba_de_la_sed(); mika = m.mika
	apartar_ecos(m)
	eco = m.ecos()[0]
	eco.pos = Vector2(5.5, 4.5)
	mika.pos = Vector2(3.5, 4.5)
	mika.mover(Vector2(3.0, 0))
	comprobar("no lo atraviesa", mika.pos.x <= 5.5 - Config.RADIO_MIKA - Config.PRUEBA_ECO_RADIO + 0.001, true)
	eco.pos = Vector2(7.5, 4.5) # fila 4, libre de (3,4) a (7,4)
	mika.pos = Vector2(3.5, 4.5)
	for i in 60: eco._physics_process(DT)
	comprobar("lo sigue a PRUEBA_ECO_VELOCIDAD casillas/s", eco.pos.distance_to(Vector2(7.5 - Config.PRUEBA_ECO_VELOCIDAD, 4.5)), 0.0, 0.05)
	m.queue_free()

	print("F) Superada por un jugador automático")
	m = await nueva_prueba_de_la_sed(); mika = m.mika
	var t := 0.0
	while not m.terminado and t < 60.0:
		_jugar(m)
		paso(m)
		t += DT
	comprobar("llega hasta Yuu", m.terminado and m.motivo == "" and m.estadisticas.sangre_bebida == 0, true)
	comprobar("sin perder Humanidad", mika.humanidad, 3)
	print("    tardó %.1f s y llegó con sed %d" % [t, mika.sed])
	paused = false
	m.queue_free()
	terminar()


## Camina hacia Yuu por el camino más corto que no pase por casillas ocupadas por ecos.
func _jugar(m: Mapa) -> void:
	var mika := m.mika
	var ocupadas := []
	for eco in m.ecos():
		var c := Vector2i(floori(eco.pos.x), floori(eco.pos.y))
		if c != mika.celda() and not m._rejilla.is_point_solid(c):
			m._rejilla.set_point_solid(c, true)
			ocupadas.append(c)
	var camino := m.camino(mika.pos, Vector2(m.celda_salida) + Vector2(0.5, 0.5))
	for c in ocupadas:
		m._rejilla.set_point_solid(c, false)
	if camino.is_empty():
		return
	var hacia := camino[0] - mika.pos
	if hacia.length() > 0.001:
		mika.mover(hacia.normalized() * minf(mika.velocidad() * DT, hacia.length()))
