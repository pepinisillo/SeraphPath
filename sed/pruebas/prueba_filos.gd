extends "res://pruebas/comun.gd"
## Filos de la espada, Sentidos y «Espada, bebe mi sangre»: cada filo cambia lo suyo, Sentidos
## revela tras las paredes (no con sed alta), la espada cuesta vida, pega doble y los vampiros
## la huelen. Y cómo se ganan los filos en la expedición.

const PUESTO := "res://escenas/mapa_puesto_control.tscn"


func plantar(s: Soldado, p: Vector2, mirada: Vector2) -> void:
	s.pos = p
	s.mirada = mirada.normalized()
	s.ruta = [Vector2i(p.floor()), Vector2i(p.floor())] as Array[Vector2i]
	s._indice = 0
	s._pausa = 100.0


func _initialize():
	await process_frame
	print("A) Datos")
	var rng := RandomNumberGenerator.new()
	var llevados: Array[String] = [Filos.MUDO, Filos.LARGO]
	var dos := Filos.dos_al_azar(llevados, rng)
	comprobar("dos filos distintos que no lleva", [dos.size(), dos[0] != dos[1], dos[0] in llevados or dos[1] in llevados], [2, true, false])
	comprobar("los diez tienen nombre y efecto", Filos.TODOS.all(func(f): return Filos.nombre(f) != f and Filos.descripcion(f) != ""), true)

	print("B) Sentidos")
	var m: Mapa = await nuevo_mapa()
	var mika := m.mika
	var s1: Soldado = m.get_node("S1")
	comprobar("al principio no se ve tras las paredes", s1.silueta.visible, false)
	comprobar("se activan", mika.usar_sentidos(), true)
	paso(m)
	comprobar("los soldados se ven tras las paredes", s1.silueta.visible, true)
	comprobar("enfriamiento largo", mika.usar_sentidos(), false)
	paso(m, Config.SENTIDOS_DURACION)
	comprobar("pasan", [mika.revelando(), s1.silueta.visible], [false, false])
	mika._enfriamiento_sentidos = 0.0
	mika.sed = mika.tramo_lento
	comprobar("sediento no se pueden usar", mika.usar_sentidos(), false)
	mika.sed = 0
	mika.filos.assign([Filos.CAZADOR])
	mika.usar_sentidos()
	comprobar("Filo del cazador: duran el doble", mika._sentidos_restante, Config.SENTIDOS_DURACION * 2)
	paso(m)
	comprobar("y los conos se ven por encima de los muros", s1.cono.z_index, 49)
	m.queue_free()

	print("C) Espada, bebe mi sangre")
	m = await nuevo_mapa()
	mika = m.mika
	var vida := mika.vida
	var dano := mika.dano_tajo()
	comprobar("se activa pagando vida", [mika.activar_espada(), mika.vida], [true, vida - Config.ESPADA_COSTE])
	comprobar("daño doble y más alcance", [mika.dano_tajo(), mika.alcance_tajo()], [dano * 2, Config.TAJO_ALCANCE * Config.ESPADA_ALCANCE])
	paso(m, Config.ESPADA_DURACION + 0.05)
	comprobar("se acaba", mika.espada_activa(), false)
	mika.vida = Config.ESPADA_COSTE
	comprobar("con poca vida no se puede", mika.activar_espada(), false)
	mika.vida = 10
	mika.filos.assign([Filos.SEDIENTO])
	mika.activar_espada()
	comprobar("Filo sediento: cuesta menos", mika.vida, 10 - Config.ESPADA_COSTE_SEDIENTO)
	m.queue_free()
	m = await cargar_mapa(PUESTO)
	var vp: Vampiro = m.get_node("VP1")
	vp.pos = Vector2(24.5, 15.5)
	vp.mirada = Vector2(0, -1)
	vp._pausa = 100.0
	m.mika.pos = vp.pos + Vector2(0, 3.0) # detrás, sin que lo vea
	m.mika.activar_espada()
	paso(m)
	comprobar("los vampiros la huelen aunque no lo vean", [vp.estado, vp.motivo], [Vampiro.Estado.TESTIGO, "espada"])
	m.queue_free()

	print("D) Filos del Tajo: mudo, largo y arterial")
	m = await nuevo_mapa()
	mika = m.mika
	s1 = m.get_node("S1")
	plantar(s1, Vector2(3.5, 5.5), Vector2(1, 0))
	mika.filos.assign([Filos.MUDO])
	mika.pos = Vector2(3.5, 7.5)
	mika.tajo()
	paso(m)
	comprobar("Filo mudo: el Tajo no se oye", s1.estado, Soldado.Estado.OCULTO)
	m.queue_free()
	m = await nuevo_mapa()
	mika = m.mika
	s1 = m.get_node("S1")
	plantar(s1, Vector2(3.5, 5.5), Vector2(1, 0))
	mika.pos = Vector2(3.5, 7.7)
	mika.mirada = Vector2(0, -1)
	comprobar("a 2,2 casillas el Tajo normal no llega", mika._alcanza_tajo(s1), false)
	mika.filos.assign([Filos.LARGO])
	comprobar("con el Filo largo, en línea recta, sí", mika._alcanza_tajo(s1), true)
	mika.mirada = Vector2(1, -1).normalized()
	comprobar("pero no en diagonal", mika._alcanza_tajo(s1), false)
	mika.filos.assign([Filos.ARTERIAL])
	mika.pos = s1.pos + Vector2(0, 1.0)
	mika.mirada = Vector2(0, -1)
	mika.sed = 50
	s1.vida = 1
	mika.tajo()
	comprobar("Filo arterial: matar con el Tajo baja la sed", [s1.derribado, mika.sed], [true, 50 + Config.FILO_ARTERIAL_SED])
	m.queue_free()

	print("E) Golpe silencioso: sombra y doble")
	m = await nuevo_mapa(true)
	mika = m.mika
	s1 = m.get_node("S1")
	var s2: Soldado = m.get_node("S2")
	plantar(s1, Vector2(3.5, 5.5), Vector2(1, 0))
	plantar(s2, Vector2(4.5, 5.5), Vector2(1, 0))
	mika.filos.assign([Filos.DOBLE, Filos.SOMBRA])
	mika.pos = Vector2(2.6, 5.5)
	mika.mirada = Vector2(1, 0)
	paso(m)
	var antes := mika.velocidad()
	mika.golpe_silencioso()
	comprobar("Filo doble: caen los dos", [s1.derribado, s2.derribado], [true, true])
	comprobar("Filo de sombra: más rápido un rato", mika.velocidad(), antes + Config.FILO_SOMBRA_VELOCIDAD)
	m.queue_free()

	print("F) Veloz, paciente y Krul")
	m = await nuevo_mapa()
	mika = m.mika
	s1 = m.get_node("S1")
	plantar(s1, Vector2(3.5, 5.5), Vector2(1, 0))
	mika.filos.assign([Filos.VELOZ])
	mika.pos = Vector2(3.5, 7.5)
	mika.impulso(Vector2.ZERO)
	paso(m)
	comprobar("Filo veloz: el Impulso no se oye", s1.estado, Soldado.Estado.OCULTO)
	m.queue_free()
	m = await nuevo_mapa()
	mika = m.mika
	mika.filos.assign([Filos.PACIENTE])
	mika.pos = Vector2(0.5, 8.5) # sombra
	mika.sed = 30
	paso(m, 6.0)
	comprobar("Filo paciente: en sombra la sed no sube", mika.sed, 30)
	mika.filos.assign([Filos.KRUL])
	mika.viales = 1
	mika.sed = 80
	mika.tomar_vial()
	paso(m, Config.VIAL_DURACION + 0.05)
	comprobar("Filo de Krul: el vial baja más", mika.sed, 80 + Config.FILO_KRUL_VIAL)
	m.queue_free()

	print("G) En la expedición")
	var e := EstadoExpedicion.actual()
	e.nueva()
	e.filos_ofrecidos = [Filos.MUDO, Filos.LARGO] as Array[String]
	var seguido := [false]
	e._tras_filo = func() -> void: seguido[0] = true
	e.elegir_filo(Filos.MUDO)
	comprobar("elegir un filo lo añade y sigue", [e.filos, seguido[0]], [[Filos.MUDO], true])
	e.filos.assign([Filos.MUDO, Filos.LARGO, Filos.KRUL])
	e._tras_filo = func() -> void: pass
	e.elegir_filo(Filos.VELOZ, Filos.LARGO)
	comprobar("con tres, se cambia uno por otro", e.filos, [Filos.MUDO, Filos.KRUL, Filos.VELOZ])
	m = await cargar_mapa(PUESTO)
	comprobar("el mapa recibe los filos", m.mika.filos, e.filos)
	m.queue_free()
	e.ruta = "arriesgada"
	e.indice = 1 # la emboscada
	m = await cargar_mapa(PUESTO)
	e.al_terminar_mapa(m, true, "")
	comprobar("superar una emboscada deja un filo pendiente", e.filo_pendiente, true)
	m.queue_free()
	paused = false
	e.activa = false
	terminar()
