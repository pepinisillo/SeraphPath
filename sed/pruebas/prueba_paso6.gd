extends "res://pruebas/comun.gd"
## Paso 6: salida del mapa, estadísticas y pantalla de resultado (al salir y al caer).


func resultado(m: Mapa) -> Resultado:
	for h in m.get_children():
		if h is Resultado:
			return h
	return null


func _initialize():
	await process_frame
	print("A) Llegar a la salida")
	var m: Mapa = await nuevo_mapa()
	var mika := m.mika
	var s: Soldado = m.get_node("S1")
	s.pos = Vector2(3.5, 5.5); s.mirada = Vector2(1, 0)
	mika.pos = Vector2(2.6, 5.5); mika.mirada = Vector2(1, 0)
	paso(m)
	mika.golpe_silencioso()
	var b := soldado_extra(m, "B", Vector2i(9, 3), Vector2(1, 0)) # de espaldas a Mika
	mika.pos = Vector2(8.6, 3.5); mika.mirada = Vector2(1, 0)
	mika.tajo()
	var c := soldado_extra(m, "C", Vector2i(4, 5), Vector2(-1, 0)) # mira hacia el cuerpo de S1
	paso(m)
	m.alerta.dar_alarma(mika.pos)
	m.alerta.activa = false
	m.alerta.dar_alarma(mika.pos) # dos alarmas distintas
	mika.pos = Vector2(8.5, 5.5) # recoge el vial
	paso(m)
	mika.pos = Vector2(9.5, 2.5)
	paso(m, 1.0)
	comprobar("aún no ha terminado", m.terminado, false)
	mika.pos = Vector2(9.5, 0.6) # en la salida
	paso(m)
	comprobar("termina al pisar la salida", m.terminado, true)
	comprobar("pausa el juego", paused, true)
	var r := resultado(m)
	comprobar("muestra el resultado", r != null, true)
	comprobar("como superado", r.exito, true)
	var e := m.estadisticas
	comprobar("tiempo", e.tiempo, 1.0 + 4 * DT, 0.02)
	comprobar("derribados en silencio", e.derribados_en_silencio, 1)
	comprobar("derribados con el Tajo", e.derribados_con_tajo, 1)
	comprobar("cuerpos descubiertos", e.cuerpos_descubiertos, 1)
	comprobar("alarmas", e.alarmas, 2)
	comprobar("viales recogidos", e.viales_recogidos, 1)
	comprobar("objetivo opcional cumplido", m.objetivo_cumplido(), true)
	comprobar("botón principal", r.boton_repetir.text, "Jugar de nuevo")
	comprobar("con el foco", r.boton_repetir.has_focus(), true)
	comprobar("sin menciones de sigilo (hubo alarma)", r._logros(e), PackedStringArray(["Sin beber sangre humana"]))
	var textos := []
	for l in r.find_children("*", "Label", true, false): textos.append(l.text)
	comprobar("título", "Puesto de control superado" in textos, true)
	comprobar("línea del objetivo", "Objetivo opcional: Recoger el vial de Krul · conseguido" in textos, true)
	paused = false
	m.queue_free()

	print("B) Caer")
	m = await nuevo_mapa()
	m.mika.recibir_golpe(100)
	comprobar("aún no hay resultado al caer", resultado(m), null)
	await create_timer(Config.RESULTADO_ESPERA_CAIDA + 0.2, true).timeout
	r = resultado(m)
	comprobar("resultado tras la espera", r != null, true)
	comprobar("como caída", r.exito, false)
	comprobar("botón principal", r.boton_repetir.text, "Volver a intentarlo")
	comprobar("objetivo no conseguido", m.objetivo_cumplido(), false)
	paused = false
	m.queue_free()

	print("C) Menciones")
	var limpia := Estadisticas.new()
	r = Resultado.new()
	comprobar("sin alarma ni cuerpos", r._logros(limpia), PackedStringArray(["Sin dejar rastro", "Sin beber sangre humana"]))
	limpia.cuerpos_descubiertos = 1; limpia.sangre_bebida = 1
	comprobar("con un cuerpo descubierto y sangre", r._logros(limpia), PackedStringArray(["Nadie dio la alarma"]))
	r.free()
	terminar()
