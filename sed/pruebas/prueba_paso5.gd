extends SceneTree
const DT := 1.0 / 60.0
var ok := true
var ofrecidas := []
var derrotas := 0

func nuevo_mapa() -> Mapa:
	var mapa: Mapa = load("res://escenas/mapa_pasos.tscn").instantiate()
	for nombre in ["S2", "S3", "S4"]: # las pruebas de este paso usan solo a S1
		mapa.get_node(nombre).free()
	root.add_child(mapa)
	mapa.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var hud := mapa.get_node("HUD")
	hud.process_mode = Node.PROCESS_MODE_DISABLED # sin pausas ni recargas durante la prueba
	mapa.mika.mejora_pendiente.disconnect(hud._mostrar_eleccion)
	mapa.mika.mejora_pendiente.connect(func(o): ofrecidas = o)
	mapa.mika.derrotada.connect(func(): derrotas += 1)
	mapa.mika.rng.seed = 7
	mapa.efectos.permitir_paradas = false
	return mapa

func paso(m: Mapa, segundos: float) -> void:
	var n := roundi(segundos / DT)
	for i in n:
		m.alerta._physics_process(DT)
		m.mika._physics_process(DT)
		for s in m.soldados(): s._physics_process(DT)
		for h in m.get_children():
			if h is Vial: h._physics_process(DT)

func comprobar(nombre: String, valor, esperado) -> void:
	var bien: bool = (absf(valor - esperado) < 0.01) if valor is float else valor == esperado
	if not bien: ok = false
	print(("  ok  " if bien else "FALLO "), nombre, ": ", valor, " (esperado ", esperado, ")")

func cerrar(m: Mapa) -> void:
	Input.action_release("beber")
	m.queue_free()
	await process_frame

func _initialize():
	await process_frame
	print("A) Sed, regeneración y velocidad")
	var m: Mapa = await nuevo_mapa()
	var mika := m.mika
	m.get_node("S1").derribar(); m.get_node("S1").bebido = true # que no moleste
	comprobar("sed inicial", mika.sed, 30)
	paso(m, 9.0 + DT)
	comprobar("sed tras 9 s", mika.sed, 33)
	mika.sed = 20; mika.vida = 10; mika._acumulado_sed = 0.0
	paso(m, 6.0 + DT)
	comprobar("saciado: regenera 1 en 6 s", mika.vida, 11)
	mika.sed = 40; mika.vida = 10
	paso(m, 6.0)
	comprobar("estable: no regenera", mika.vida, 10)
	mika.sed = 59
	comprobar("velocidad con 59", mika.velocidad(), 5.5)
	mika.sed = 60
	comprobar("velocidad con 60", mika.velocidad(), 3.5)
	mika.sed = 30
	mika.impulso(Vector2.RIGHT)
	comprobar("Impulso sube la sed 8", mika.sed, 38)
	await cerrar(m)

	print("B) Golpes de soldado y caída")
	m = await nuevo_mapa(); mika = m.mika
	var s: Soldado = m.get_node("S1")
	mika.pos = Vector2(4.5, 5.5)
	s.pos = Vector2(3.7, 5.5); s.mirada = Vector2(1, 0)
	m.alerta.dar_alarma(mika.pos)
	paso(m, DT)
	comprobar("primer golpe: vida", mika.vida, 10)
	comprobar("primer golpe: sed +3", mika.sed, 33)
	paso(m, 0.5)
	comprobar("medio segundo después, sin otro golpe", mika.vida, 10)
	paso(m, 0.55)
	comprobar("al segundo, otro golpe", mika.vida, 8)
	paso(m, 4.0)
	comprobar("cae con vida 0", mika.caida and mika.vida == 0, true)
	comprobar("señal de derrota una vez", derrotas, 1)
	await cerrar(m)

	print("C) Vial de Krul")
	m = await nuevo_mapa(); mika = m.mika
	m.get_node("S1").derribar(); m.get_node("S1").bebido = true
	comprobar("hay un vial en el mapa", m.celdas_vial, [Vector2i(8, 5)])
	mika.pos = Vector2(8.5, 5.5)
	paso(m, DT)
	comprobar("lo recoge al pisarlo", mika.viales, 1)
	await process_frame
	var quedan := 0
	for h in m.get_children(): if h is Vial and not h.is_queued_for_deletion(): quedan += 1
	comprobar("desaparece del suelo", quedan, 0)
	mika.sed = 70
	comprobar("empieza a beberlo", mika.tomar_vial(), true)
	paso(m, 0.25)
	comprobar("a mitad aún no hace efecto", mika.sed, 70)
	paso(m, 0.26)
	comprobar("a los 0,5 s: sed −40", mika.sed, 30)
	comprobar("gastó el vial", mika.viales, 0)
	comprobar("sin viales no puede", mika.tomar_vial(), false)
	await cerrar(m)

	print("D) Beber sangre")
	m = await nuevo_mapa(); mika = m.mika
	s = m.get_node("S1")
	s.pos = Vector2(3.5, 5.5); s.derribar()
	mika.pos = Vector2(4.3, 5.5); mika.sed = 55; mika.vida = 5
	paso(m, DT)
	comprobar("cuerpo al alcance", mika.objetivo_beber, s)
	Input.action_press("beber")
	paso(m, 1.0)
	Input.action_release("beber")
	paso(m, DT)
	comprobar("soltar a mitad cancela", mika.esta_bebiendo() or s.bebido, false)
	Input.action_press("beber")
	paso(m, 2.05)
	Input.action_release("beber")
	comprobar("sed a 0", mika.sed, 0)
	comprobar("vida completa", mika.vida, 12)
	comprobar("Humanidad −1", mika.humanidad, 2)
	comprobar("cuerpo bebido", s.bebido, true)
	comprobar("ofrece 2 mejoras distintas", ofrecidas.size() == 2 and ofrecidas[0] != ofrecidas[1], true)
	paso(m, DT)
	comprobar("no se bebe dos veces", mika.objetivo_beber, null)

	print("E) Mejoras")
	mika.elegir_mejora(Mejoras.VIGOR)
	comprobar("Vigor: vida máxima", mika.vida_max, 16)
	comprobar("Vigor: vida", mika.vida, 16)
	mika.elegir_mejora(Mejoras.FUERZA)
	comprobar("Fuerza: daño del Tajo", mika.dano_tajo(), 6)
	mika.elegir_mejora(Mejoras.VELOCIDAD)
	comprobar("Velocidad", mika.velocidad(), 6.5)
	mika.elegir_mejora(Mejoras.REGENERACION)
	mika.sed = 50; mika.vida = 10; mika._acumulado_regeneracion = 0.0
	paso(m, 6.0 + DT)
	comprobar("Regeneración con sed 50", mika.vida, 11)
	var otro: Soldado = load("res://escenas/soldado.tscn").instantiate()
	otro.ruta.assign([Vector2i(9, 3)]); m.add_child(otro); otro.iniciar(m)
	paso(m, DT)
	comprobar("sin Olfato no hay silueta", otro.silueta.visible, false)
	mika.elegir_mejora(Mejoras.OLFATO)
	paso(m, DT)
	comprobar("con Olfato hay silueta", otro.silueta.visible, true)
	mika.mejoras.clear(); mika._ofrecer_mejora()
	var todas := {}
	for i in 40:
		mika._ofrecer_mejora()
		for o in ofrecidas: todas[o] = true
	comprobar("el azar ofrece las 5", todas.size(), 5)
	mika.mejoras.assign(Mejoras.TODAS.slice(0, 4)); ofrecidas = []
	mika._ofrecer_mejora()
	comprobar("con una sola restante, ofrece esa", ofrecidas, [Mejoras.REGENERACION])
	await cerrar(m)

	print("F) Frenesí con un soldado cerca")
	m = await nuevo_mapa(); mika = m.mika
	s = m.get_node("S1")
	s.ruta.assign([Vector2i(3, 8)]); s.pos = Vector2(3.5, 8.5); s.mirada = Vector2(1, 0) # de espaldas a Mika
	mika.pos = Vector2(0.5, 8.5); mika.sed = 90
	var sin_control := 0.0
	var t := 0.0
	while t < 8.0 and not s.bebido:
		paso(m, DT); t += DT
		if mika.sin_control(): sin_control += DT
	comprobar("lo derriba y bebe", s.derribado and s.bebido, true)
	comprobar("sin control todo el tiempo", absf(sin_control - t) < 0.05, true)
	comprobar("Humanidad −1", mika.humanidad, 2)
	comprobar("sed a 0", mika.sed, 0)
	print("    tardó %.2f s (2 de beber)" % t)
	await cerrar(m)

	print("G) Frenesí sin nadie de quien beber")
	m = await nuevo_mapa(); mika = m.mika
	m.get_node("S1").derribar(); m.get_node("S1").bebido = true
	mika.sed = 95
	paso(m, DT)
	comprobar("entra en Frenesí", mika.en_frenesi(), true)
	paso(m, 4.0)
	comprobar("a los 4 s recupera el control", mika.sin_control(), false)
	paso(m, 2.9)
	comprobar("respiro de 3 s", mika.en_frenesi(), false)
	paso(m, 0.2)
	comprobar("luego vuelve el Frenesí", mika.en_frenesi(), true)
	await cerrar(m)

	print("H) Panel de elección")
	m = await nuevo_mapa(); mika = m.mika
	var hud: Hud = m.get_node("HUD")
	hud._mostrar_eleccion([Mejoras.VIGOR, Mejoras.FUERZA] as Array[String])
	comprobar("pausa el juego", paused, true)
	var boton: Button = hud._eleccion.find_children("*", "Button", true, false)[0]
	comprobar("el primer botón tiene el foco", boton.has_focus(), true)
	boton.pressed.emit()
	comprobar("aplica la mejora", mika.mejoras, [Mejoras.VIGOR])
	comprobar("quita la pausa", paused, false)
	await cerrar(m)
	print("RESULTADO: ", "OK" if ok else "FALLO")
	quit()
